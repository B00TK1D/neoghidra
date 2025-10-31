-- Configuration module for NeoGhidra

local M = {}

-- Default configuration
M.defaults = {
  -- Path to Ghidra installation directory
  ghidra_path = os.getenv("GHIDRA_INSTALL_DIR") or "/opt/ghidra",

  -- Path to Ghidra project directory (for caching analyses)
  project_dir = vim.fn.stdpath("data") .. "/neoghidra/projects",

  -- Auto-analyze binaries on open
  auto_analyze = true,

  -- Start with decompiler view (true) or disassembly view (false)
  default_view = "decompiler",

  -- Timeout for Ghidra analysis (in seconds)
  analysis_timeout = 300,

  -- Binary file patterns to auto-detect
  binary_patterns = {
    "*.exe", "*.elf", "*.o", "*.so", "*.dll", "*.dylib",
    "*.bin", "*.out", "a.out"
  },

  -- Keymaps
  keymaps = {
    toggle_view = "<leader>gt",      -- Toggle between decompiler and disassembly
    goto_definition = "gd",           -- Go to definition
    rename_symbol = "<leader>gr",     -- Rename symbol
    show_references = "<leader>gR",   -- Show references
    retype_variable = "<leader>gy",   -- Retype variable
    jump_to_offset = "<leader>go",    -- Jump to offset
    refresh = "<leader>gf",           -- Refresh decompilation
    list_functions = "<leader>gF",    -- List all functions
    list_symbols = "<leader>gs",      -- List all symbols
  },

  -- UI settings
  ui = {
    split = "vertical",  -- How to open windows: "vertical", "horizontal", "tab"
    width = 80,          -- Width for vertical split
    height = 30,         -- Height for horizontal split
    signs = true,        -- Show signs in sign column
  },

  -- Highlighting
  highlights = {
    offset = "Number",
    function_name = "Function",
    variable = "Identifier",
    type = "Type",
    comment = "Comment",
  },

  -- Advanced options
  advanced = {
    cache_results = true,      -- Cache decompilation results
    auto_save_project = true,  -- Auto-save Ghidra project changes
    use_treesitter = true,     -- Use treesitter for syntax highlighting
    show_line_offsets = true,  -- Show offsets in line numbers
  }
}

-- Current configuration (starts as copy of defaults)
M.options = vim.deepcopy(M.defaults)

-- Setup function to merge user config with defaults
function M.setup(user_config)
  M.options = vim.tbl_deep_extend("force", M.options, user_config or {})

  -- Ensure project directory exists
  vim.fn.mkdir(M.options.project_dir, "p")

  return M.options
end

-- Get current configuration
function M.get()
  return M.options
end

-- Validate Ghidra installation
function M.validate_ghidra()
  local ghidra_headless = M.options.ghidra_path .. "/support/analyzeHeadless"

  if vim.fn.executable(ghidra_headless) == 0 then
    return false, "Ghidra headless not found at: " .. ghidra_headless
  end

  return true, ghidra_headless
end

return M
