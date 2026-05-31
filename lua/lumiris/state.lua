local M = {}

-- Runtime (non-persisted) state.
M.enabled = true
M.last = nil ---@type string|nil  last successfully applied colorscheme

---@class lumiris.Prefs
---@field version integer
---@field weights table<string, integer>  per-colorscheme like score (higher = picked more often)
---@field hated table<string, boolean>    colorschemes excluded from rotation

local prefs ---@type lumiris.Prefs|nil  in-memory cache

local function default_prefs()
  return { version = 1, weights = {}, hated = {} }
end

local function path()
  return require("lumiris.config").options.state_path
end

---Load preferences from disk (cached). Corrupt/missing files yield defaults.
---@return lumiris.Prefs
function M.load()
  if prefs then
    return prefs
  end
  local fd = io.open(path(), "r")
  if not fd then
    prefs = default_prefs()
    return prefs
  end
  local content = fd:read("*a")
  fd:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    prefs = vim.tbl_deep_extend("force", default_prefs(), decoded)
  else
    prefs = default_prefs()
  end
  return prefs
end

---Persist the in-memory preferences to disk.
---@return boolean
function M.save()
  local p = path()
  vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
  local fd, err = io.open(p, "w")
  if not fd then
    require("lumiris.log").warn("cannot write prefs: " .. (err or p))
    return false
  end
  fd:write(vim.json.encode(M.load()))
  fd:close()
  return true
end

---Boost the like score of a colorscheme (and un-hate it).
---@param name string
function M.like(name)
  local pr = M.load()
  pr.weights[name] = (pr.weights[name] or 0) + 1
  pr.hated[name] = nil
  M.save()
end

---Exclude a colorscheme from rotation.
---@param name string
function M.hate(name)
  local pr = M.load()
  pr.hated[name] = true
  M.save()
end

---@param name string
---@return integer
function M.weight(name)
  return M.load().weights[name] or 0
end

---@param name string
---@return boolean
function M.is_hated(name)
  return M.load().hated[name] == true
end

return M
