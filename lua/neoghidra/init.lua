-- NeoGhidra main module
-- A Neovim plugin for decompiling binaries with Ghidra

local M = {}

-- Lazy load modules
local config = require('neoghidra.config')
local utils = require('neoghidra.utils')

-- Plugin state
M.is_setup = false

-- Setup function
function M.setup(user_config)
  -- Merge user config with defaults
  config.setup(user_config or {})

  -- Validate Ghidra installation
  local valid, msg = config.validate_ghidra()
  if not valid then
    utils.error("Ghidra installation not found. Please set ghidra_path in config.")
    utils.error(msg)
    return
  end

  -- Setup autocommands for binary files
  M.setup_autocommands()

  -- Setup user commands
  M.setup_commands()

  M.is_setup = true

  utils.notify("NeoGhidra initialized successfully!")
end

-- Setup autocommands for automatic binary detection
function M.setup_autocommands()
  local conf = config.get()

  -- Create augroup
  local group = vim.api.nvim_create_augroup('NeoGhidra', { clear = true })

  -- Auto-detect binary files on BufRead
  vim.api.nvim_create_autocmd('BufRead', {
    group = group,
    pattern = '*',
    callback = function(args)
      local filepath = vim.fn.expand('%:p')

      -- Skip if file is empty or doesn't exist
      if filepath == '' or vim.fn.filereadable(filepath) == 0 then
        return
      end

      -- Check if it's a binary file
      if utils.is_binary_file(filepath) and conf.auto_analyze then
        -- Prompt user to decompile
        vim.schedule(function()
          local choice = vim.fn.confirm(
            'Binary file detected. Open with NeoGhidra?',
            "&Yes\n&No\n&Disassembly",
            1
          )

          if choice == 1 then
            -- Open decompiler view
            M.open_decompiler(filepath)
          elseif choice == 3 then
            -- Open disassembly view
            M.open_disassembly(filepath)
          end
        end)
      end
    end
  })

  -- Auto-detect by file type
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = {'bin', 'exe', 'elf'},
    callback = function()
      local filepath = vim.fn.expand('%:p')
      if filepath ~= '' and conf.auto_analyze then
        vim.schedule(function()
          M.open_decompiler(filepath)
        end)
      end
    end
  })
end

-- Setup user commands
function M.setup_commands()
  -- Command to open decompiler
  vim.api.nvim_create_user_command('NeoGhidraDecompile', function(opts)
    local filepath = opts.args
    if filepath == '' then
      filepath = vim.fn.expand('%:p')
    end

    if filepath == '' then
      utils.error("No file specified")
      return
    end

    M.open_decompiler(filepath)
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Open binary in NeoGhidra decompiler'
  })

  -- Command to open disassembly
  vim.api.nvim_create_user_command('NeoGhidraDisassemble', function(opts)
    local filepath = opts.args
    if filepath == '' then
      filepath = vim.fn.expand('%:p')
    end

    if filepath == '' then
      utils.error("No file specified")
      return
    end

    M.open_disassembly(filepath)
  end, {
    nargs = '?',
    complete = 'file',
    desc = 'Open binary in NeoGhidra disassembly view'
  })

  -- Command to jump to offset
  vim.api.nvim_create_user_command('NeoGhidraJump', function(opts)
    local navigation = require('neoghidra.navigation')
    navigation.jump_to_offset(opts.args)
  end, {
    nargs = 1,
    desc = 'Jump to offset in NeoGhidra buffer'
  })

  -- Command to list functions
  vim.api.nvim_create_user_command('NeoGhidraFunctions', function()
    local buf = vim.api.nvim_get_current_buf()
    local decomp = require('neoghidra.decompiler')
    local disasm = require('neoghidra.disassembly')

    local binary_path = decomp.buffer_binaries[buf] or disasm.buffer_binaries[buf]

    if binary_path then
      local symbols = require('neoghidra.symbols')
      symbols.show_function_list(binary_path)
    else
      utils.error("Not in a NeoGhidra buffer")
    end
  end, {
    desc = 'List all functions in current binary'
  })

  -- Command to list symbols
  vim.api.nvim_create_user_command('NeoGhidraSymbols', function()
    local buf = vim.api.nvim_get_current_buf()
    local decomp = require('neoghidra.decompiler')
    local disasm = require('neoghidra.disassembly')

    local binary_path = decomp.buffer_binaries[buf] or disasm.buffer_binaries[buf]

    if binary_path then
      local symbols = require('neoghidra.symbols')
      symbols.show_symbol_list(binary_path)
    else
      utils.error("Not in a NeoGhidra buffer")
    end
  end, {
    desc = 'List all symbols in current binary'
  })

  -- Command to clear cache
  vim.api.nvim_create_user_command('NeoGhidraClearCache', function()
    utils.cache_clear()
    utils.notify("Cache cleared")
  end, {
    desc = 'Clear NeoGhidra analysis cache'
  })
end

-- Open decompiler for binary
function M.open_decompiler(filepath)
  if not M.is_setup then
    utils.error("NeoGhidra not initialized. Run :lua require('neoghidra').setup()")
    return
  end

  -- Expand path
  filepath = vim.fn.fnamemodify(filepath, ':p')

  if vim.fn.filereadable(filepath) == 0 then
    utils.error("File not found: " .. filepath)
    return
  end

  local decompiler = require('neoghidra.decompiler')
  local buf = decompiler.open(filepath)

  -- Setup navigation
  local navigation = require('neoghidra.navigation')
  navigation.setup_offset_navigation(buf)

  return buf
end

-- Open disassembly for binary
function M.open_disassembly(filepath, address)
  if not M.is_setup then
    utils.error("NeoGhidra not initialized. Run :lua require('neoghidra').setup()")
    return
  end

  -- Expand path
  filepath = vim.fn.fnamemodify(filepath, ':p')

  if vim.fn.filereadable(filepath) == 0 then
    utils.error("File not found: " .. filepath)
    return
  end

  local disassembly = require('neoghidra.disassembly')
  local buf = disassembly.open(filepath, address)

  -- Setup navigation
  local navigation = require('neoghidra.navigation')
  navigation.setup_offset_navigation(buf)

  return buf
end

-- Toggle between decompiler and disassembly
function M.toggle_view()
  local buf = vim.api.nvim_get_current_buf()
  local decomp = require('neoghidra.decompiler')
  local disasm = require('neoghidra.disassembly')

  if decomp.buffer_binaries[buf] then
    -- Currently in decompiler, switch to disassembly
    local binary_path = decomp.buffer_binaries[buf]
    local address = decomp.get_address_at_cursor(buf)
    M.open_disassembly(binary_path, address)
  elseif disasm.buffer_binaries[buf] then
    -- Currently in disassembly, switch to decompiler
    local binary_path = disasm.buffer_binaries[buf]
    M.open_decompiler(binary_path)
  else
    utils.error("Not in a NeoGhidra buffer")
  end
end

-- Expose submodules
M.config = config
M.decompiler = require('neoghidra.decompiler')
M.disassembly = require('neoghidra.disassembly')
M.symbols = require('neoghidra.symbols')
M.navigation = require('neoghidra.navigation')
M.ghidra = require('neoghidra.ghidra')
M.utils = utils

return M
