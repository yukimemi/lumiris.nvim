local M = {}

local h = vim.health
local start = h.start or h.report_start
local ok = h.ok or h.report_ok
local info = h.info or h.report_info
local warn = h.warn or h.report_warn

function M.check()
  start("lumiris")

  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim >= 0.10")
  else
    warn("Neovim 0.10+ recommended (vim.uv / vim.health.start)")
  end

  local options = require("lumiris.config").options
  local state = require("lumiris.state")
  local cands = require("lumiris.colorscheme").candidates()

  if #cands == 0 then
    warn("no candidate colorschemes after include/exclude/hated filtering")
  else
    ok(("%d candidate colorscheme(s)"):format(#cands))
  end

  if options.interval and options.interval > 0 then
    info(("auto-switch every %ds on: %s"):format(options.interval, table.concat(options.events, ", ")))
  else
    info(("interval = 0: switch on each event (%s)"):format(table.concat(options.events, ", ")))
  end

  info("state file: " .. options.state_path)
  info("enabled: " .. tostring(state.enabled))
  if state.last then
    info("last applied: " .. state.last)
  end
end

return M
