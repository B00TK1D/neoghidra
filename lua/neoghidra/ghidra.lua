-- Ghidra interaction module

local utils = require('neoghidra.utils')
local config = require('neoghidra.config')

local M = {}

-- Get script path
local function get_script_path()
  local source = debug.getinfo(1, "S").source:sub(2)
  local plugin_root = vim.fn.fnamemodify(source, ":h:h:h")
  return plugin_root .. "/scripts/ghidra_decompile.py"
end

-- Generate project name from binary path
local function get_project_name(binary_path)
  local basename = vim.fn.fnamemodify(binary_path, ":t")
  local hash = vim.fn.sha256(binary_path):sub(1, 8)
  return basename .. "_" .. hash
end

-- Run Ghidra headless analysis
function M.analyze_binary(binary_path, callback)
  local conf = config.get()
  local is_valid, ghidra_headless = config.validate_ghidra()

  if not is_valid then
    utils.error(ghidra_headless)
    if callback then callback(nil, ghidra_headless) end
    return
  end

  local project_name = get_project_name(binary_path)
  local project_dir = conf.project_dir
  local script_path = get_script_path()

  -- Ensure script exists
  if vim.fn.filereadable(script_path) == 0 then
    local err = "Decompile script not found: " .. script_path
    utils.error(err)
    if callback then callback(nil, err) end
    return
  end

  -- Build command
  local cmd = {
    ghidra_headless,
    project_dir,
    project_name,
    "-import", binary_path,
    "-overwrite",
    "-scriptPath", vim.fn.fnamemodify(script_path, ":h"),
    "-postScript", "ghidra_decompile.py"
  }

  utils.notify("Analyzing binary with Ghidra...")

  -- Run async
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        local output = table.concat(data, "\n")

        -- Extract JSON output
        local json_start = output:find("__NEOGHIDRA_JSON_START__")
        local json_end = output:find("__NEOGHIDRA_JSON_END__")

        if json_start and json_end then
          local json_str = output:sub(json_start + 28, json_end - 1)
          local success, result = pcall(vim.json.decode, json_str)

          if success then
            -- Check if result contains an error
            if result.error then
              local err = "Ghidra analysis error: " .. (result.message or "unknown error")
              utils.error(err)
              if result.traceback then
                utils.error("Traceback:\n" .. result.traceback)
              end
              if callback then callback(nil, err) end
            else
              utils.notify("Analysis complete!")
              -- Cache result
              utils.cache_set(binary_path, result)
              if callback then
                callback(result, nil)
              end
            end
          else
            local err = "Failed to parse Ghidra output: " .. tostring(result)
            utils.error(err)
            if callback then callback(nil, err) end
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 then
        local err_msg = table.concat(data, "\n")
        if err_msg:match("%S") then  -- Only log non-empty errors
          vim.schedule(function()
            -- Filter out Ghidra warnings
            if not err_msg:match("^%s*$") and not err_msg:match("WARN") then
              utils.warn("Ghidra: " .. err_msg)
            end
          end)
        end
      end
    end,
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.schedule(function()
          utils.error("Ghidra analysis failed with exit code: " .. exit_code)
          if callback then callback(nil, "Analysis failed") end
        end)
      end
    end
  })
end

-- Decompile a specific function
function M.decompile_function(binary_path, function_name, callback)
  -- First ensure we have the analysis
  local cached = utils.cache_get(binary_path)

  if cached then
    -- Find function in cached results
    for _, func in ipairs(cached.functions or {}) do
      if func.name == function_name then
        if callback then callback(func, nil) end
        return
      end
    end

    if callback then callback(nil, "Function not found") end
  else
    -- Need to analyze first
    M.analyze_binary(binary_path, function(result, err)
      if err then
        if callback then callback(nil, err) end
        return
      end

      -- Now find the function
      for _, func in ipairs(result.functions or {}) do
        if func.name == function_name then
          if callback then callback(func, nil) end
          return
        end
      end

      if callback then callback(nil, "Function not found") end
    end)
  end
end

-- Get disassembly at address
function M.get_disassembly(binary_path, address, callback)
  local cached = utils.cache_get(binary_path)

  if cached then
    -- Return cached disassembly
    if callback then callback(cached.disassembly, nil) end
  else
    -- Need to analyze first
    M.analyze_binary(binary_path, function(result, err)
      if err then
        if callback then callback(nil, err) end
        return
      end

      if callback then callback(result.disassembly, nil) end
    end)
  end
end

-- Rename symbol at address
function M.rename_symbol(binary_path, address, new_name, callback)
  utils.notify("Symbol renaming requires Ghidra project modification")
  -- This would require a separate headless script to modify the project
  -- For now, we'll update the cache
  local cached = utils.cache_get(binary_path)
  if cached then
    for _, symbol in ipairs(cached.symbols or {}) do
      if symbol.address == address then
        symbol.name = new_name
        utils.notify("Symbol renamed to: " .. new_name)
        if callback then callback(true, nil) end
        return
      end
    end
  end

  if callback then callback(false, "Symbol not found") end
end

-- Get all functions
function M.get_functions(binary_path)
  local cached = utils.cache_get(binary_path)
  return cached and cached.functions or {}
end

-- Get all symbols
function M.get_symbols(binary_path)
  local cached = utils.cache_get(binary_path)
  return cached and cached.symbols or {}
end

-- Find symbol at address
function M.find_symbol_at_address(binary_path, address)
  local cached = utils.cache_get(binary_path)
  if not cached then return nil end

  local addr_str = utils.format_address(address)

  for _, symbol in ipairs(cached.symbols or {}) do
    if symbol.address == addr_str then
      return symbol
    end
  end

  return nil
end

-- Find function at address
function M.find_function_at_address(binary_path, address)
  local cached = utils.cache_get(binary_path)
  if not cached then return nil end

  local addr_num = utils.parse_address(address)

  for _, func in ipairs(cached.functions or {}) do
    local func_addr = utils.parse_address(func.entry_point)
    -- Check if address is within function body
    -- This is simplified; a real implementation would parse body_range
    if func_addr == addr_num or func.entry_point == address then
      return func
    end
  end

  return nil
end

-- Clear cache for binary
function M.clear_cache(binary_path)
  utils.cache_clear(binary_path)
end

return M
