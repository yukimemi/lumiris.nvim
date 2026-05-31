local M = {}

---Configure lumiris and start automatic colorscheme rotation.
---@param opts? lumiris.Options
function M.setup(opts)
  require("lumiris.config").setup(opts)
  math.randomseed(vim.uv.now())
  require("lumiris.command").register()
  require("lumiris.autocmd").register()
end

-- Convenience Lua API mirroring the `:Lumiris*` commands.

---Switch to a new colorscheme now.
---@return string|nil applied
function M.change()
  return require("lumiris.colorscheme").rotate({ force = true })
end

---@param name? string  defaults to the current colorscheme
function M.like(name)
  name = name or vim.g.colors_name
  if name and name ~= "" then
    require("lumiris.state").like(name)
  end
end

---@param name? string  defaults to the current colorscheme
function M.hate(name)
  local cur = vim.g.colors_name
  name = name or cur
  if not name or name == "" then
    return
  end
  require("lumiris.state").hate(name)
  -- Switch away only when excluding the colorscheme that is currently active.
  if name == cur then
    require("lumiris.colorscheme").rotate({ force = true })
  end
end

function M.enable()
  require("lumiris.state").enabled = true
end

function M.disable()
  require("lumiris.state").enabled = false
end

---@return string[]
function M.candidates()
  return require("lumiris.colorscheme").candidates()
end

return M
