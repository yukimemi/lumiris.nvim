local M = {}

local AUGROUP = "lumiris"
local timer ---@type uv_timer_t|nil

function M.stop_timer()
  if timer then
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
    timer = nil
  end
end

---(Re)start the periodic rotation timer. `interval <= 0` leaves it stopped
---(event-only mode).
function M.start_timer()
  M.stop_timer()
  local secs = require("lumiris.config").options.interval or 0
  if secs <= 0 then
    return
  end
  local ms = secs * 1000
  timer = vim.uv.new_timer()
  timer:start(ms, ms, function()
    vim.schedule(function()
      require("lumiris.colorscheme").rotate()
    end)
  end)
end

---Install the autocmd + timer. Idempotent: clears the augroup and resets the
---timer, so calling `setup()` again re-applies cleanly.
function M.register()
  local options = require("lumiris.config").options
  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  if options.events and #options.events > 0 then
    vim.api.nvim_create_autocmd(options.events, {
      group = group,
      callback = function()
        require("lumiris.colorscheme").rotate()
      end,
    })
  end
  local cs = require("lumiris.colorscheme")
  cs.refresh() -- colors_path may have changed since the last register
  cs.scan() -- warm the discovery cache in the background (non-blocking)
  cs.prime()
  M.start_timer()
end

function M.unregister()
  pcall(vim.api.nvim_del_augroup_by_name, AUGROUP)
  M.stop_timer()
end

return M
