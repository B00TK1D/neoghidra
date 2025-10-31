#!/bin/bash
# NeoGhidra Installation Script
# Installs Ghidra, Neovim, and sets up NeoGhidra

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GHIDRA_VERSION="${GHIDRA_VERSION:-11.2.1}"
GHIDRA_DATE="${GHIDRA_DATE:-20241105}"
GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-/opt/ghidra}"
NVIM_VERSION="${NVIM_VERSION:-v0.10.2}"
INSTALL_MODE="${INSTALL_MODE:-user}"  # user or system

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            DISTRO=$ID
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        echo_error "Unsupported OS: $OSTYPE"
        exit 1
    fi
    echo_info "Detected OS: $OS${DISTRO:+ ($DISTRO)}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ] && [ "$INSTALL_MODE" != "docker" ]; then
        echo_warning "Running as root. Installing system-wide."
        INSTALL_MODE="system"
    fi
}

# Install system dependencies
install_dependencies() {
    echo_info "Installing system dependencies..."

    if [ "$OS" = "linux" ]; then
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y wget curl git unzip gcc make openjdk-21-jdk || \
            apt-get install -y wget curl git unzip gcc make openjdk-17-jdk || \
            apt-get install -y wget curl git unzip gcc make default-jdk
        elif command -v yum &> /dev/null; then
            yum install -y wget curl git unzip gcc make java-21-openjdk-devel || \
            yum install -y wget curl git unzip gcc make java-17-openjdk-devel
        elif command -v pacman &> /dev/null; then
            pacman -Sy --noconfirm wget curl git unzip gcc make jdk-openjdk
        elif command -v apk &> /dev/null; then
            apk add --no-cache wget curl git unzip gcc make openjdk21 || \
            apk add --no-cache wget curl git unzip gcc make openjdk17
        fi
    elif [ "$OS" = "macos" ]; then
        if ! command -v brew &> /dev/null; then
            echo_error "Homebrew is required on macOS. Install from https://brew.sh"
            exit 1
        fi
        brew install wget curl git openjdk@21 || brew install wget curl git openjdk@17
    fi

    echo_success "Dependencies installed"
}

# Verify Java installation
check_java() {
    echo_info "Checking Java installation..."

    if ! command -v java &> /dev/null; then
        echo_error "Java not found. Please install Java 17 or later."
        exit 1
    fi

    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [ "$JAVA_VERSION" -lt 17 ]; then
        echo_error "Java 17 or later is required. Found version $JAVA_VERSION"
        exit 1
    fi

    echo_success "Java $JAVA_VERSION detected"
}

# Install Ghidra
install_ghidra() {
    echo_info "Installing Ghidra ${GHIDRA_VERSION}..."

    if [ -d "$GHIDRA_INSTALL_DIR" ]; then
        echo_warning "Ghidra already installed at $GHIDRA_INSTALL_DIR"
        return 0
    fi

    local GHIDRA_ZIP="ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip"
    local GHIDRA_URL="https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/$GHIDRA_ZIP"
    local TMP_DIR="/tmp/ghidra_install"

    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    echo_info "Downloading Ghidra from GitHub..."
    if ! wget -q --show-progress "$GHIDRA_URL"; then
        echo_error "Failed to download Ghidra"
        exit 1
    fi

    echo_info "Extracting Ghidra..."
    unzip -q "$GHIDRA_ZIP"

    echo_info "Installing Ghidra to $GHIDRA_INSTALL_DIR..."
    mkdir -p "$(dirname "$GHIDRA_INSTALL_DIR")"
    mv "ghidra_${GHIDRA_VERSION}_PUBLIC" "$GHIDRA_INSTALL_DIR"

    # Cleanup
    rm -rf "$TMP_DIR"

    echo_success "Ghidra installed to $GHIDRA_INSTALL_DIR"
}

