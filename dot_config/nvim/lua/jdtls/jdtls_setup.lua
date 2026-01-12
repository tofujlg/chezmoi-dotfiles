local M = {}

function M:setup()
  local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
  local workspace_dir = vim.fn.stdpath("data")
    .. package.config:sub(1, 1)
    .. "jdtls-workspace"
    .. package.config:sub(1, 1)
    .. project_name

  -- Java 21+ is required to run JDTLS itself
  local jdtls_java_home = "/Library/Java/JavaVirtualMachines/zulu-21.jdk/Contents/Home"
  -- Java 11 for your project compilation/runtime
  local project_java_home = "/Library/Java/JavaVirtualMachines/zulu-11.jdk/Contents/Home"

  -- Lombok JAR path
  local lombok_path = "/Users/tofuredbull/.m2/repository/org/projectlombok/lombok/1.18.20/lombok-1.18.20.jar"

  -- Find jdtls JAR and configuration directory
  local jdtls_jar = vim.fn.glob("~/.local/share/nvim/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar")
  local jdtls_config = vim.fn.glob("~/.local/share/nvim/mason/packages/jdtls/config_mac")

  -- See `:help vim.lsp.start` for an overview of the supported `config` options.
  local config = {
    name = "jdtls",

    -- `cmd` defines the executable to launch eclipse.jdt.ls.
    -- Use full Java command to allow adding Lombok agent
    cmd = {
      jdtls_java_home .. "/bin/java",
      "-Declipse.application=org.eclipse.jdt.ls.core.id1",
      "-Dosgi.bundles.defaultStartLevel=4",
      "-Declipse.product=org.eclipse.jdt.ls.core.product",
      "-Dlog.protocol=true",
      "-Dlog.level=ALL",
      "-Xmx1g",
      "--add-modules=ALL-SYSTEM",
      "--add-opens",
      "java.base/java.util=ALL-UNNAMED",
      "--add-opens",
      "java.base/java.lang=ALL-UNNAMED",
      "-javaagent:" .. lombok_path, -- Lombok agent for annotation processing
      "-jar",
      jdtls_jar,
      "-configuration",
      jdtls_config,
      "-data",
      workspace_dir,
    },

    -- `root_dir` must point to the root of your project.
    -- See `:help vim.fs.root`
    root_dir = vim.fs.root(0, { "gradlew", ".git", "mvnw" }),

    -- Here you can configure eclipse.jdt.ls specific settings
    -- See https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
    -- for a list of options
    settings = {
      java = {
        -- Configure project to use Java 11
        configuration = {
          runtimes = {
            {
              name = "JavaSE-11",
              path = project_java_home,
              default = true,
            },
          },
        },
        -- Set source and target compatibility to Java 11
        eclipse = {
          downloadSources = true,
        },
        maven = {
          downloadSources = true,
        },
        implementationsCodeLens = {
          enabled = true,
        },
        referencesCodeLens = {
          enabled = true,
        },
        references = {
          includeDecompiledSources = true,
        },
        format = {
          enabled = true,
        },
      },
    },

    -- This sets the `initializationOptions` sent to the language server
    -- If you plan on using additional eclipse.jdt.ls plugins like java-debug
    -- you'll need to set the `bundles`
    --
    -- See https://codeberg.org/mfussenegger/nvim-jdtls#java-debug-installation
    --
    -- Setup java-debug bundle for DAP support
    init_options = {
      bundles = {},
    },
  }

  -- Find and add java-debug bundle if available
  local java_debug_path = vim.fn.glob("~/.local/share/nvim/mason/packages/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar")
  if java_debug_path ~= "" then
    config.init_options.bundles = { java_debug_path }
  end

  require("jdtls").start_or_attach(config)

  -- Setup DAP for Java
  local jdtls = require("jdtls")
  local dap = require("dap")
  
  -- Store Java path for DAP to use
  local java_executable = project_java_home .. "/bin/java"
  
  -- Set JAVA_HOME environment variable for the Java debug adapter
  -- This is critical - the adapter uses JAVA_HOME to find Java
  vim.env.JAVA_HOME = project_java_home
  
  -- Also set it in the process environment (for subprocesses)
  if vim.fn.has("win32") == 0 then
    -- Unix-like systems
    vim.env.PATH = project_java_home .. "/bin:" .. vim.env.PATH
  end
  
  -- Setup DAP - this creates the adapter and basic configurations
  -- Pass the Java executable so jdtls knows which Java to use
  jdtls.setup_dap({
    hotcodereplace = "auto",
  })
  
  -- After setup_dap, ensure javaExecutable is set on all launch configs
  -- jdtls.setup_dap() should handle classpaths automatically, but we need to ensure Java path is set
  local function fix_java_configs()
    if dap.configurations.java then
      for _, cfg in ipairs(dap.configurations.java) do
        if cfg.request == "launch" then
          -- ALWAYS set javaExecutable - this is critical
          cfg.javaExecutable = java_executable
          
          -- Set projectRoot explicitly
          if not cfg.projectRoot or cfg.projectRoot == "${workspaceFolder}" then
            cfg.projectRoot = vim.fn.getcwd()
          end
          
          -- Wrap mainClass resolution to ensure it works correctly
          if type(cfg.mainClass) == "function" then
            local original_main_class = cfg.mainClass
            cfg.mainClass = function()
              local result = original_main_class()
              -- Ensure javaExecutable is set before mainClass is resolved
              cfg.javaExecutable = java_executable
              return result
            end
          elseif cfg.mainClass == "${file}" then
            -- Resolve ${file} to actual main class
            -- Note: This only works for classes with main() methods
            -- For AEM Sling Models, use "Debug (Attach)" instead
            cfg.mainClass = function()
              local current_file = vim.api.nvim_buf_get_name(0)
              if not current_file or current_file == "" then
                return vim.fn.input("Main class > ")
              end
              
              -- Use jdtls to resolve main class (most reliable)
              local ok, resolved = pcall(jdtls.resolve_main_class, current_file)
              if ok and resolved and resolved ~= "" then
                return resolved
              end
              
              -- Fallback: convert file path to package.class
              local package_path = current_file:match("src/main/java/(.+)%.java$")
              if package_path then
                return package_path:gsub("/", ".")
              end
              
              package_path = current_file:match("src/(.+)%.java$")
              if package_path then
                return package_path:gsub("/", ".")
              end
              
              -- Last resort
              return vim.fn.input("Main class > ", current_file)
            end
          end
        end
      end
    end
  end
  
  -- Fix configs immediately
  vim.defer_fn(fix_java_configs, 100)
  
  -- Also fix whenever Java file is opened
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
      vim.defer_fn(fix_java_configs, 50)
    end,
  })

  -- CRITICAL: Ensure javaExecutable is set on ALL launch configurations
  -- This must happen after setup_dap() and be applied to all configs
  local function ensure_java_executable()
    if dap.configurations.java then
      for i, cfg in ipairs(dap.configurations.java) do
        if cfg.request == "launch" then
          -- Force set javaExecutable - this is the key fix
          cfg.javaExecutable = java_executable
          -- Also ensure projectRoot is set if missing
          if not cfg.projectRoot then
            cfg.projectRoot = vim.fn.getcwd()
          end
        end
      end
    end
  end
  
  -- Apply immediately after setup_dap
  vim.defer_fn(function()
    ensure_java_executable()
  end, 200)
  
  -- Also set it right before DAP launches (as final safety net)
  -- This ensures javaExecutable is set even if configs were modified
  vim.api.nvim_create_autocmd("User", {
    pattern = "DapDebugPre",
    callback = function()
      ensure_java_executable()
    end,
  })
  
  -- Set it whenever a Java file is opened (ensures it's always current)
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
      vim.defer_fn(ensure_java_executable, 100)
    end,
  })
  
  -- Hook into DAP launch to ensure javaExecutable is always set
  -- This runs right before the adapter is called
  vim.api.nvim_create_autocmd("User", {
    pattern = "DapDebugPre",
    callback = function(data)
      local config = data and data.data and data.data.config
      if config and config.type == "java" and config.request == "launch" then
        config.javaExecutable = java_executable
        if not config.projectRoot then
          config.projectRoot = vim.fn.getcwd()
        end
      end
    end,
  })
  
  -- Also hook into the actual DAP run command
  local dap_run = dap.run
  if dap_run then
    dap.run = function(config, opts)
      if config and config.type == "java" and config.request == "launch" then
        config.javaExecutable = java_executable
        if not config.projectRoot then
          config.projectRoot = vim.fn.getcwd()
        end
      end
      return dap_run(config, opts)
    end
  end
end

return M
