#!/bin/bash
# Quick test for JSON extraction logic

set -e

echo "Testing JSON extraction logic..."

# Create test output
cat > /tmp/test_ghidra_output.txt << 'EOF'
INFO: Some Ghidra log message
WARN: Some warning
__NEOGHIDRA_JSON_START__
{
  "test": "value",
  "number": 123,
  "array": [1, 2, 3]
}
__NEOGHIDRA_JSON_END__
INFO: More log messages
EOF

echo "Test input created."
echo ""

# Extract JSON
sed -n '/__NEOGHIDRA_JSON_START__/,/__NEOGHIDRA_JSON_END__/p' /tmp/test_ghidra_output.txt | \
    sed '/__NEOGHIDRA_JSON_START__/d' | \
    sed '/__NEOGHIDRA_JSON_END__/d' > /tmp/test_result.json

echo "Extracted JSON:"
cat /tmp/test_result.json
echo ""

# Validate
if command -v python3 &> /dev/null; then
    echo "Validating..."
    if python3 -m json.tool /tmp/test_result.json > /dev/null 2>&1; then
        echo "✓ JSON extraction works correctly!"

        # Test with Python
        python3 << 'PYEOF'
import json
with open('/tmp/test_result.json') as f:
    data = json.load(f)
    print("Parsed data:", data)
    assert data['test'] == 'value'
    assert data['number'] == 123
    print("✓ All assertions passed!")
PYEOF
    else
        echo "✗ JSON validation failed!"
        exit 1
    fi
else
    echo "Python3 not available, skipping validation"
fi

echo ""
echo "JSON extraction test PASSED!"
