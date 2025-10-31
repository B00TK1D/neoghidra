# NeoGhidra

A Neovim plugin that integrates Ghidra's powerful decompilation engine directly into your editor. Automatically decompile and analyze binaries with full IDE-like features including go-to-definition, symbol renaming, and seamless switching between decompiled and disassembly views.

## Features

- **Automatic Binary Detection**: Automatically detects and offers to decompile binary files (ELF, PE, Mach-O, etc.)
- **Decompiler View**: View decompiled C code from Ghidra with syntax highlighting
- **Disassembly View**: Toggle to assembly view with annotations
- **Symbol Navigation**: Go to definition, rename symbols, list functions
- **Offset Navigation**: Jump directly to any address (`:NeoGhidraJump f82710` jumps to `0xf82710`)
- **Treesitter Integration**: Full syntax highlighting for decompiled C code
- **Smart Caching**: Analysis results are cached for faster subsequent access
- **View Switching**: Seamlessly toggle between decompiler and disassembly views
- **Function Browser**: List and navigate all functions with Telescope or Quickfix integration

## Prerequisites

- Neovim 0.8 or later
- [Ghidra](https://ghidra-sre.org/) installed and configured
- Python 3 (for Ghidra headless scripts)
- (Optional) [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) for enhanced syntax highlighting
- (Optional) [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for better function/symbol browsing

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'B00TK1D/neoghidra',
  config = function()
    require('neoghidra').setup({
      -- Path to your Ghidra installation
      ghidra_path = '/opt/ghidra',  -- or set GHIDRA_INSTALL_DIR env var

      -- Auto-analyze binaries when opened
      auto_analyze = true,

      -- Default view: "decompiler" or "disassembly"
      default_view = "decompiler",

      -- Keymaps (customize as needed)
      keymaps = {
        toggle_view = "<leader>gt",
        goto_definition = "gd",
        rename_symbol = "<leader>gr",
        jump_to_offset = "<leader>go",
        list_functions = "<leader>gF",
      }
    })
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'B00TK1D/neoghidra',
  config = function()
    require('neoghidra').setup({
      ghidra_path = '/opt/ghidra',
    })
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'B00TK1D/neoghidra'

" In your init.vim or init.lua:
lua << EOF
require('neoghidra').setup({
  ghidra_path = '/opt/ghidra',
})
EOF
```

## Configuration

### Environment Variables

You can set `GHIDRA_INSTALL_DIR` environment variable instead of specifying `ghidra_path` in the config:

```bash
export GHIDRA_INSTALL_DIR=/opt/ghidra
```

### Full Configuration Options

```lua
require('neoghidra').setup({
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
  },

  -- Advanced options
  advanced = {
    cache_results = true,      -- Cache decompilation results
    auto_save_project = true,  -- Auto-save Ghidra project changes
    use_treesitter = true,     -- Use treesitter for syntax highlighting
  }
})
```

## Usage

### Opening Binaries

#### Automatic Detection
When you open a binary file, NeoGhidra will automatically detect it and prompt you:
```
Binary file detected. Open with NeoGhidra?
[Y]es [N]o [D]isassembly
```

#### Manual Commands

Open current file in decompiler:
```vim
:NeoGhidraDecompile
```

Open specific file in decompiler:
```vim
:NeoGhidraDecompile /path/to/binary
```

Open in disassembly view:
```vim
:NeoGhidraDisassemble
:NeoGhidraDisassemble /path/to/binary
```

### Navigation

#### Jump to Offset
Jump to a specific memory address:
```vim
:NeoGhidraJump f82710          " Jumps to 0xf82710
:NeoGhidraJump 0x401000        " Jumps to 0x401000
```

Or use the keymap (default: `<leader>go`):
- Press `<leader>go`
- Enter the hex offset (with or without `0x` prefix)

#### Go to Definition
Place cursor on a function name or symbol and press `gd` (or your configured keymap) to jump to its definition.

#### List Functions
Press `<leader>gF` to open a list of all functions:
- With Telescope: Interactive fuzzy searchable list
- Without Telescope: Quickfix list

#### Toggle Views
Press `<leader>gt` to toggle between decompiler and disassembly views, maintaining your current position.

### Symbol Management

#### Rename Symbol
1. Place cursor on a symbol/function name
2. Press `<leader>gr`
3. Enter the new name
4. The view will refresh with the renamed symbol

#### Show References
Press `<leader>gR` to find all references to the symbol under cursor.

#### Retype Variable
Press `<leader>gy` to change the type annotation of a variable (work in progress).

### Other Commands

List all symbols:
```vim
:NeoGhidraSymbols
```

List all functions:
```vim
:NeoGhidraFunctions
```

Clear analysis cache:
```vim
:NeoGhidraClearCache
```

Refresh current view:
```vim
" Use the keymap (default: <leader>gf)
<leader>gf
```

## Workflow Example

1. Open a binary file:
   ```bash
   nvim /bin/ls
   ```

2. NeoGhidra detects it and prompts you - select "Yes" for decompiler view

3. Wait for Ghidra analysis (status shown in notifications)

4. Browse the decompiled C code with syntax highlighting

5. Navigate to functions:
   - Press `<leader>gF` to see all functions
   - Select one to jump to it
   - Or place cursor on a function call and press `gd`

6. Toggle to disassembly view:
   - Press `<leader>gt`
   - See the assembly code at the same location

7. Jump to specific address:
   - Press `<leader>go`
   - Enter address like `401000`

8. Rename symbols:
   - Place cursor on a symbol
   - Press `<leader>gr`
   - Enter new name

## Architecture

```
neoghidra/
├── lua/neoghidra/
│   ├── init.lua          # Main plugin entry point
│   ├── config.lua        # Configuration management
│   ├── ghidra.lua        # Ghidra headless interface
│   ├── decompiler.lua    # Decompiler view
│   ├── disassembly.lua   # Disassembly view
│   ├── symbols.lua       # Symbol management
│   ├── navigation.lua    # Offset navigation
│   └── utils.lua         # Utility functions
├── scripts/
│   └── ghidra_decompile.py  # Ghidra headless script
├── queries/c/
│   └── highlights.scm    # Treesitter highlighting queries
└── plugin/
    └── neoghidra.lua     # Plugin autoload
```

## How It Works

1. **Binary Detection**: When a binary file is opened, NeoGhidra detects it via file magic bytes (ELF, PE, Mach-O headers)

2. **Headless Analysis**: Ghidra runs in headless mode using `analyzeHeadless` command with the Python script

3. **Data Extraction**: The Python script extracts:
   - Decompiled C code for all functions
   - Disassembly listings with annotations
   - Symbol table and function metadata
   - Cross-references and call graphs

4. **Caching**: Results are cached in `~/.local/share/nvim/neoghidra/projects` for fast reloading

5. **Interactive Viewing**: The Lua modules present the data in interactive buffers with keymaps and commands

## Supported Binary Formats

- ELF (Linux executables, libraries)
- PE (Windows executables, DLLs)
- Mach-O (macOS executables)
- Raw binary files
- Object files (.o, .obj)

All formats supported by Ghidra are compatible.

## Troubleshooting

### "Ghidra headless not found"
- Ensure Ghidra is installed and `ghidra_path` points to the installation directory
- Verify the `analyzeHeadless` script exists at `$GHIDRA_PATH/support/analyzeHeadless`
- Set the `GHIDRA_INSTALL_DIR` environment variable

### Analysis is slow
- Large binaries take time to analyze - be patient
- Increase `analysis_timeout` in config if analysis times out
- Results are cached, so subsequent opens are fast

### Decompilation quality
- Ghidra's decompilation quality depends on the binary
- Stripped binaries have less information (no symbol names)
- Use symbol renaming to make code more readable

### Keymaps not working
- Ensure you're in a NeoGhidra buffer
- Check for keymap conflicts with `:verbose map <leader>gt`
- Customize keymaps in setup() if needed

## Limitations

- Symbol renaming is currently cached locally (not persisted to Ghidra project)
- Variable retyping requires additional Ghidra integration (work in progress)
- Very large binaries (>100MB) may take significant time to analyze
- Some advanced Ghidra features (patching, debugging) are not yet exposed

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - see LICENSE file for details

## Credits

- [Ghidra](https://ghidra-sre.org/) - NSA's reverse engineering framework
- [Neovim](https://neovim.io/) - Hyperextensible Vim-based text editor

## Related Projects

- [Cutter](https://cutter.re/) - Reverse engineering platform powered by rizin
- [Binary Ninja](https://binary.ninja/) - Commercial reverse engineering platform
- [IDA Pro](https://hex-rays.com/ida-pro/) - Industry standard disassembler