# Install Neovim
install_neovim() {
    echo_info "Checking Neovim installation..."

    if command -v nvim &> /dev/null; then
        local CURRENT_VERSION=$(nvim --version | head -n 1 | cut -d' ' -f2)
        echo_success "Neovim already installed: $CURRENT_VERSION"
        return 0
    fi

    echo_info "Installing Neovim ${NVIM_VERSION}..."

    if [ "$OS" = "linux" ]; then
        local NVIM_URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux64.tar.gz"
        local TMP_DIR="/tmp/nvim_install"

        mkdir -p "$TMP_DIR"
        cd "$TMP_DIR"

        wget -q --show-progress "$NVIM_URL"
        tar xzf nvim-linux64.tar.gz

        if [ "$INSTALL_MODE" = "system" ] || [ "$INSTALL_MODE" = "docker" ]; then
            cp -r nvim-linux64/* /usr/local/
        else
            mkdir -p "$HOME/.local"
            cp -r nvim-linux64/* "$HOME/.local/"
        fi

        rm -rf "$TMP_DIR"

    elif [ "$OS" = "macos" ]; then
        brew install neovim
    fi

    echo_success "Neovim installed"
}

# Setup NeoGhidra configuration
setup_neoghidra() {
    echo_info "Setting up NeoGhidra configuration..."

    local NVIM_CONFIG_DIR
    if [ "$INSTALL_MODE" = "docker" ]; then
        NVIM_CONFIG_DIR="/root/.config/nvim"
    elif [ "$INSTALL_MODE" = "system" ]; then
        NVIM_CONFIG_DIR="/root/.config/nvim"
    else
        NVIM_CONFIG_DIR="$HOME/.config/nvim"
    fi

    # Backup existing config if it exists
    if [ -d "$NVIM_CONFIG_DIR" ]; then
        echo_warning "Backing up existing Neovim config to ${NVIM_CONFIG_DIR}.backup"
        mv "$NVIM_CONFIG_DIR" "${NVIM_CONFIG_DIR}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    # Create config directory
    mkdir -p "$NVIM_CONFIG_DIR"

    # Determine the plugin source directory
    local PLUGIN_DIR
    if [ -n "$NEOGHIDRA_SRC" ]; then
        PLUGIN_DIR="$NEOGHIDRA_SRC"
    elif [ -f "$(dirname "$0")/../lua/neoghidra/init.lua" ]; then
        PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    else
        echo_error "Cannot find NeoGhidra plugin source"
        exit 1
    fi

    # Copy the standalone config
    if [ -f "$PLUGIN_DIR/standalone/config/init.lua" ]; then
        cp "$PLUGIN_DIR/standalone/config/init.lua" "$NVIM_CONFIG_DIR/init.lua"
    else
        echo_error "Cannot find standalone init.lua"
        exit 1
    fi

    # Create symlink or copy plugin
    local NVIM_DATA_DIR
    if [ "$INSTALL_MODE" = "docker" ] || [ "$INSTALL_MODE" = "system" ]; then
        NVIM_DATA_DIR="/root/.local/share/nvim"
    else
        NVIM_DATA_DIR="$HOME/.local/share/nvim"
    fi

    mkdir -p "$NVIM_DATA_DIR/lazy"

    # Copy the plugin
    cp -r "$PLUGIN_DIR" "$NVIM_DATA_DIR/lazy/neoghidra"

    # Set environment variable
    export GHIDRA_INSTALL_DIR="$GHIDRA_INSTALL_DIR"

    echo_success "NeoGhidra configuration installed"
}

# Install Neovim plugins
install_plugins() {
    echo_info "Installing Neovim plugins..."

    # Run Neovim headless to install plugins
    nvim --headless "+Lazy! sync" +qa || true

    # Give it a moment
    sleep 2

    echo_success "Plugins installed"
}

# Create launcher script
create_launcher() {
    echo_info "Creating launcher script..."

    local LAUNCHER="/usr/local/bin/neoghidra"
    if [ "$INSTALL_MODE" = "user" ]; then
        LAUNCHER="$HOME/.local/bin/neoghidra"
        mkdir -p "$HOME/.local/bin"
    fi

    cat > "$LAUNCHER" << 'EOF'
#!/bin/bash
# NeoGhidra Launcher

export GHIDRA_INSTALL_DIR="${GHIDRA_INSTALL_DIR:-/opt/ghidra}"

if [ $# -eq 0 ]; then
    echo "NeoGhidra - Terminal Ghidra Editor"
    echo ""
    echo "Usage: neoghidra <binary-file>"
    echo "   or: neoghidra              (opens file browser)"
    echo ""
    echo "Ghidra: $GHIDRA_INSTALL_DIR"
    nvim
else
    nvim "$@"
fi
EOF

    chmod +x "$LAUNCHER"

    echo_success "Launcher created: $LAUNCHER"
}

# Main installation
main() {
    echo_info "======================================"
    echo_info "  NeoGhidra Installation Script"
    echo_info "======================================"
    echo ""

    detect_os
    check_root

    echo_info "Installation mode: $INSTALL_MODE"
    echo ""

    # Install components
    if [ "$INSTALL_MODE" = "docker" ] || [ "$INSTALL_MODE" = "system" ]; then
        install_dependencies
    fi

    check_java
    install_ghidra
    install_neovim
    setup_neoghidra
    install_plugins
    create_launcher

    echo ""
    echo_success "======================================"
    echo_success "  Installation Complete!"
    echo_success "======================================"
    echo ""
    echo_info "Run 'neoghidra <binary>' to decompile a binary"
    echo_info "Or run 'neoghidra' to open the file browser"
    echo ""
    echo_info "Environment:"
    echo_info "  GHIDRA_INSTALL_DIR=$GHIDRA_INSTALL_DIR"
    echo ""
}

# Run main installation
main "$@"
