local M = {}

local NAME_TO_LEVEL = {
  trace = vim.log.levels.TRACE,
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

local function threshold()
  local name = require("lumiris.config").options.log_level
  return NAME_TO_LEVEL[name] or vim.log.levels.WARN
end

---Background log. Shown only when `notify = true` and `level >= log_level`.
---All background paths (timer/autocmd/apply failures) must go through here so
---that `notify = false` makes lumiris truly silent.
---@param level integer  vim.log.levels.*
---@param msg string
function M.at(level, msg)
  if not require("lumiris.config").options.notify then
    return
  end
  if level < threshold() then
    return
  end
  vim.notify(msg, level, { title = "lumiris" })
end

function M.debug(msg)
  M.at(vim.log.levels.DEBUG, msg)
end

function M.info(msg)
  M.at(vim.log.levels.INFO, msg)
end

function M.warn(msg)
  M.at(vim.log.levels.WARN, msg)
end

function M.error(msg)
  M.at(vim.log.levels.ERROR, msg)
end

---User-initiated feedback (from a `:Lumiris*` command). Always shown,
---regardless of the `notify` toggle, because the user explicitly asked.
---@param msg string
---@param level? integer
function M.echo(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "lumiris" })
end

return M
