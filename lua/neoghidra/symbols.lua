-- Symbol management module

local utils = require('neoghidra.utils')
local ghidra = require('neoghidra.ghidra')
local config = require('neoghidra.config')

local M = {}

-- Get word under cursor
local function get_word_under_cursor()
  local word = vim.fn.expand('<cword>')
  return word
end

-- Get binary path from buffer
local function get_binary_path(buf)
  local decomp = require('neoghidra.decompiler')
  local disasm = require('neoghidra.disassembly')

  return decomp.buffer_binaries[buf] or disasm.buffer_binaries[buf]
end

-- Parse function call from decompiler line
local function parse_function_call(line)
  -- Match function calls like: func_name(...)
  local func_name = line:match("(%w+)%s*%(")
  return func_name
end

-- Parse jump target from disassembly line
local function parse_jump_target(line)
  -- Match addresses in jump/call instructions
  -- Examples: "call 0x12345", "jmp func_name"
  local addr = line:match("call%s+(%w+)")
  if not addr then
    addr = line:match("jmp%s+(%w+)")
  end
  if not addr then
    addr = line:match("b%w*%s+(%w+)")  -- ARM branches
  end
  return addr
end

-- Go to definition of symbol under cursor
function M.goto_definition(buf)
  local binary_path = get_binary_path(buf)
  if not binary_path then
    utils.error("No binary associated with this buffer")
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local line = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]

  -- Get word under cursor
  local word = get_word_under_cursor()

  -- Try to find function/symbol
  local functions = ghidra.get_functions(binary_path)
  local symbols = ghidra.get_symbols(binary_path)

  -- Search for matching function
  for _, func in ipairs(functions) do
    if func.name == word then
      -- Found function, jump to it
      local decomp = require('neoghidra.decompiler')
      local disasm = require('neoghidra.disassembly')

      if decomp.buffer_binaries[buf] then
        -- In decompiler view
        decomp.jump_to_address(buf, func.entry_point)
      elseif disasm.buffer_binaries[buf] then
        -- In disassembly view
        disasm.jump_to_address(buf, func.entry_point)
      end

      utils.notify("Jumped to function: " .. func.name)
      return
    end
  end

  -- Search for matching symbol
  for _, symbol in ipairs(symbols) do
    if symbol.name == word then
      local decomp = require('neoghidra.decompiler')
      local disasm = require('neoghidra.disassembly')

      if decomp.buffer_binaries[buf] then
        decomp.jump_to_address(buf, symbol.address)
      elseif disasm.buffer_binaries[buf] then
        disasm.jump_to_address(buf, symbol.address)
      end

      utils.notify("Jumped to symbol: " .. symbol.name)
      return
    end
  end

  -- Try parsing jump/call target from disassembly
  local target = parse_jump_target(line)
  if target then
    -- Check if it's an address
    if target:match("^0x") then
      local disasm = require('neoghidra.disassembly')
      if disasm.buffer_binaries[buf] then
        disasm.jump_to_address(buf, target)
        return
      end
    else
      -- It's a symbol name, search again
      for _, func in ipairs(functions) do
        if func.name == target then
          local disasm = require('neoghidra.disassembly')
          disasm.jump_to_address(buf, func.entry_point)
          return
        end
      end
    end
  end

  utils.warn("Definition not found for: " .. word)
end

-- Rename symbol at cursor
function M.rename_symbol(buf)
  local binary_path = get_binary_path(buf)
  if not binary_path then
    utils.error("No binary associated with this buffer")
    return
  end

  local word = get_word_under_cursor()

  vim.ui.input({ prompt = 'New name for "' .. word .. '": ' }, function(new_name)
    if not new_name or new_name == "" then
      return
    end

    -- Find the symbol's address
    local symbols = ghidra.get_symbols(binary_path)
    local functions = ghidra.get_functions(binary_path)

    local target_address = nil

    -- Search in functions
    for _, func in ipairs(functions) do
      if func.name == word then
        target_address = func.entry_point
        break
      end
    end

    -- Search in symbols if not found
    if not target_address then
      for _, symbol in ipairs(symbols) do
        if symbol.name == word then
          target_address = symbol.address
          break
        end
      end
    end

    if target_address then
      ghidra.rename_symbol(binary_path, target_address, new_name, function(success, err)
        if success then
          utils.notify("Symbol renamed to: " .. new_name)
          -- Refresh the view
          local decomp = require('neoghidra.decompiler')
          local disasm = require('neoghidra.disassembly')

          if decomp.buffer_binaries[buf] then
            decomp.refresh(buf)
          elseif disasm.buffer_binaries[buf] then
            -- Disassembly refresh not implemented yet
            utils.notify("Please reopen to see changes")
          end
        else
          utils.error("Failed to rename symbol: " .. (err or "unknown error"))
        end
      end)
    else
      utils.error("Symbol not found: " .. word)
    end
  end)
