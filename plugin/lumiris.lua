-- Eager registration so the `:Lumiris*` commands work without calling
-- `require("lumiris").setup()` (convention over configuration). The automatic
-- rotation timer/autocmd is opt-in and only starts from `setup()`.
if vim.g.loaded_lumiris then
  return
end
vim.g.loaded_lumiris = true

require("lumiris.command").register()
