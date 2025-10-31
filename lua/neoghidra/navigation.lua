-- Navigation module for custom offset jumping

local utils = require('neoghidra.utils')

local M = {}

-- Jump to offset command
-- Usage: :NeoGhidraJump f82710 (jumps to 0xf82710)
function M.jump_to_offset(offset_str)
  -- Get current buffer
  local buf = vim.api.nvim_get_current_buf()

  -- Parse offset (remove 'f' prefix if present, and any '0x')
  offset_str = offset_str:gsub("^f", ""):gsub("^0x", "")

  -- Convert to number
  local offset = tonumber(offset_str, 16)

  if not offset then
    utils.error("Invalid hex offset: " .. offset_str)
    return
  end

  -- Determine which view we're in
  local decomp = require('neoghidra.decompiler')
  local disasm = require('neoghidra.disassembly')

  if decomp.buffer_binaries[buf] then
    -- In decompiler view
    decomp.jump_to_address(buf, offset)
  elseif disasm.buffer_binaries[buf] then
    -- In disassembly view
    disasm.jump_to_address(buf, offset)
  else
    utils.error("Not in a NeoGhidra buffer")
  end
end

-- Setup the :f command for line number navigation
-- This overrides the default line number behavior in NeoGhidra buffers
function M.setup_offset_navigation(buf)
  -- Create buffer-local command
  vim.api.nvim_buf_create_user_command(buf, 'NeoGhidraJump', function(opts)
    M.jump_to_offset(opts.args)
  end, {
    nargs = 1,
    desc = "Jump to offset in NeoGhidra buffer"
  })

  -- Setup autocmd to intercept :f commands
  -- Note: This is a custom solution since we can't directly override : commands
  -- Users should use :NeoGhidraJump f82710 instead of :f82710

  -- However, we can provide a mapping for convenience
  local config = require('neoghidra.config')
  local conf = config.get()

  -- Map leader+go to jump to offset
  vim.keymap.set('n', conf.keymaps.jump_to_offset, function()
    vim.ui.input({ prompt = 'Jump to offset (hex): ' }, function(input)
      if input then
        M.jump_to_offset(input)
      end
    end)
  end, { buffer = buf, noremap = true, silent = true })
end

-- Alternative: Create a custom command-line mode command
-- This is more complex but provides :f82710 syntax
function M.setup_commandline_intercept(buf)
  -- Create an autocmd that fires on CmdlineEnter
  vim.api.nvim_create_autocmd("CmdlineChanged", {
    buffer = buf,
    callback = function()
      local cmdline = vim.fn.getcmdline()

      -- Check if it matches :f followed by hex digits
      if cmdline:match("^f%x+$") then
        -- Extract the hex part
        local hex_part = cmdline:match("^f(%x+)$")

        -- Set up to execute our jump command instead
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-u>", true, false, true), 'n', false)
        vim.fn.setcmdline("NeoGhidraJump " .. hex_part)
      end
    end
  })
end

return M
