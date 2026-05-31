local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T["defaults are applied without opts"] = function()
  local cfg = require("lumiris.config")
  cfg.setup()
  eq(cfg.options.interval, 3600)
  eq(cfg.options.log_level, "warn")
  eq(type(cfg.options.events), "table")
end

T["user opts deep-merge over defaults"] = function()
  local cfg = require("lumiris.config")
  cfg.setup({ interval = 10, exclude = { "desert" } })
  eq(cfg.options.interval, 10)
  eq(cfg.options.exclude, { "desert" })
  -- untouched keys keep their default
  eq(cfg.options.log_level, "warn")
  eq(cfg.options.notify, false)
end

T["setup is repeatable and resets from defaults"] = function()
  local cfg = require("lumiris.config")
  cfg.setup({ interval = 1 })
  eq(cfg.options.interval, 1)
  cfg.setup({})
  eq(cfg.options.interval, 3600)
end

return T
