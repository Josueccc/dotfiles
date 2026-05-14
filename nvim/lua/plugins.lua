-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({

    -- ── Colorscheme ───────────────────────────────────────────────────────
    {
        "olimorris/onedarkpro.nvim",
        priority = 1000,
        config = function()
            vim.cmd.colorscheme("onedark")
        end,
    },

    -- ── File tree (replaces NERDTree) ──────────────────────────────────────
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            -- disable netrw so nvim-tree takes over
            vim.g.loaded_netrw = 1
            vim.g.loaded_netrwPlugin = 1
            require("nvim-tree").setup()
        end,
    },

    -- ── Status bar (replaces vim-airline) ─────────────────────────────────
    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("lualine").setup({
                options = { theme = "onedark" },
            })
        end,
    },

    -- ── Editing utilities ──────────────────────────────────────────────────
    { "numToStr/Comment.nvim", config = true },
    { "tpope/vim-surround" },
    {
        "windwp/nvim-autopairs",   -- replaces jiangmiao/auto-pairs
        event = "InsertEnter",
        config = true,
    },

    -- ── Indent guides ──────────────────────────────────────────────────────
    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        config = true,
    },

    -- ── Treesitter (syntax, indentation, folding) ──────────────────────────
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter").setup({
                ensure_installed = {
                    "lua", "vim", "vimdoc",
                    "python", "rust",
                    "typescript", "javascript", "tsx",
                    "html", "css", "json", "sql",
                    "php", "svelte",
                },
            })
        end,
    },

    -- Auto-close HTML/JSX tags (replaces vim-closetag)
    {
        "windwp/nvim-ts-autotag",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = true,
    },

    -- ── Fuzzy finder (replaces fzf.vim + vim-esearch) ────────────────────
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            require("telescope").setup({
                defaults = {
                    layout_strategy = "horizontal",
                    mappings = {
                        i = {
                            ["<C-j>"] = "move_selection_next",
                            ["<C-k>"] = "move_selection_previous",
                        },
                    },
                },
            })
        end,
    },

    -- ── Fast motion (replaces vim-easymotion) ─────────────────────────────
    -- Use 's' in normal/visual for 2-char jump across the buffer
    {
        url = "https://codeberg.org/andyg/leap.nvim",
    },

    -- ── Transparent background ─────────────────────────────────────────────
    { "xiyaowong/transparent.nvim", config = true },

    -- ── Copilot ────────────────────────────────────────────────────────────
    -- ── Copilot (pure Lua, agent fetched separately — no heavy git bundle) ──
    {
        "zbirenbaum/copilot.lua",
        cmd   = "Copilot",
        event = "InsertEnter",
        config = function()
            require("copilot").setup({
                -- disable built-in suggestion/panel so copilot-cmp drives completion
                suggestion = { enabled = false },
                panel      = { enabled = false },
            })
        end,
    },
    {
        "zbirenbaum/copilot-cmp",
        dependencies = { "zbirenbaum/copilot.lua" },
        config = true,
    },
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        dependencies = { "nvim-lua/plenary.nvim", "zbirenbaum/copilot.lua" },
        config = true,
    },

    -- ── Claude Code ────────────────────────────────────────────────────────
    {
        "greggh/claude-code.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = true,
    },

    -- ── Flutter ────────────────────────────────────────────────────────────
    {
        "nvim-flutter/flutter-tools.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "stevearc/dressing.nvim",
        },
        config = true,
    },

    -- ── LSP + Mason ────────────────────────────────────────────────────────
    -- mason installs LSP server binaries; mason-lspconfig bridges to nvim-lspconfig.
    -- Servers that need Node.js (ts_ls, html, cssls, jsonls, eslint,
    -- intelephense, svelte) are only usable when node is present on the machine;
    -- servers without Node.js (pylsp, rust_analyzer, sqlls, lua_ls) always work.
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            require("mason").setup()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls",
                    "pylsp",         -- Python — no Node.js
                    "rust_analyzer", -- Rust   — no Node.js
                    "sqlls",         -- SQL    — no Node.js
                    "ts_ls",         -- TypeScript  — needs Node.js
                    "jsonls",        -- JSON        — needs Node.js
                    "cssls",         -- CSS         — needs Node.js
                    "html",          -- HTML        — needs Node.js
                    "eslint",        -- ESLint      — needs Node.js
                    "intelephense",  -- PHP         — needs Node.js
                    "svelte",        -- Svelte      — needs Node.js
                },
                automatic_enable = true,
            })

            -- Global defaults applied to every server
            vim.lsp.config("*", {
                capabilities = require("cmp_nvim_lsp").default_capabilities(),
            })

            -- Per-server overrides
            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = { diagnostics = { globals = { "vim" } } },
                },
            })

            -- LSP keymaps set once per buffer on attach
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local opts = { buffer = args.buf, silent = true }
                    vim.keymap.set("n", "gd", vim.lsp.buf.definition,      opts)
                    vim.keymap.set("n", "gy", vim.lsp.buf.type_definition,  opts)
                    vim.keymap.set("n", "gi", vim.lsp.buf.implementation,   opts)
                    vim.keymap.set("n", "gr", vim.lsp.buf.references,       opts)
                    vim.keymap.set("n", "K",  vim.lsp.buf.hover,            opts)
                    vim.keymap.set({ "n", "x" }, "<leader>fw", vim.lsp.buf.format, opts)
                    vim.keymap.set("n", "<leader>fa", vim.lsp.buf.format,   opts)
                end,
            })
        end,
    },

    -- ── Completion engine (replaces CoC completion + coc-snippets) ─────────
    {
        "hrsh7th/nvim-cmp",
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "saadparwaiz1/cmp_luasnip",
            {
                "L3MON4D3/LuaSnip",
                dependencies = { "rafamadriz/friendly-snippets" },
                config = function()
                    require("luasnip.loaders.from_vscode").lazy_load()
                end,
            },
        },
        config = function()
            local cmp     = require("cmp")
            local luasnip = require("luasnip")

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<CR>"]      = cmp.mapping.confirm({ select = true }),
                    ["<C-f>"]     = cmp.mapping.scroll_docs(4),
                    ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                sources = cmp.config.sources({
                    { name = "copilot" },
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                    { name = "buffer" },
                    { name = "path" },
                }),
            })
        end,
    },

    -- ── Formatting (replaces coc-prettier) ────────────────────────────────
    {
        "stevearc/conform.nvim",
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    javascript = { "prettier" },
                    typescript = { "prettier" },
                    html       = { "prettier" },
                    css        = { "prettier" },
                    json       = { "prettier" },
                    svelte     = { "prettier" },
                    php        = { "prettier" },
                    python     = { "black" },
                    rust       = { "rustfmt" },
                    sql        = { "sqlfluff" },
                },
                format_on_save = false,
            })
        end,
    },

    -- ── Linting (replaces coc-eslint) ─────────────────────────────────────
    {
        "mfussenegger/nvim-lint",
        config = function()
            require("lint").linters_by_ft = {
                javascript = { "eslint" },
                typescript = { "eslint" },
                svelte     = { "eslint" },
                python     = { "pylint" },
            }
            vim.api.nvim_create_autocmd("BufWritePost", {
                callback = function()
                    require("lint").try_lint()
                end,
            })
        end,
    },

}, {
    ui  = { border = "rounded" },
    git = { timeout = 180 },
})
