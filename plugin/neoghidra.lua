-- NeoGhidra plugin entry point
-- This file is automatically loaded by Neovim

-- Prevent loading twice
if vim.g.loaded_neoghidra == 1 then
  return
end
vim.g.loaded_neoghidra = 1

-- The plugin will be initialized when user calls setup()
-- This is the lazy-loading pattern

-- Provide a simple command to get started
vim.api.nvim_create_user_command('NeoGhidraSetup', function()
  require('neoghidra').setup()
end, {
  desc = 'Initialize NeoGhidra plugin'
})
