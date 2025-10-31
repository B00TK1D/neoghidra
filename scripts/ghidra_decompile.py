#!/usr/bin/env python
"""
Ghidra Headless Decompiler Script
This script runs in Ghidra's headless mode to analyze and decompile binaries.
Note: This script runs under Jython (Python 2.x compatible), not CPython.
"""

# @category: NeoGhidra
# @author: NeoGhidra

from ghidra.app.decompiler import DecompInterface
from ghidra.util.task import ConsoleTaskMonitor
from ghidra.program.model.listing import CodeUnit
from ghidra.program.model.symbol import SourceType
import json
import sys

def get_entry_point():
    """Get the program entry point."""
    entry_points = currentProgram.getSymbolTable().getExternalEntryPointIterator()
    if entry_points.hasNext():
        return entry_points.next().getAddress()
    return currentProgram.getMinAddress()

def decompile_function(decompiler, function):
    """Decompile a single function."""
    if function is None:
        return None

    results = decompiler.decompileFunction(function, 30, monitor)

    if results and results.decompileCompleted():
        decomp_code = results.getDecompiledFunction()
        if decomp_code:
            return {
                'name': function.getName(),
                'entry_point': str(function.getEntryPoint()),
                'code': decomp_code.getC(),
                'signature': str(function.getSignature()),
                'body': str(function.getBody())
            }
    return None

def get_disassembly(address, num_instructions=100):
    """Get disassembly listing from address."""
    listing = currentProgram.getListing()
    instructions = []

    current_addr = address
    for _ in range(num_instructions):
        instr = listing.getInstructionAt(current_addr)
        if instr is None:
            break

        instructions.append({
            'address': str(instr.getAddress()),
            'mnemonic': instr.getMnemonicString(),
            'operands': str(instr.getDefaultOperandRepresentation()),
            'bytes': ' '.join(['%02x' % (b & 0xff) for b in instr.getBytes()]),
            'comment': listing.getComment(CodeUnit.EOL_COMMENT, current_addr) or ''
        })

        current_addr = instr.getAddress().add(instr.getLength())

    return instructions

def get_symbols():
    """Get all symbols in the program."""
    symbol_table = currentProgram.getSymbolTable()
    symbols = []

    for symbol in symbol_table.getAllSymbols(False):
        if not symbol.isExternal():
            symbols.append({
                'name': symbol.getName(),
                'address': str(symbol.getAddress()),
                'type': str(symbol.getSymbolType()),
                'source': str(symbol.getSource())
            })

    return symbols

def get_functions():
    """Get all functions in the program."""
    function_manager = currentProgram.getFunctionManager()
    functions = []

    for func in function_manager.getFunctions(True):
        functions.append({
            'name': func.getName(),
            'entry_point': str(func.getEntryPoint()),
            'signature': str(func.getSignature()),
            'body_range': str(func.getBody())
        })

    return functions

def rename_symbol(address_str, new_name):
    """Rename a symbol at the given address."""
    try:
        address = currentProgram.getAddressFactory().getAddress(address_str)
        symbol_table = currentProgram.getSymbolTable()
        symbols = symbol_table.getSymbols(address)

        for symbol in symbols:
            symbol.setName(new_name, SourceType.USER_DEFINED)
            return {'success': True, 'message': 'Renamed to {}'.format(new_name)}

        return {'success': False, 'message': 'No symbol found at address'}
    except Exception as e:
        return {'success': False, 'message': str(e)}

def set_data_type(address_str, type_str):
    """Set data type for a variable."""
    try:
        from ghidra.program.model.data import DataTypeParser

        address = currentProgram.getAddressFactory().getAddress(address_str)
        parser = DataTypeParser()
        data_type = parser.parse(type_str)

        listing = currentProgram.getListing()
        data = listing.getDataAt(address)
        if data:
            listing.createData(address, data_type)
            return {'success': True, 'message': 'Set type to {}'.format(type_str)}

        return {'success': False, 'message': 'No data at address'}
    except Exception as e:
        return {'success': False, 'message': str(e)}

def analyze_program():
    """Main analysis function."""
    try:
        # Initialize decompiler
        decompiler = DecompInterface()
        decompiler.openProgram(currentProgram)

        # Get entry point
        entry_addr = get_entry_point()

        # Get function at entry point
        function_manager = currentProgram.getFunctionManager()
        entry_function = function_manager.getFunctionContaining(entry_addr)

        # Decompile entry function (may be None if no function at entry)
        entry_decompiled = None
        if entry_function is not None:
            entry_decompiled = decompile_function(decompiler, entry_function)

        # Get all functions
        functions = get_functions()

        # Get all symbols
        symbols = get_symbols()

        # Get disassembly at entry point
        disassembly = get_disassembly(entry_addr)

        # Build result
        result = {
            'program_name': currentProgram.getName(),
            'entry_point': str(entry_addr),
            'entry_function': entry_decompiled,
            'functions': functions,
            'symbols': symbols,
            'disassembly': disassembly,
            'image_base': str(currentProgram.getImageBase()),
            'language': str(currentProgram.getLanguageID())
        }

        return result
    except Exception as e:
        # Return error information
        import traceback
        return {
            'error': True,
            'message': str(e),
            'traceback': traceback.format_exc(),
            'program_name': currentProgram.getName() if currentProgram else 'unknown'
        }

# Main execution
if __name__ == '__main__':
    monitor = ConsoleTaskMonitor()

    # Note: When run via analyzeHeadless, the program is automatically analyzed
    # We don't need to trigger analysis manually here

    result = analyze_program()

    # Output as JSON
    print("__NEOGHIDRA_JSON_START__")
    print(json.dumps(result, indent=2))
    print("__NEOGHIDRA_JSON_END__")
