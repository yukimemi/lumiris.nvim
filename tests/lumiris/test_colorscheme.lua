local MiniTest = require("mini.test")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      require("lumiris.config").setup({ state_path = vim.fn.tempname() })
      package.loaded["lumiris.state"] = nil
    end,
  },
})

T["candidates honor the exclude list"] = function()
  require("lumiris.config").setup({ state_path = vim.fn.tempname(), exclude = { "desert" } })
  package.loaded["lumiris.state"] = nil
  local cands = require("lumiris.colorscheme").candidates()
  eq(vim.tbl_contains(cands, "desert"), false)
end

T["candidates honor the include allowlist"] = function()
  require("lumiris.config").setup({ state_path = vim.fn.tempname(), include = { "default" } })
  package.loaded["lumiris.state"] = nil
  local cands = require("lumiris.colorscheme").candidates()
  eq(cands, { "default" })
end

T["hated colorschemes drop out of candidates"] = function()
  local state = require("lumiris.state")
  local cands = require("lumiris.colorscheme").candidates()
  if #cands == 0 then
    MiniTest.skip("no colorschemes available")
  end
  local victim = cands[1]
  state.hate(victim)
  local after = require("lumiris.colorscheme").candidates()
  eq(vim.tbl_contains(after, victim), false)
end

T["pick avoids the current colorscheme"] = function()
  local cs = require("lumiris.colorscheme")
  local cands = cs.candidates()
  if #cands < 2 then
    MiniTest.skip("need >= 2 colorschemes")
  end
  local current = cands[1]
  for _ = 1, 30 do
    eq(cs.pick(current) ~= current, true)
  end
end

T["pick returns nil when nothing is available"] = function()
  require("lumiris.config").setup({ state_path = vim.fn.tempname(), include = { "definitely-not-a-real-scheme" } })
  package.loaded["lumiris.state"] = nil
  eq(require("lumiris.colorscheme").pick(nil), nil)
end

T["colors_path discovers off-runtimepath colorschemes"] = function()
  -- Lay out <root>/github.com/acme/demo.nvim/colors/lumiris_demo.lua
  local root = vim.fn.tempname()
  local plug = root .. "/github.com/acme/demo.nvim/colors"
  vim.fn.mkdir(plug, "p")
  local fd = assert(io.open(plug .. "/lumiris_demo.lua", "w"))
  fd:write("-- fake colorscheme for tests\n")
  fd:close()

  require("lumiris.config").setup({ state_path = vim.fn.tempname(), colors_path = { root } })
  package.loaded["lumiris.state"] = nil
  local cs = require("lumiris.colorscheme")
  cs.refresh()

  eq(vim.tbl_contains(cs.candidates(), "lumiris_demo"), true)
  vim.fn.delete(root, "rf")
end

return T
