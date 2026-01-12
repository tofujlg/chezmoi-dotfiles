return {
  "sindrets/diffview.nvim",
  keys = {
    { "<leader>gd", ":DiffviewOpen<CR>", desc = "Open diffview" },
    { "<leader>gq", ":DiffviewClose<CR>", desc = "Close diffview" },
  },
  config = function()
    -- Add keybinding to close diffview in diffview buffers
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "DiffviewFiles",
      callback = function()
        vim.keymap.set("n", "q", ":DiffviewClose<CR>", { buffer = true, desc = "Close diffview" })
        vim.keymap.set("n", "<Esc>", ":DiffviewClose<CR>", { buffer = true, desc = "Close diffview" })
      end,
    })
  end,
}
