-- Jump to a relative line number by typing it on the home row.
-- <Space>e jumps down and <Space>n jumps up, then the home row keys are the
-- digits 1234567890.
return {
  {
    "prendradjaja/vim-vertigo",
    init = function()
      -- Colemak-DH home row. Must be set before the plugin loads.
      vim.g.Vertigo_homerow = "arstgmneio"
    end,
    config = function()
      for _, mode in ipairs({ "n", "v", "o" }) do
        vim.keymap.set(mode, "<Space>e", ":<C-U>VertigoDown " .. mode .. "<CR>", { silent = true, desc = "Vertigo down" })
        vim.keymap.set(mode, "<Space>n", ":<C-U>VertigoUp " .. mode .. "<CR>", { silent = true, desc = "Vertigo up" })
      end
    end,
  },

  -- LazyVim uses <Space>e (file explorer) and <Space>n (notification history).
  -- Free them for vertigo. The explorer is still on <Space>E and <Space>fe.
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>e", false },
      { "<leader>n", false },
    },
  },
}
