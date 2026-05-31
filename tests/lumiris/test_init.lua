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
