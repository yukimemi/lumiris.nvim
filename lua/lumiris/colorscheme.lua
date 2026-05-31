local M = {}

-- vim.uv.now() (ms) of the last successful apply. `nil` = clock not primed yet.
local last_change_ms = nil

-- Discovered colorschemes from `colors_path`: name -> plugin root (the dir to
-- prepend to the runtimepath before `:colorscheme name` can succeed). Cached;
-- cleared by `M.refresh()`.
local discovered = nil ---@type table<string, string>|nil

local function cfg()
  return require("lumiris.config").options
end

---Scan `colors_path` for `**/colors/*.{vim,lua}` and map each colorscheme name
---to its plugin root. First match wins so runtimepath/built-ins are not shadowed.
---@return table<string, string>
local function discover()
  if discovered then
    return discovered
  end
  discovered = {}
  for _, dir in ipairs(cfg().colors_path or {}) do
    if vim.fn.isdirectory(dir) == 1 then
      for _, ext in ipairs({ "vim", "lua" }) do
        for _, file in ipairs(vim.fn.globpath(dir, "**/colors/*." .. ext, false, true)) do
          local name = vim.fn.fnamemodify(file, ":t:r")
          if name ~= "" and discovered[name] == nil then
            discovered[name] = vim.fn.fnamemodify(file, ":h:h")
          end
        end
      end
    end
  end
  return discovered
end

---Drop the discovery cache (call after `colors_path` changes).
function M.refresh()
  discovered = nil
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
  for name in pairs(discover()) do
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
    local root = discover()[name]
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
