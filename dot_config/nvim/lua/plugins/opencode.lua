return {
  "NickvanDyke/opencode.nvim",
  dependencies = {
    -- Recommended for `ask()` and `select()`.
    -- Required for `snacks` provider.
    ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
    { "folke/snacks.nvim" },
  },
  enabled = true,
  keys = {
    {
      "<leader>oa",
      function()
        require("opencode").ask()
      end,
      desc = "Ask opencode",
      mode = "n",
    },
    {
      "<leader>oa",
      function()
        require("opencode").ask()
      end,
      desc = "Ask opencode about selection",
      mode = "v",
    },
  },
}
