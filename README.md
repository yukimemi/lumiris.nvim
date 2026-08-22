<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/yukimemi/lumiris.nvim/main/assets/logo-dark.svg">
  <img src="https://raw.githubusercontent.com/yukimemi/lumiris.nvim/main/assets/logo.svg" alt="lumiris — auto-rotate your Neovim colorschemes" width="520">
</picture>

<p><em>auto-rotate your Neovim colorschemes.</em></p>

[![CI](https://github.com/yukimemi/lumiris.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/yukimemi/lumiris.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/yukimemi/lumiris.nvim/blob/main/LICENSE)
[![Neovim 0.10+](https://img.shields.io/badge/Neovim-0.10+-57A143?logo=neovim&logoColor=white)](https://neovim.io)

</div>

Automatically rotate through your installed colorschemes, with per-scheme
like/hate preferences that persist across sessions. A pure-Lua, Neovim-only
rewrite of [lumiris.vim](https://github.com/yukimemi/lumiris.vim) (no Deno /
denops dependency).

## Requirements

- Neovim >= 0.10 (`vim.uv`, `vim.health.start`)

## Install

With [rvpm](https://github.com/yukimemi/rvpm) (recommended):

```sh
rvpm add yukimemi/lumiris.nvim --on-event CursorHold --on-cmd '/^Lumiris.*$/'
```

Or in `config.toml`:

```toml
[[plugins]]
url = "https://github.com/yukimemi/lumiris.nvim"
on_event = "CursorHold"
on_cmd = ["/^Lumiris.*$/"]
opts = {} # rvpm calls setup(opts) — e.g. { interval = 3600 }, same values as lazy.nvim below
```

> Here `setup()` is **required**: the commands come up either way, but nothing
> is switched automatically until `require("lumiris").setup(...)` installs the
> autocmds. **rvpm >= 3.45.0 handles it for you** — put `opts = {}` (or your
> options) in the `[[plugins]]` entry and rvpm calls
> `require("lumiris").setup(<opts>)` right before the plugin's `after.lua`
> (same convention as lazy.nvim's `opts`). Use a hook
> (`rvpm edit yukimemi/lumiris.nvim --after`) only when the options need a Lua
> function, which TOML cannot express.

Or with [lazy.nvim](https://github.com/folke/lazy.nvim):

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

`setup()` picks a colorscheme immediately when none is active yet, so a fresh
session never sits on `default` waiting for the first `interval` to elapse. If
your config already set a colorscheme, it is left untouched.

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
