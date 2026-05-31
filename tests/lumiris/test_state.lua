local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality

local tmp

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      tmp = vim.fn.tempname()
      require("lumiris.config").setup({ state_path = tmp })
      -- drop the cached prefs so each case starts from a clean file
      package.loaded["lumiris.state"] = nil
    end,
    post_case = function()
      if tmp then
        vim.fn.delete(tmp)
      end
    end,
  },
})

T["like increments weight and persists across reload"] = function()
  local state = require("lumiris.state")
  state.like("tokyonight")
  eq(state.weight("tokyonight"), 1)
  state.like("tokyonight")
  eq(state.weight("tokyonight"), 2)

  -- reload from disk to prove persistence
  package.loaded["lumiris.state"] = nil
  local reloaded = require("lumiris.state")
  eq(reloaded.weight("tokyonight"), 2)
end

T["hate excludes and like un-hates"] = function()
  local state = require("lumiris.state")
  state.hate("desert")
  eq(state.is_hated("desert"), true)
  state.like("desert")
  eq(state.is_hated("desert"), false)
end

T["missing state file yields defaults"] = function()
  local state = require("lumiris.state")
  eq(state.weight("never-seen"), 0)
  eq(state.is_hated("never-seen"), false)
end

T["corrupt state file falls back to defaults"] = function()
  local fd = assert(io.open(tmp, "w"))
  fd:write("{ this is not valid json ")
  fd:close()
  package.loaded["lumiris.state"] = nil
  local state = require("lumiris.state")
  eq(state.weight("anything"), 0)
end

return T
