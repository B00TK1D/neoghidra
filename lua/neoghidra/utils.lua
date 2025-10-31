-- Utility functions for NeoGhidra

local M = {}

-- Parse hex address
function M.parse_address(addr_str)
  -- Remove 0x prefix if present
  addr_str = addr_str:gsub("^0x", "")
  return tonumber(addr_str, 16)
end

-- Format address as hex string
function M.format_address(addr)
  if type(addr) == "string" then
    addr = M.parse_address(addr)
  end
  return string.format("0x%x", addr)
end

-- Check if file is a binary
function M.is_binary_file(filepath)
  local config = require('neoghidra.config').get()

  -- Check by extension
  for _, pattern in ipairs(config.binary_patterns) do
    local glob_pattern = pattern:gsub("%*", ".*"):gsub("%.", "%%.") .. "$"
    if filepath:match(glob_pattern) then
      return true
    end
  end

  -- Check by file magic
  local handle = io.open(filepath, "rb")
  if not handle then
    return false
  end

  local header = handle:read(4)
  handle:close()

  if not header or #header < 4 then
    return false
  end

  -- Check for common binary formats
  local byte1, byte2, byte3, byte4 = header:byte(1, 4)

  -- ELF
  if byte1 == 0x7f and byte2 == 0x45 and byte3 == 0x4c and byte4 == 0x46 then
    return true
  end

  -- PE/MZ
  if byte1 == 0x4d and byte2 == 0x5a then
    return true
  end

  -- Mach-O
  if (byte1 == 0xfe and byte2 == 0xed and byte3 == 0xfa and byte4 == 0xce) or
     (byte1 == 0xfe and byte2 == 0xed and byte3 == 0xfa and byte4 == 0xcf) or
     (byte1 == 0xce and byte2 == 0xfa and byte3 == 0xed and byte4 == 0xfe) or
     (byte1 == 0xcf and byte2 == 0xfa and byte3 == 0xed and byte4 == 0xfe) then
    return true
  end

  return false
end

-- Create a scratch buffer
function M.create_scratch_buffer(name, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', filetype)
  return buf
end

-- Open buffer in appropriate split
function M.open_buffer(buf)
  local config = require('neoghidra.config').get()

  if config.ui.split == "vertical" then
    vim.cmd("vsplit")
    if config.ui.width then
      vim.cmd("vertical resize " .. config.ui.width)
    end
  elseif config.ui.split == "horizontal" then
    vim.cmd("split")
    if config.ui.height then
      vim.cmd("resize " .. config.ui.height)
    end
  elseif config.ui.split == "tab" then
    vim.cmd("tabnew")
  end

  vim.api.nvim_set_current_buf(buf)
end

-- Show notification
function M.notify(message, level)
  level = level or vim.log.levels.INFO
  vim.notify("[NeoGhidra] " .. message, level)
end

-- Show error
function M.error(message)
  M.notify(message, vim.log.levels.ERROR)
end

-- Show warning
function M.warn(message)
  M.notify(message, vim.log.levels.WARN)
end

-- Execute shell command and return output
function M.execute_command(cmd, timeout)
  timeout = timeout or 30000

  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local handle
  local output = ""
  local error_output = ""

  handle = vim.loop.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    stdio = {nil, stdout, stderr}
  }, function(code, signal)
    stdout:close()
    stderr:close()
    if handle then
      handle:close()
    end
  end)

  if not handle then
    return nil, "Failed to spawn process"
  end

  stdout:read_start(function(err, data)
    if err then
      error_output = error_output .. err
    elseif data then
      output = output .. data
    end
  end)

  stderr:read_start(function(err, data)
    if err then
      error_output = error_output .. err
    elseif data then
      error_output = error_output .. data
    end
  end)

  -- Wait for completion (with timeout)
  local start_time = vim.loop.now()
  while handle and not handle:is_closing() do
    vim.wait(100)
    if vim.loop.now() - start_time > timeout then
      if handle and not handle:is_closing() then
        handle:kill(9)
      end
      return nil, "Command timed out"
    end
  end

  if error_output ~= "" then
    return output, error_output
  end

  return output, nil
end

-- Find line number for address in disassembly buffer
function M.find_line_for_address(buf, address)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local target_addr = M.format_address(address)

  for i, line in ipairs(lines) do
    if line:match("^" .. target_addr) or line:match("%s" .. target_addr) then
      return i
    end
  end

  return nil
end

-- Cache management
M.cache = {}

function M.cache_set(key, value)
  M.cache[key] = value
end

function M.cache_get(key)
  return M.cache[key]
end

function M.cache_clear(key)
  if key then
    M.cache[key] = nil
  else
    M.cache = {}
  end
end

-- Debounce function calls
function M.debounce(fn, ms)
  local timer = vim.loop.new_timer()
  return function(...)
    local args = {...}
    timer:start(ms, 0, vim.schedule_wrap(function()
      fn(unpack(args))
    end))
  end
end

return M
