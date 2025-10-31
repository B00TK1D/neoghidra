#!/bin/bash
# NeoGhidra Docker Wrapper Script
# Easy command-line interface for running NeoGhidra in Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="neoghidra:latest"
CONTAINER_NAME="neoghidra-session"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat << EOF
NeoGhidra Docker Wrapper

Usage:
    $0 build              Build the Docker image
    $0 run <binary>       Run NeoGhidra on a binary file
    $0 shell              Start an interactive shell in the container
    $0 clean              Remove container and volumes
    $0 help               Show this help message

Examples:
    $0 build                      # Build NeoGhidra image
    $0 run /path/to/binary        # Decompile a binary
    $0 run /bin/ls                # Decompile /bin/ls
    $0 shell                      # Interactive session

EOF
}

build_image() {
    echo -e "${BLUE}Building NeoGhidra Docker image...${NC}"
    cd "$SCRIPT_DIR"
    docker build -t "$IMAGE_NAME" .
    echo -e "${GREEN}Build complete!${NC}"
}

run_binary() {
    local BINARY_PATH="$1"

    if [ -z "$BINARY_PATH" ]; then
        echo -e "${YELLOW}No binary specified. Starting in browser mode...${NC}"
        BINARY_PATH=""
    elif [ ! -f "$BINARY_PATH" ]; then
        echo "Error: File not found: $BINARY_PATH"
        exit 1
    fi

    # Get absolute path
    if [ -n "$BINARY_PATH" ]; then
        BINARY_PATH="$(realpath "$BINARY_PATH")"
        BINARY_DIR="$(dirname "$BINARY_PATH")"
        BINARY_NAME="$(basename "$BINARY_PATH")"
    else
        BINARY_DIR="$(pwd)"
        BINARY_NAME=""
    fi

    echo -e "${BLUE}Starting NeoGhidra...${NC}"
    echo "  Binary dir: $BINARY_DIR"
    if [ -n "$BINARY_NAME" ]; then
        echo "  Binary: $BINARY_NAME"
    fi

    docker run -it --rm \
        --name "$CONTAINER_NAME" \
        -v "$BINARY_DIR:/binaries:ro" \
        -v neoghidra-data:/home/ghidra/.local/share/nvim/neoghidra \
        "$IMAGE_NAME" \
        ${BINARY_NAME:+/binaries/$BINARY_NAME}
}

interactive_shell() {
    echo -e "${BLUE}Starting interactive shell...${NC}"

    docker run -it --rm \
        --name "$CONTAINER_NAME" \
        -v "$(pwd):/binaries" \
        -v neoghidra-data:/home/ghidra/.local/share/nvim/neoghidra \
        --entrypoint /bin/bash \
        "$IMAGE_NAME"
}

clean() {
    echo -e "${YELLOW}Cleaning up...${NC}"

    # Stop and remove container if running
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true

    # Ask about volumes
    read -p "Remove data volumes? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume rm neoghidra-data neoghidra-config 2>/dev/null || true
        echo -e "${GREEN}Volumes removed${NC}"
    fi

    echo -e "${GREEN}Cleanup complete${NC}"
}

# Main command processing
case "${1:-help}" in
    build)
        build_image
        ;;
    run)
        run_binary "$2"
        ;;
    shell)
        interactive_shell
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac
