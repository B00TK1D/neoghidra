-- Disassembly view module

local utils = require('neoghidra.utils')
local ghidra = require('neoghidra.ghidra')
local config = require('neoghidra.config')

local M = {}

-- Store mapping between buffer and binary path
M.buffer_binaries = {}

-- Store disassembly data
M.buffer_disasm = {}

-- Create disassembly buffer
function M.create_buffer(binary_path, name)
  local buf = utils.create_scratch_buffer(name or "NeoGhidra: Disassembly", "asm")
  M.buffer_binaries[buf] = binary_path

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)

  return buf
end

-- Format disassembly output
local function format_disassembly(result, start_address)
  local lines = {}
  local line_to_addr = {}

  -- Add header
  table.insert(lines, "; NeoGhidra Disassembly")
  table.insert(lines, "; Binary: " .. result.program_name)
  table.insert(lines, "; Entry Point: " .. result.entry_point)
  table.insert(lines, "; Architecture: " .. result.language)
  table.insert(lines, "; Image Base: " .. result.image_base)
  table.insert(lines, ";")
  table.insert(lines, "")

  -- Add disassembly
  if result.disassembly then
    for _, instr in ipairs(result.disassembly) do
      local line_num = #lines + 1
      line_to_addr[line_num] = instr.address

      -- Format: ADDRESS: BYTES    MNEMONIC OPERANDS    ; COMMENT
      local line = string.format("%-18s %-16s %-8s %-20s",
        instr.address .. ":",
        instr.bytes,
        instr.mnemonic,
        instr.operands
      )

      if instr.comment and instr.comment ~= "" then
        line = line .. "  ; " .. instr.comment
      end

      table.insert(lines, line)
    end
  end

  return lines, line_to_addr
end

-- Load disassembly into buffer
function M.load_disassembly(buf, result, start_address)
  local lines, line_to_addr = format_disassembly(result, start_address)

  -- Store mapping
  M.buffer_disasm[buf] = {
    line_to_addr = line_to_addr,
    result = result
  }

  -- Make buffer modifiable temporarily
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf, 'readonly', false)

  -- Set lines
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Make buffer read-only again
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)

  -- Apply highlighting
  M.apply_highlights(buf)
end

-- Apply custom highlighting
function M.apply_highlights(buf)
  local conf = config.get()
  local ns = vim.api.nvim_create_namespace('neoghidra_disasm')
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for i, line in ipairs(lines) do
    -- Highlight addresses
    local addr_end = line:find(":", 1, true)
    if addr_end then
      vim.api.nvim_buf_add_highlight(buf, ns, conf.highlights.offset, i - 1, 0, addr_end)
    end

    -- Highlight comments
    local comment_start = line:find(";", 1, true)
    if comment_start then
      vim.api.nvim_buf_add_highlight(buf, ns, conf.highlights.comment, i - 1, comment_start - 1, -1)
    end

    -- Highlight hex bytes
    for hex in line:gmatch("%x%x") do
      local start_col = line:find(hex, addr_end or 1, true)
      if start_col and start_col < (comment_start or #line) then
        vim.api.nvim_buf_add_highlight(buf, ns, "Number", i - 1, start_col - 1, start_col + 1)
      end
    end
  end
end

-- Open disassembly view for binary
function M.open(binary_path, start_address)
  utils.notify("Opening disassembly for: " .. vim.fn.fnamemodify(binary_path, ":t"))

  -- Create buffer
  local buf = M.create_buffer(binary_path, "NeoGhidra: Disassembly [" .. vim.fn.fnamemodify(binary_path, ":t") .. "]")

  -- Open in split
  utils.open_buffer(buf)

  -- Show loading message
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "; Analyzing binary with Ghidra...",
    ";",
    "; This may take a moment depending on binary size.",
    ";",
    "; Binary: " .. binary_path
  })
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Get disassembly
  ghidra.get_disassembly(binary_path, start_address, function(disasm, err)
    vim.schedule(function()
      if err then
        utils.error("Failed to get disassembly: " .. err)
        return
      end

      -- Get full result from cache
      local result = utils.cache_get(binary_path)
      if result then
        M.load_disassembly(buf, result, start_address)

        -- Setup keymaps
        M.setup_keymaps(buf)

        -- Jump to start address if provided
        if start_address then
          M.jump_to_address(buf, start_address)
        else
          -- Jump to entry point
          M.jump_to_address(buf, result.entry_point)
        end
      end
    end)
  end)

  return buf
end

-- Find line for address in disassembly buffer
function M.find_line_for_address(buf, address)
  local disasm_data = M.buffer_disasm[buf]
  if not disasm_data then return nil end

  local addr_str = utils.format_address(address)

  for line, mapped_addr in pairs(disasm_data.line_to_addr) do
    if utils.format_address(mapped_addr) == addr_str then
      return line
    end
  end

  return nil
end

-- Jump to address in disassembly
function M.jump_to_address(buf, address)
  local line = M.find_line_for_address(buf, address)

  if line then
    -- Set cursor to the line
    vim.api.nvim_win_set_cursor(0, {line, 0})
    -- Center the view
    vim.cmd("normal! zz")
    return true
  end

  utils.warn("Address not found in disassembly: " .. utils.format_address(address))
  return false
end

-- Get address at cursor position
function M.get_address_at_cursor(buf)
  local disasm_data = M.buffer_disasm[buf]
  if not disasm_data then return nil end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  return disasm_data.line_to_addr[line]
end

-- Setup buffer keymaps
function M.setup_keymaps(buf)
  local conf = config.get()
  local opts = { buffer = buf, noremap = true, silent = true }

  -- Toggle to decompiler view
  vim.keymap.set('n', conf.keymaps.toggle_view, function()
    local decomp = require('neoghidra.decompiler')
    local binary_path = M.buffer_binaries[buf]

    if binary_path then
      -- Close current buffer
      local current_win = vim.api.nvim_get_current_win()
      decomp.open(binary_path)
      -- Close disassembly window
      vim.api.nvim_win_close(current_win, false)
    end
  end, opts)

  -- Jump to offset command
  vim.keymap.set('n', conf.keymaps.jump_to_offset, function()
    vim.ui.input({ prompt = 'Enter offset (hex): ' }, function(input)
      if input then
        -- Remove 0x prefix if present
        input = input:gsub("^0x", "")
        local address = tonumber(input, 16)
        if address then
          M.jump_to_address(buf, address)
        else
          utils.error("Invalid hex address: " .. input)
        end
      end
    end)
  end, opts)

  -- Go to definition (jump to call target)
  vim.keymap.set('n', conf.keymaps.goto_definition, function()
    require('neoghidra.symbols').goto_definition(buf)
  end, opts)

  -- List functions
  vim.keymap.set('n', conf.keymaps.list_functions, function()
    local binary_path = M.buffer_binaries[buf]
    if binary_path then
      require('neoghidra.symbols').show_function_list(binary_path)
    end
  end, opts)
end

return M
