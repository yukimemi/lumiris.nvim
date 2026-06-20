local M = {}

local function current_colors()
  local name = vim.g.colors_name
  if not name or name == "" then
    return nil
  end
  return name
end

---Register the `:Lumiris*` user commands. Safe to call more than once.
function M.register()
  local function cmd(name, fn, desc)
    vim.api.nvim_create_user_command(name, fn, { desc = desc })
  end

  cmd("LumirisChange", function()
    require("lumiris.colorscheme").rotate({ force = true })
  end, "lumiris: switch to a new colorscheme now")

  cmd("LumirisLike", function()
    local cur = current_colors()
    if not cur then
      require("lumiris.log").echo("no active colorscheme to like")
      return
    end
    local state = require("lumiris.state")
    state.like(cur)
    require("lumiris.log").echo(("liked '%s' (weight %d)"):format(cur, state.weight(cur)))
  end, "lumiris: boost the current colorscheme")

  cmd("LumirisHate", function()
    local cur = current_colors()
    if cur then
      require("lumiris.state").hate(cur)
      require("lumiris.log").echo(("hated '%s' (excluded from rotation)"):format(cur))
    else
      -- Stuck on `default` (no current scheme to hate). Still switch away so the
      -- key always does something visible instead of silently no-op'ing.
      require("lumiris.log").echo("no active colorscheme to hate; switching anyway")
    end
    require("lumiris.colorscheme").rotate({ force = true })
  end, "lumiris: exclude the current colorscheme and switch away")

  cmd("LumirisEnable", function()
    require("lumiris.state").enabled = true
    require("lumiris.log").echo("automatic switching enabled")
  end, "lumiris: resume automatic switching")

  cmd("LumirisDisable", function()
    require("lumiris.state").enabled = false
    require("lumiris.log").echo("automatic switching disabled")
  end, "lumiris: pause automatic switching")

  cmd("LumirisToggle", function()
    local state = require("lumiris.state")
    state.enabled = not state.enabled
    require("lumiris.log").echo(state.enabled and "automatic switching enabled" or "automatic switching disabled")
  end, "lumiris: toggle automatic switching")
end

return M
