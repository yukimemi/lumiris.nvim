local M = {}

---@class lumiris.Options
---@field notify boolean        Emit `vim.notify` for background events (gated by `log_level`). Default false.
---@field log_level "trace"|"debug"|"info"|"warn"|"error"  Minimum severity surfaced when `notify = true`. Default "warn".
---@field interval integer      Seconds between automatic switches. `0` = switch on every event. Default 3600.
---@field events string[]       Autocmd events that may trigger a switch (rate-limited by `interval`). Default {"FocusLost","CursorHold"}.
---@field background "dark"|"light"|nil  Force `&background` before applying. `nil` = leave as-is.
---@field include string[]      Allowlist of colorscheme names. Empty = all installed.
---@field exclude string[]      Denylist of colorscheme names.
---@field colors_path string[]  Extra dirs scanned for `**/colors/*.{vim,lua}` to enumerate colorscheme names that are not yet on the runtimepath (e.g. a plugin manager's lazy clone cache). Loading on apply is delegated to the manager's `:colorscheme` hook (rvpm / lazy.nvim); lumiris only falls back to runtimepath injection if that fails. Empty = rely on the runtimepath only.
---@field state_path string     JSON file holding persisted like/hate preferences.

M.defaults = {
  notify = false,
  log_level = "warn",
  interval = 3600,
  events = { "FocusLost", "CursorHold" },
  background = nil,
  include = {},
  exclude = {},
  colors_path = {},
  state_path = vim.fn.stdpath("state") .. "/lumiris/prefs.json",
}

M.options = vim.deepcopy(M.defaults)

---@param opts? lumiris.Options
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
