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

T["hate of the current colorscheme excludes it and switches away"] = function()
  local lumiris = require("lumiris")
  local cs = require("lumiris.colorscheme")
  local cands = cs.candidates()
  if #cands < 2 then
    MiniTest.skip("need >= 2 colorschemes")
  end

  cs.apply(cands[1])
  local victim = vim.g.colors_name
  lumiris.hate() -- no arg = current

  eq(require("lumiris.state").is_hated(victim), true)
  eq(vim.g.colors_name ~= victim, true)
end

T["setup applies a colorscheme when none is active (escapes default)"] = function()
  local cs = require("lumiris.colorscheme")
  if #cs.candidates() == 0 then
    MiniTest.skip("no colorschemes available")
  end
  vim.g.colors_name = nil -- simulate the fresh-startup default state
  require("lumiris").setup({ state_path = vim.fn.tempname(), interval = 0 })
  eq(vim.g.colors_name ~= nil and vim.g.colors_name ~= "", true)
end

T["setup leaves an already-active colorscheme untouched"] = function()
  local cs = require("lumiris.colorscheme")
  local cands = cs.candidates()
  if #cands == 0 then
    MiniTest.skip("no colorschemes available")
  end
  cs.apply(cands[1])
  local chosen = vim.g.colors_name
  require("lumiris").setup({ state_path = vim.fn.tempname(), interval = 0 })
  eq(vim.g.colors_name, chosen)
end

T["LumirisHate with no active colorscheme switches anyway"] = function()
  local cs = require("lumiris.colorscheme")
  if #cs.candidates() == 0 then
    MiniTest.skip("no colorschemes available")
  end
  require("lumiris.command").register()
  vim.g.colors_name = nil
  vim.cmd("LumirisHate")
  eq(vim.g.colors_name ~= nil and vim.g.colors_name ~= "", true)
end

T["LumirisLike with no active colorscheme is a harmless no-op"] = function()
  require("lumiris.command").register()
  vim.g.colors_name = nil
  -- Must not error even though there is nothing to like.
  vim.cmd("LumirisLike")
end

T["hate of a non-current scheme excludes it but does not switch"] = function()
  local lumiris = require("lumiris")
  local cs = require("lumiris.colorscheme")
  local cands = cs.candidates()
  if #cands < 2 then
    MiniTest.skip("need >= 2 colorschemes")
  end

  cs.apply(cands[1])
  local current = vim.g.colors_name
  local other
  for _, n in ipairs(cands) do
    if n ~= current then
      other = n
      break
    end
  end

  lumiris.hate(other)
  eq(require("lumiris.state").is_hated(other), true)
  eq(vim.g.colors_name, current) -- unchanged
end

return T
