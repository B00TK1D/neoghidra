#!/bin/bash
# Test script for NeoGhidra local testing

set -e

# Configuration
GHIDRA_PATH="${GHIDRA_INSTALL_DIR:-/opt/ghidra}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts"
TEST_BINARY="$PWD/test_binary"
PROJECT_DIR="/tmp/neoghidra_test"

echo "============================================"
echo "NeoGhidra Test Script"
echo "============================================"
echo "Ghidra path: $GHIDRA_PATH"
echo "Test binary: $TEST_BINARY"
echo "Script dir: $SCRIPT_DIR"
echo "Project dir: $PROJECT_DIR"
echo "============================================"

# Check if Ghidra exists
if [ ! -f "$GHIDRA_PATH/support/analyzeHeadless" ]; then
    echo "ERROR: Ghidra not found at $GHIDRA_PATH"
    echo "Please set GHIDRA_INSTALL_DIR environment variable or install Ghidra at /opt/ghidra"
    exit 1
fi

# Check if test binary exists
if [ ! -f "$TEST_BINARY" ]; then
    echo "ERROR: Test binary not found at $TEST_BINARY"
    echo "Please run: gcc -o test_binary test.c"
    exit 1
fi

# Clean up old project
rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR"

echo ""
echo "Running Ghidra headless analysis..."
echo "-------------------------------------------"

# Run Ghidra analysis
"$GHIDRA_PATH/support/analyzeHeadless" \
    "$PROJECT_DIR" \
    "test_project" \
    -import "$TEST_BINARY" \
    -overwrite \
    -scriptPath "$SCRIPT_DIR" \
    -postScript "ghidra_decompile.py" \
    2>&1 | tee /tmp/ghidra_output.log

echo ""
echo "-------------------------------------------"
echo "Analysis complete!"
echo ""
echo "Checking for JSON output..."

if grep -q "__NEOGHIDRA_JSON_START__" /tmp/ghidra_output.log; then
    echo "✓ JSON output found!"
    echo ""
    echo "Extracting JSON..."
    sed -n '/__NEOGHIDRA_JSON_START__/,/__NEOGHIDRA_JSON_END__/p' /tmp/ghidra_output.log | \
        sed '/__NEOGHIDRA_JSON_START__/d' | \
        sed '/__NEOGHIDRA_JSON_END__/d' > /tmp/ghidra_result.json

    echo ""
    echo "Raw JSON size: $(wc -c < /tmp/ghidra_result.json) bytes"
    echo "JSON lines: $(wc -l < /tmp/ghidra_result.json)"
    echo ""
    echo "JSON Result (first 50 lines):"
    echo "-------------------------------------------"
    head -n 50 /tmp/ghidra_result.json
    echo "-------------------------------------------"

    # Validate JSON
    if command -v python3 &> /dev/null; then
        echo ""
        echo "Validating JSON with Python..."
        if python3 -m json.tool /tmp/ghidra_result.json > /tmp/ghidra_result_formatted.json 2>/tmp/json_error.log; then
            echo "✓ JSON is valid!"

            # Show some key information
            echo ""
            echo "Program Info:"
            python3 << 'PYEOF'
import json
with open('/tmp/ghidra_result.json') as f:
    data = json.load(f)
    print("  Program name:", data.get('program_name'))
    print("  Entry point:", data.get('entry_point'))
    print("  Architecture:", data.get('language'))
    print("  Functions found:", len(data.get('functions', [])))
    print("  Symbols found:", len(data.get('symbols', [])))

    if data.get('entry_function'):
        print("\n  Entry function:")
        print("    Name:", data['entry_function'].get('name'))
        print("    Address:", data['entry_function'].get('entry_point'))
        print("    Signature:", data['entry_function'].get('signature'))
PYEOF
        else
            echo "✗ JSON is invalid!"
            echo ""
            echo "JSON Error:"
            cat /tmp/json_error.log
            echo ""
            echo "First 500 characters of JSON:"
            head -c 500 /tmp/ghidra_result.json
            echo ""
            exit 1
        fi
    fi

    echo ""
    echo "============================================"
    echo "✓ Test PASSED!"
    echo "============================================"
else
    echo "✗ JSON output NOT found!"
    echo ""
    echo "Full Ghidra output:"
    cat /tmp/ghidra_output.log
    exit 1
fi
