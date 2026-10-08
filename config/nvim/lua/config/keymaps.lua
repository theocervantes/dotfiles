-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- kk leaves insert and visual mode
vim.keymap.set({ "i", "v" }, "kk", "<Esc>", { desc = "Escape" })