end

-- Show function list in quickfix or telescope
function M.show_function_list(binary_path)
  local functions = ghidra.get_functions(binary_path)

  if #functions == 0 then
    utils.warn("No functions found")
    return
  end

  -- Try to use telescope if available
  local has_telescope, telescope = pcall(require, 'telescope')

  if has_telescope then
    M.show_functions_telescope(binary_path, functions)
  else
    M.show_functions_quickfix(binary_path, functions)
  end
end

-- Show functions in telescope
function M.show_functions_telescope(binary_path, functions)
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  pickers.new({}, {
    prompt_title = 'Functions',
    finder = finders.new_table {
      results = functions,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("%-40s %s", entry.name, entry.entry_point),
          ordinal = entry.name,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()

        -- Jump to function
        local decomp = require('neoghidra.decompiler')
        local disasm = require('neoghidra.disassembly')

        -- Get current buffer
        local buf = vim.api.nvim_get_current_buf()

        if decomp.buffer_binaries[buf] then
          decomp.jump_to_address(buf, selection.value.entry_point)
        elseif disasm.buffer_binaries[buf] then
          disasm.jump_to_address(buf, selection.value.entry_point)
        end
      end)
      return true
    end,
  }):find()
end

-- Show functions in quickfix
function M.show_functions_quickfix(binary_path, functions)
  local qf_list = {}

  for _, func in ipairs(functions) do
    table.insert(qf_list, {
      text = string.format("%s @ %s - %s", func.name, func.entry_point, func.signature),
      pattern = func.entry_point,
    })
  end

  vim.fn.setqflist(qf_list)
  vim.cmd('copen')
end

-- Show symbol list
function M.show_symbol_list(binary_path)
  local symbols = ghidra.get_symbols(binary_path)

  if #symbols == 0 then
    utils.warn("No symbols found")
    return
  end

  -- Build quickfix list
  local qf_list = {}

  for _, symbol in ipairs(symbols) do
    table.insert(qf_list, {
      text = string.format("%s @ %s [%s]", symbol.name, symbol.address, symbol.type),
      pattern = symbol.address,
    })
  end

  vim.fn.setqflist(qf_list)
  vim.cmd('copen')
end

-- Show references to symbol
function M.show_references(buf)
  local binary_path = get_binary_path(buf)
  if not binary_path then
    utils.error("No binary associated with this buffer")
    return
  end

  local word = get_word_under_cursor()

  utils.notify("Searching for references to: " .. word)

  -- This would require XREFs from Ghidra
  -- For now, just search the decompiled code
  vim.cmd("vimgrep /" .. word .. "/j %")
  vim.cmd("copen")
end

-- Retype variable (change type annotation)
function M.retype_variable(buf)
  local binary_path = get_binary_path(buf)
  if not binary_path then
    utils.error("No binary associated with this buffer")
    return
  end

  local word = get_word_under_cursor()

  vim.ui.input({ prompt = 'New type for "' .. word .. '": ' }, function(new_type)
    if not new_type or new_type == "" then
      return
    end

    utils.notify("Retyping " .. word .. " as " .. new_type)

    -- This would require interaction with Ghidra to set the data type
    -- For now, just show a message
    utils.warn("Variable retyping requires Ghidra project modification (not yet fully implemented)")

    -- TODO: Implement actual retyping via Ghidra headless script
  end)
end

return M
