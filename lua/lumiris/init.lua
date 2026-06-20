local M = {}

---Configure lumiris and start automatic colorscheme rotation.
---@param opts? lumiris.Options
function M.setup(opts)
  require("lumiris.config").setup(opts)
  math.randomseed(vim.uv.now())
  require("lumiris.command").register()
  require("lumiris.autocmd").register()

  -- Without an active colorscheme the session sits on `default` until the first
  -- timer/event switch (up to `interval` seconds away), and `:LumirisHate` /
  -- `:LumirisLike` have no current scheme to act on. Pick one so lumiris is in
  -- control from the start. A colorscheme already chosen (by the user's config)
  -- is left untouched.
  local function escape_default()
    local cur = vim.g.colors_name
    if not cur or cur == "" then
      require("lumiris.colorscheme").rotate({ force = true })
    end
  end
  -- Defer to VimEnter during startup so a colorscheme the user sets *after*
  -- setup() wins (no double-load / flash). If Neovim has already entered
  -- (setup() called interactively, or under the test harness), run it now and
  -- keep the call synchronous.
  if vim.v.vim_did_enter == 1 then
    escape_default()
  else
    vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = escape_default })
  end
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
  if cur == "" then
    cur = nil
  end
  name = name or cur
  if name then
    require("lumiris.state").hate(name)
  end
  -- Switch away when excluding the active scheme, or when nothing is active yet
  -- (stuck on default), so the call always makes progress instead of no-op'ing.
  if name == cur or cur == nil then
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
