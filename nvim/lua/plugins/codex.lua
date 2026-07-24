return {
  {
    "johnseth97/codex.nvim",

    -- 执行这些命令时才加载插件
    cmd = {
      "Codex",
      "CodexToggle",
    },

    -- 快捷键：Space a c
    keys = {
      {
        "<leader>ac",
        function()
          require("codex").toggle()
        end,
        desc = "Toggle Codex Agent",
        mode = { "n", "t" },
      },
    },

    opts = {
      -- Codex CLI 已经手动安装，禁止插件调用 npm 自动安装
      autoinstall = false,

      -- true：右侧面板
      -- false：中央浮动窗口
      panel = true,

      keymaps = {
        -- 避免插件额外注册冲突快捷键
        toggle = nil,

        -- 在 Codex 窗口内按 Ctrl+q 关闭窗口
        quit = "<C-q>",
      },

      -- 保持为终端 Buffer，能够完整运行 Codex TUI
      use_buffer = false,
    },
  },
}
