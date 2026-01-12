return {
  "mfussenegger/nvim-dap",
  config = function()
    local dap = require("dap")
    -- Get Java path from jdtls configuration if available
    -- Default to Java 11 path (project Java)
    local project_java_home = "/Library/Java/JavaVirtualMachines/zulu-11.jdk/Contents/Home"
    local java_exec = project_java_home .. "/bin/java"

    -- These will be used if jdtls.setup_dap() doesn't create them
    dap.configurations.java = {
      {
        type = "java",
        request = "launch",
        name = "Debug (Launch) - Custom Main Class",
        mainClass = function()
          return vim.fn.input("Main class (with package) > ", "", "file")
        end,
        projectRoot = "${workspaceFolder}",
        javaExecutable = java_exec,
        args = function()
          local args_string = vim.fn.input("Program arguments > ")
          if args_string == "" then
            return {}
          end
          return vim.split(args_string, " ", true)
        end,
      },
      {
        type = "java",
        request = "attach",
        name = "Debug (Attach) - AEM Local",
        hostName = "127.0.0.1",
        port = 5005,
      },
      {
        type = "java",
        request = "attach",
        name = "Debug (Attach) - Custom Port",
        hostName = "127.0.0.1",
        port = function()
          return tonumber(vim.fn.input("Port > ", "5005"))
        end,
      },
      {
        type = "java",
        request = "attach",
        name = "Debug (Attach) - Remote AEM",
        hostName = function()
          return vim.fn.input("Host > ", "localhost")
        end,
        port = function()
          return tonumber(vim.fn.input("Port > ", "5005"))
        end,
      },
    }
  end,
  dependencies = {
    {
      "mfussenegger/nvim-jdtls",
      config = function()
        -- Java DAP setup is handled in jdtls_setup.lua
        -- This ensures jdtls is loaded as a dependency
      end,
    },
  },
}
