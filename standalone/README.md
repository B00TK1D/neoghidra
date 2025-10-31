# NeoGhidra Standalone Distribution

This directory contains a complete standalone setup for NeoGhidra with automatic installation of all dependencies.

## Quick Start

```bash
# Run the install script
./scripts/install.sh

# Launch NeoGhidra
neoghidra /path/to/binary
```

## What Gets Installed

The install script will automatically:

1. **Detect your OS** (Linux/macOS)
2. **Install system dependencies**
   - Java 17+ (required for Ghidra)
   - Git, wget, curl, gcc, make
3. **Download and install Ghidra**
   - Latest stable version (11.2.1)
   - Installed to `/opt/ghidra` (or custom location)
4. **Install Neovim** (if not already installed)
   - Version 0.10.2
5. **Configure NeoGhidra**
   - Standalone Neovim configuration
   - All required plugins
   - Optimized keybindings

## Installation Options

### Standard Installation

```bash
./scripts/install.sh
```

Installs to your home directory (`~/.config/nvim`, `~/.local/bin/neoghidra`)

### System-Wide Installation

```bash
sudo ./scripts/install.sh
```

Installs to system directories (`/opt/ghidra`, `/usr/local/bin/neoghidra`)

### Custom Ghidra Location

```bash
export GHIDRA_INSTALL_DIR=/custom/path/ghidra
./scripts/install.sh
```

### Custom Ghidra Version

```bash
export GHIDRA_VERSION=11.1.2
export GHIDRA_DATE=20240926
./scripts/install.sh
```

## Configuration

The standalone configuration is located at:
- **Config file**: `config/init.lua`
- **Installed to**: `~/.config/nvim/init.lua`

### Features Included

- **Color scheme**: Tokyo Night
- **File explorer**: nvim-tree
- **Fuzzy finder**: Telescope
- **Syntax highlighting**: Treesitter
- **Status line**: lualine
- **Key hints**: which-key
- **NeoGhidra**: Fully configured

### Keybindings

| Key | Action |
|-----|--------|
| `<Space>` | Leader key |
| `<Space>gd` | Decompile file |
| `<Space>ga` | Disassemble file |
| `<Space>gt` | Toggle view |
| `<Space>gF` | List functions |
| `<Space>gs` | List symbols |
| `<Space>go` | Jump to offset |
| `<Space>gr` | Rename symbol |
| `<Space>e` | File explorer |
| `<Space>ff` | Find files |
| `<Space>fg` | Live grep |

## Using NeoGhidra

### From Command Line

```bash
# Decompile a binary
neoghidra /path/to/binary

# Open file browser
neoghidra
```

### From Neovim

```vim
:NeoGhidraDecompile /path/to/binary
:NeoGhidraDisassemble /path/to/binary
:NeoGhidraJump f82710
```

## Customization

### Modifying Keybindings

Edit `config/init.lua` and change the keymaps section:

```lua
keymaps = {
  toggle_view = "<leader>gt",  -- Change these
  goto_definition = "gd",
  -- ...
}
```

Then reinstall or manually copy to `~/.config/nvim/init.lua`

### Adding Plugins

Edit `config/init.lua` and add to the plugins table:

```lua
local plugins = {
  -- Your plugins here
  {
    'plugin/name',
    config = function()
      -- configuration
    end,
  },
  -- ...
}
```

### Changing Color Scheme

Edit `config/init.lua`:

```lua
{
  "folke/tokyonight.nvim",  -- Change to your preferred theme
  priority = 1000,
  config = function()
    vim.cmd.colorscheme('tokyonight-night')
  end,
},
```

## Uninstallation

### Remove NeoGhidra Config

```bash
rm -rf ~/.config/nvim
rm -rf ~/.local/share/nvim
rm ~/.local/bin/neoghidra
```

### Remove Ghidra

```bash
sudo rm -rf /opt/ghidra
```

### Remove Neovim

#### Ubuntu/Debian
```bash
sudo rm -rf /usr/local/bin/nvim /usr/local/share/nvim
```

#### macOS
```bash
brew uninstall neovim
```

## Troubleshooting

### "Java not found"

Install Java 17 or later:

```bash
# Ubuntu/Debian
sudo apt install openjdk-21-jdk

# macOS
brew install openjdk@21
```

### "Ghidra download failed"

Check your internet connection or download manually:
1. Go to https://github.com/NationalSecurityAgency/ghidra/releases
2. Download Ghidra 11.2.1
3. Extract to `/opt/ghidra` (or custom location)
4. Set `GHIDRA_INSTALL_DIR` environment variable

### "Permission denied"

Run with sudo for system-wide install:
```bash
sudo ./scripts/install.sh
```

Or use user installation (default):
```bash
./scripts/install.sh
```

### Conflicts with Existing Neovim Config

The install script backs up your existing config to:
```
~/.config/nvim.backup.<timestamp>
```

To restore:
```bash
mv ~/.config/nvim.backup.<timestamp> ~/.config/nvim
```

## Architecture

```
standalone/
├── config/
│   └── init.lua          # Standalone Neovim configuration
├── scripts/
│   └── install.sh        # Automated installation script
└── README.md             # This file
```

The configuration:
- Uses lazy.nvim for plugin management
- Loads NeoGhidra from local directory
- Includes essential plugins for reverse engineering
- Provides sensible defaults

## Requirements

### Minimum

- OS: Linux or macOS
- Disk: 2GB free space
- RAM: 2GB (4GB recommended)
- Internet: For downloading Ghidra and plugins

### Recommended

- OS: Linux or macOS
- Disk: 5GB free space
- RAM: 8GB
- CPU: 2+ cores
- Internet: Broadband connection

## Support

- Issues: https://github.com/B00TK1D/neoghidra/issues
- Documentation: [Main README](../README.md)
- Docker Guide: [DOCKER.md](../DOCKER.md)

## License

MIT License - see [LICENSE](../LICENSE)
