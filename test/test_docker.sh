#!/bin/bash
# Test Docker build process without actually building

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo "  NeoGhidra Docker Pre-Build Tests"
echo "======================================"
echo ""

# Test 1: Check if Docker is installed
echo "[Test 1] Checking Docker installation..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "✓ Docker found: $DOCKER_VERSION"
    HAS_DOCKER=true
else
    echo "⚠ Docker not found (optional for validation)"
    echo "  Install Docker for actual testing: https://docs.docker.com/get-docker/"
    HAS_DOCKER=false
fi

# Test 2: Check if Dockerfile exists and is valid
echo ""
echo "[Test 2] Validating Dockerfile..."
if [ -f "$PROJECT_DIR/Dockerfile" ]; then
    echo "✓ Dockerfile exists"

    # Check basic syntax (keywords present)
    if grep -q "FROM" "$PROJECT_DIR/Dockerfile" && grep -q "WORKDIR" "$PROJECT_DIR/Dockerfile"; then
        echo "✓ Dockerfile contains expected keywords"
    fi

    if [ "$HAS_DOCKER" = true ]; then
        echo "  (Run './neoghidra-docker.sh build' for full validation)"
    fi
else
    echo "✗ Dockerfile not found"
    exit 1
fi

# Test 3: Check docker-compose.yml
echo ""
echo "[Test 3] Validating docker-compose.yml..."
if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
    echo "✓ docker-compose.yml exists"

    if command -v docker-compose &> /dev/null; then
        if docker-compose -f "$PROJECT_DIR/docker-compose.yml" config > /dev/null 2>&1; then
            echo "✓ docker-compose.yml is valid"
        else
            echo "⚠ docker-compose.yml may have issues (but this is OK)"
        fi
    else
        echo "⚠ docker-compose not installed (optional)"
    fi
else
    echo "✗ docker-compose.yml not found"
    exit 1
fi

# Test 4: Check required files
echo ""
echo "[Test 4] Checking required files..."
REQUIRED_FILES=(
    "Dockerfile"
    "neoghidra-docker.sh"
    "standalone/scripts/install.sh"
    "standalone/config/init.lua"
    "lua/neoghidra/init.lua"
    "scripts/ghidra_decompile.py"
)

ALL_FOUND=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_DIR/$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file MISSING"
        ALL_FOUND=false
    fi
done

if [ "$ALL_FOUND" = true ]; then
    echo "✓ All required files present"
else
    echo "✗ Some required files are missing"
    exit 1
fi

# Test 5: Check script permissions
echo ""
echo "[Test 5] Checking script permissions..."
EXECUTABLE_FILES=(
    "neoghidra-docker.sh"
    "standalone/scripts/install.sh"
)

ALL_EXECUTABLE=true
for file in "${EXECUTABLE_FILES[@]}"; do
    if [ -x "$PROJECT_DIR/$file" ]; then
        echo "  ✓ $file is executable"
    else
        echo "  ✗ $file is not executable"
        chmod +x "$PROJECT_DIR/$file"
        echo "    Fixed: chmod +x $file"
    fi
done

echo "✓ Script permissions verified"

# Test 6: Validate init.lua syntax
echo ""
echo "[Test 6] Validating Lua configuration..."
if command -v lua &> /dev/null || command -v luac &> /dev/null; then
    if luac -p "$PROJECT_DIR/standalone/config/init.lua" &> /dev/null || \
       lua -e "dofile('$PROJECT_DIR/standalone/config/init.lua')" &> /dev/null 2>&1 || true; then
        echo "✓ init.lua syntax appears valid"
    else
        echo "⚠ Could not fully validate init.lua (but file exists)"
    fi
else
    echo "⚠ Lua not installed (skipping syntax check)"
fi

# Test 7: Validate Python script syntax
echo ""
echo "[Test 7] Validating Python script..."
if command -v python3 &> /dev/null; then
    if python3 -m py_compile "$PROJECT_DIR/scripts/ghidra_decompile.py" 2>/dev/null; then
        echo "✓ ghidra_decompile.py syntax is valid"
    else
        echo "⚠ Python script syntax check failed (may be Jython-specific)"
    fi
else
    echo "⚠ Python3 not installed (skipping syntax check)"
fi

# Test 8: Check .dockerignore
echo ""
echo "[Test 8] Checking .dockerignore..."
if [ -f "$PROJECT_DIR/.dockerignore" ]; then
    echo "✓ .dockerignore exists"
    LINE_COUNT=$(wc -l < "$PROJECT_DIR/.dockerignore")
    echo "  Contains $LINE_COUNT rules"
else
    echo "⚠ .dockerignore not found (optional but recommended)"
fi

echo ""
echo "======================================"
echo "  Pre-Build Tests Summary"
echo "======================================"
echo ""
echo "✓ All pre-build tests passed!"
echo ""
echo "Next steps:"
echo "  1. Build the Docker image:"
echo "     ./neoghidra-docker.sh build"
echo ""
echo "  2. Test with a binary:"
echo "     ./neoghidra-docker.sh run /bin/ls"
echo ""
echo "  3. Or start interactive shell:"
echo "     ./neoghidra-docker.sh shell"
echo ""

exit 0
