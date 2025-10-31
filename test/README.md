# NeoGhidra Test Suite

This directory contains test files and scripts for validating NeoGhidra functionality.

## Prerequisites

- Ghidra installed (set `GHIDRA_INSTALL_DIR` environment variable or install at `/opt/ghidra`)
- GCC compiler (for building test binaries)
- Python 3 (for JSON validation)

## Quick Test

Run the automated test:

```bash
cd test
./test_ghidra.sh
```

This will:
1. Compile the test binary (if needed)
2. Run Ghidra headless analysis
3. Execute the NeoGhidra decompilation script
4. Validate JSON output
5. Display analysis results

## Manual Testing

### 1. Compile Test Binary

```bash
gcc -o test_binary test.c
```

### 2. Set Ghidra Path

```bash
export GHIDRA_INSTALL_DIR=/path/to/ghidra
```

### 3. Run Ghidra Analysis

```bash
$GHIDRA_INSTALL_DIR/support/analyzeHeadless \
    /tmp/neoghidra_test \
    test_project \
    -import test_binary \
    -overwrite \
    -scriptPath ../scripts \
    -postScript ghidra_decompile.py
```

### 4. Check Output

Look for `__NEOGHIDRA_JSON_START__` and `__NEOGHIDRA_JSON_END__` markers in the output.

## Test Files

- `test.c` - Simple C program with multiple functions
- `test_binary` - Compiled ELF binary
- `test_ghidra.sh` - Automated test script

## Expected Output

The script should output JSON with:
- Program metadata (name, entry point, architecture)
- Decompiled entry function
- List of all functions
- Symbol table
- Disassembly at entry point

Example:
```json
{
  "program_name": "test_binary",
  "entry_point": "0x001010a0",
  "entry_function": {
    "name": "main",
    "code": "int main(void) { ... }",
    "signature": "undefined4 main(void)"
  },
  "functions": [...],
  "symbols": [...],
  "disassembly": [...]
}
```

## Troubleshooting

### Ghidra Not Found
```
ERROR: Ghidra not found at /opt/ghidra
```
**Solution:** Set `GHIDRA_INSTALL_DIR` environment variable:
```bash
export GHIDRA_INSTALL_DIR=/your/ghidra/path
```

### Java Version Issues
Ghidra requires Java 11 or later. Check:
```bash
java -version
```

### Jython Syntax Errors
If you see Python syntax errors, ensure the script uses Jython-compatible syntax (no f-strings).

### Analysis Timeout
For large binaries, increase timeout in Ghidra command:
```bash
-analysisTimeoutPerFile 600
```

## Creating Your Own Tests

Add new test binaries:
1. Write C/C++/Assembly source
2. Compile to ELF/PE/Mach-O
3. Run through test script
4. Verify JSON output

Example:
```bash
gcc -o my_test my_test.c
export TEST_BINARY=my_test
./test_ghidra.sh
```
