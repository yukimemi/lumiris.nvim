local M = {}

-- vim.uv.now() (ms) of the last successful apply. `nil` = clock not primed yet.
local last_change_ms = nil

-- Discovered colorschemes from `colors_path`: name -> plugin root (the dir to
-- prepend to the runtimepath as an apply fallback). Filled asynchronously by
-- M.scan() so the UI never blocks; `nil` until the first scan completes.
local discovered = nil ---@type table<string, string>|nil
local scanning = false -- in-flight guard so concurrent calls don't double-walk

local function cfg()
  return require("lumiris.config").options
end

-- Derive name + plugin root from a "/"-separated colorscheme file path using
-- pure string ops only, so it is safe inside libuv (fast) callbacks where
-- vim.fn.* must not be called. e.g. ".../demo.nvim/colors/foo.lua" -> "foo",
-- ".../demo.nvim".
local function entry_of(file)
  local name = file:match("([^/]+)%.[^./]+$")
  local root = file:match("^(.*)/colors/[^/]+$")
  return name, root
end

-- Directory names never worth descending into when hunting for colorschemes.
local PRUNE_DIRS = { [".git"] = true, ["node_modules"] = true }

-- Non-blocking recursive walk of `root` via vim.uv, collecting files that live
-- directly under a `colors/` dir. `on_done` fires (in the libuv/fast context)
-- once every outstanding scandir has drained. Hidden dirs and a few heavy dir
-- names are pruned; everything else is descended so colorschemes nested under
-- subdirectories (collection-style plugins) are still found.
local function walk_async(root, on_done)
  local files = {}
  local active = 0

  -- `in_colors` is true when `dir` itself is a colors/ directory.
  local function scan(dir, in_colors)
    active = active + 1
    vim.uv.fs_scandir(dir, function(err, handle)
      if not err and handle then
        while true do
          local name, typ = vim.uv.fs_scandir_next(handle)
          if not name then
            break
          end
          local full = dir .. "/" .. name
          if typ == "directory" then
            if name:sub(1, 1) ~= "." and not PRUNE_DIRS[name] then
              scan(full, name == "colors")
            end
          elseif in_colors then
            local ext = name:sub(-4)
            if ext == ".lua" or ext == ".vim" then
              files[#files + 1] = full
            end
          end
        end
      end
      active = active - 1
      if active == 0 then
        on_done(files)
      end
    end)
  end

  scan(root, false)
end

---Asynchronously scan `colors_path` and cache the name -> root map. The UI is
---never blocked. `on_done(map)` (optional) fires once the cache is ready, in a
---scheduled (API-safe) context. No-op while a scan is already in flight.
---@param on_done? fun(map: table<string, string>)
function M.scan(on_done)
  if discovered then
    if on_done then
      on_done(discovered)
    end
    return
  end
  if scanning then
    return
  end
  scanning = true

  local dirs = {}
  for _, d in ipairs(cfg().colors_path or {}) do
    local nd = vim.fs.normalize(d)
    if vim.fn.isdirectory(nd) == 1 then
      dirs[#dirs + 1] = nd
    end
  end

  local acc = {}
  local remaining = #dirs

  local function finish()
    vim.schedule(function()
      discovered = acc
      scanning = false
      if on_done then
        on_done(acc)
      end
    end)
  end

  if remaining == 0 then
    return finish()
  end

  for _, dir in ipairs(dirs) do
    walk_async(dir, function(found)
      for _, file in ipairs(found) do
        local name, droot = entry_of(file)
        if name and droot and acc[name] == nil then
          acc[name] = droot
        end
      end
      remaining = remaining - 1
      if remaining == 0 then
        finish()
      end
    end)
  end
end

---Drop the discovery cache (call after `colors_path` changes).
function M.refresh()
  discovered = nil
  scanning = false
end

-- Kick off discovery if it has neither completed nor started. Non-blocking.
local function ensure_scan()
  if discovered == nil and not scanning then
    M.scan()
  end
end

---Installed colorschemes after applying include / exclude / hated filters.
---Union of runtimepath colorschemes and those discovered under `colors_path`.
---@return string[]
function M.candidates()
  local options = cfg()
  local state = require("lumiris.state")

  local seen, all = {}, {}
  local function add(name)
    if not seen[name] then
      seen[name] = true
      all[#all + 1] = name
    end
  end
  for _, name in ipairs(vim.fn.getcompletion("", "color")) do
    add(name)
  end
  ensure_scan() -- warm the cache in the background; use whatever is ready now
  for name in pairs(discovered or {}) do
    add(name)
  end

  local include_set
  if options.include and #options.include > 0 then
    include_set = {}
    for _, n in ipairs(options.include) do
      include_set[n] = true
    end
  end
  local exclude_set = {}
  for _, n in ipairs(options.exclude or {}) do
    exclude_set[n] = true
  end

  local out = {}
  for _, name in ipairs(all) do
    local keep = true
    if include_set and not include_set[name] then
      keep = false
    elseif exclude_set[name] then
      keep = false
    elseif state.is_hated(name) then
      keep = false
    end
    if keep then
      out[#out + 1] = name
    end
  end
  return out
end

---Weighted-random pick avoiding `current` when alternatives exist.
---Like score shifts the baseline weight of 1; floors at 1 so disliked-but-not-hated
---schemes stay selectable.
---@param current? string
---@return string|nil
function M.pick(current)
  local state = require("lumiris.state")
  local cands = M.candidates()

  if current and #cands > 1 then
    local filtered = {}
    for _, n in ipairs(cands) do
      if n ~= current then
        filtered[#filtered + 1] = n
      end
    end
    cands = filtered
  end
  if #cands == 0 then
    return nil
  end

  local weights, total = {}, 0
  for i, name in ipairs(cands) do
    local w = state.weight(name) + 1
    if w < 1 then
      w = 1
    end
    weights[i] = w
    total = total + w
  end

  local roll = math.random() * total
  local acc = 0
  for i, name in ipairs(cands) do
    acc = acc + weights[i]
    if roll <= acc then
      return name
    end
  end
  return cands[#cands]
end

---Apply a colorscheme. Returns false (and logs) if the scheme errors out.
---@param name string
---@return boolean
function M.apply(name)
  local options = cfg()
  if options.background == "dark" or options.background == "light" then
    vim.o.background = options.background
  end

  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    -- The plugin manager (rvpm / lazy.nvim) normally lazy-loads the owning
    -- plugin on `:colorscheme` via a ColorSchemePre hook, so the first attempt
    -- usually succeeds. Fallback for unmanaged setups: put the discovered
    -- plugin root on the runtimepath and retry once.
    local root = (discovered or {})[name]
    if root and not vim.o.runtimepath:find(root, 1, true) then
      vim.opt.runtimepath:prepend(root)
      ok, err = pcall(vim.cmd.colorscheme, name)
    end
  end
  if not ok then
    require("lumiris.log").warn(("failed to apply '%s': %s"):format(name, tostring(err)))
    return false
  end
  require("lumiris.state").last = name
  last_change_ms = vim.uv.now()
  require("lumiris.log").info("colorscheme -> " .. name)
  return true
end

---Prime the interval clock without switching (called on register/setup) so the
---first event after startup does not immediately flip the colorscheme.
function M.prime()
  last_change_ms = vim.uv.now()
end

---Switch to a new colorscheme. The timer and autocmd call this without args; it
---is rate-limited by `interval` and skipped while disabled. `force = true`
---(from `:LumirisChange`) bypasses both gates.
---@param opts? { force?: boolean }
---@return string|nil applied
function M.rotate(opts)
  opts = opts or {}
  local state = require("lumiris.state")
  if not opts.force and not state.enabled then
    return nil
  end

  local options = cfg()
  if not opts.force and options.interval and options.interval > 0 then
    if last_change_ms == nil then
      last_change_ms = vim.uv.now() -- first tick primes; no switch yet
      return nil
    end
    if (vim.uv.now() - last_change_ms) < (options.interval * 1000) then
      return nil
    end
  end

  local current = vim.g.colors_name
  for _ = 1, 5 do
    local name = M.pick(current)
    if not name then
      require("lumiris.log").debug("lumiris: no candidate colorschemes")
      return nil
    end
    if M.apply(name) then
      return name
    end
    current = name -- failed to apply; try a different one
  end
  return nil
end

return M
