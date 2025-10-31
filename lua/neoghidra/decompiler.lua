-- Decompiler view module

local utils = require('neoghidra.utils')
local ghidra = require('neoghidra.ghidra')
local config = require('neoghidra.config')

local M = {}

-- Store mapping between buffer and binary path
M.buffer_binaries = {}

-- Store mapping between lines and addresses
M.line_to_address = {}

-- Create decompiler buffer
function M.create_buffer(binary_path, name)
  local buf = utils.create_scratch_buffer(name or "NeoGhidra: Decompiler", "c")
  M.buffer_binaries[buf] = binary_path

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)

  return buf
end

-- Format decompiled code with metadata
local function format_decompiled_code(result)
  local lines = {}
  local line_map = {}

  -- Add header
  table.insert(lines, "// NeoGhidra Decompiler")
  table.insert(lines, "// Binary: " .. result.program_name)
  table.insert(lines, "// Entry Point: " .. result.entry_point)
  table.insert(lines, "// Architecture: " .. result.language)
  table.insert(lines, "//")
  table.insert(lines, "")

  -- Add entry function decompilation
  if result.entry_function then
    local func = result.entry_function

    table.insert(lines, "// Function: " .. func.name)
    table.insert(lines, "// Address: " .. func.entry_point)
    table.insert(lines, "")

    -- Store address mapping
    local start_line = #lines + 1
    line_map[start_line] = func.entry_point

    -- Add decompiled code
    if func.code then
      local code_lines = vim.split(func.code, "\n", { plain = true })
      for _, line in ipairs(code_lines) do
        table.insert(lines, line)
      end
    end

    table.insert(lines, "")
  end

  -- Add other function signatures
  table.insert(lines, "")
  table.insert(lines, "// Other Functions:")
  table.insert(lines, "")

  if result.functions then
    for _, func in ipairs(result.functions) do
      if not result.entry_function or func.entry_point ~= result.entry_function.entry_point then
        local line_num = #lines + 1
        line_map[line_num] = func.entry_point
        table.insert(lines, string.format("// %s @ %s", func.name, func.entry_point))
        table.insert(lines, "// " .. func.signature)
        table.insert(lines, "")
      end
    end
  end

  return lines, line_map
end

-- Load decompilation into buffer
function M.load_decompilation(buf, result)
  local lines, line_map = format_decompiled_code(result)

  -- Store line mapping
  M.line_to_address[buf] = line_map

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

  -- Create highlight namespace
  local ns = vim.api.nvim_create_namespace('neoghidra_decompiler')

  -- Get lines
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- Highlight addresses and offsets
  for i, line in ipairs(lines) do
    -- Highlight hex addresses
    for addr in line:gmatch("0x[0-9a-fA-F]+") do
      local start_col = line:find(addr, 1, true) - 1
      vim.api.nvim_buf_add_highlight(buf, ns, conf.highlights.offset, i - 1, start_col, start_col + #addr)
    end

    -- Highlight function names in comments
    if line:match("^// Function:") or line:match("^// .*@") then
      vim.api.nvim_buf_add_highlight(buf, ns, conf.highlights.function_name, i - 1, 0, -1)
    end
  end
end

-- Open decompiler view for binary
function M.open(binary_path)
  utils.notify("Opening decompiler for: " .. vim.fn.fnamemodify(binary_path, ":t"))

  -- Create buffer
  local buf = M.create_buffer(binary_path, "NeoGhidra: Decompiler [" .. vim.fn.fnamemodify(binary_path, ":t") .. "]")

  -- Open in split
  utils.open_buffer(buf)

  -- Show loading message
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "Analyzing binary with Ghidra...",
    "",
    "This may take a moment depending on binary size.",
    "",
    "Binary: " .. binary_path
  })
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Start analysis
  ghidra.analyze_binary(binary_path, function(result, err)
    vim.schedule(function()
      if err then
        utils.error("Failed to analyze binary: " .. err)
        return
      end

      -- Load decompilation
      M.load_decompilation(buf, result)

      -- Setup keymaps
      M.setup_keymaps(buf)

      -- Jump to entry point
      local entry_line = M.find_line_for_address(buf, result.entry_point)
      if entry_line then
        vim.api.nvim_win_set_cursor(0, {entry_line, 0})
      end
    end)
  end)

  return buf
end

-- Find line for address in decompiler buffer
function M.find_line_for_address(buf, address)
  local line_map = M.line_to_address[buf]
  if not line_map then return nil end

  local addr_str = utils.format_address(address)

  for line, mapped_addr in pairs(line_map) do
    if utils.format_address(mapped_addr) == addr_str then
      return line
    end
  end

  -- Fallback: search through buffer
  return utils.find_line_for_address(buf, address)
end

-- Jump to address in decompiler
function M.jump_to_address(buf, address)
  local line = M.find_line_for_address(buf, address)

  if line then
    vim.api.nvim_win_set_cursor(0, {line, 0})
    return true
  end

  utils.warn("Address not found in decompilation: " .. utils.format_address(address))
  return false
end

-- Get current address from cursor position
function M.get_address_at_cursor(buf)
  local line_map = M.line_to_address[buf]
  if not line_map then return nil end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1]

  -- Check if this line has a direct mapping
  if line_map[line] then
    return line_map[line]
  end

  -- Search backwards for nearest address
  for i = line, 1, -1 do
    if line_map[i] then
      return line_map[i]
    end
  end

  return nil
end

-- Refresh decompilation
function M.refresh(buf)
  local binary_path = M.buffer_binaries[buf]
  if not binary_path then
    utils.error("No binary associated with this buffer")
    return
  end

  -- Clear cache
  ghidra.clear_cache(binary_path)

  -- Reload
  utils.notify("Refreshing decompilation...")
  ghidra.analyze_binary(binary_path, function(result, err)
    vim.schedule(function()
      if err then
        utils.error("Failed to refresh: " .. err)
        return
      end

      M.load_decompilation(buf, result)
      utils.notify("Decompilation refreshed")
    end)
  end)
end

-- Setup buffer keymaps
function M.setup_keymaps(buf)
  local conf = config.get()
  local opts = { buffer = buf, noremap = true, silent = true }

  -- Toggle view
  vim.keymap.set('n', conf.keymaps.toggle_view, function()
    local disasm = require('neoghidra.disassembly')
    local binary_path = M.buffer_binaries[buf]
    local address = M.get_address_at_cursor(buf)

    if binary_path then
      disasm.open(binary_path, address)
    end
  end, opts)

  -- Refresh
  vim.keymap.set('n', conf.keymaps.refresh, function()
    M.refresh(buf)
  end, opts)

  -- List functions
  vim.keymap.set('n', conf.keymaps.list_functions, function()
    local binary_path = M.buffer_binaries[buf]
    if binary_path then
      require('neoghidra.symbols').show_function_list(binary_path)
    end
  end, opts)

  -- Go to definition
  vim.keymap.set('n', conf.keymaps.goto_definition, function()
    require('neoghidra.symbols').goto_definition(buf)
  end, opts)

  -- Rename symbol
  vim.keymap.set('n', conf.keymaps.rename_symbol, function()
    require('neoghidra.symbols').rename_symbol(buf)
  end, opts)
end

return M
