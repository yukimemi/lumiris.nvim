# lumiris.nvim

Automatically rotate through your installed colorschemes, with per-scheme
like/hate preferences that persist across sessions.

A pure-Lua, Neovim-only rewrite of [lumiris.vim](https://github.com/yukimemi/lumiris.vim)
(no Deno / denops dependency).

## Requirements

- Neovim >= 0.10 (`vim.uv`, `vim.health.start`)

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yukimemi/lumiris.nvim",
  event = "VeryLazy",
  opts = {
    interval = 3600, -- seconds between automatic switches (0 = on every event)
  },
}
```

`opts` is passed straight to `require("lumiris").setup()`.

## Configuration

Defaults:

```lua
require("lumiris").setup({
  notify = false,                          -- vim.notify for background events (gated by log_level)
  log_level = "warn",                      -- "trace"|"debug"|"info"|"warn"|"error"
  interval = 3600,                         -- seconds; 0 = switch on every event
  events = { "FocusLost", "CursorHold" },  -- events that may trigger a switch (rate-limited by interval)
  background = nil,                        -- "dark"|"light"|nil (force &background before applying)
  include = {},                            -- allowlist of colorscheme names (empty = all installed)
  exclude = {},                            -- denylist of colorscheme names
  state_path = vim.fn.stdpath("state") .. "/lumiris/prefs.json",
})
```

`interval` rate-limits switching: events fire often (e.g. `CursorHold`) but the
colorscheme only changes once `interval` seconds have elapsed. Set `interval = 0`
to switch on *every* event instead.

## Commands

| Command | Action |
| --- | --- |
| `:LumirisChange` | Switch to a new colorscheme now (ignores the interval) |
| `:LumirisLike` | Boost the current colorscheme (picked more often) |
| `:LumirisHate` | Exclude the current colorscheme and switch away |
| `:LumirisEnable` / `:LumirisDisable` / `:LumirisToggle` | Control automatic switching |

The commands are available without calling `setup()`; only the automatic
rotation needs `setup()`.

## Lua API

```lua
local lumiris = require("lumiris")
lumiris.change()         -- == :LumirisChange
lumiris.like("habamax")  -- defaults to current colorscheme
lumiris.hate("blue")
lumiris.enable()
lumiris.disable()
lumiris.candidates()     -- string[] of eligible colorschemes
```

Preferences are stored as JSON at `state_path`.

## Health

```vim
:checkhealth lumiris
```

## License

MIT
