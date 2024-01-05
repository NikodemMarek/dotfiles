-- LSP Configuration & Plugins
return {
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"folke/neodev.nvim",
			"RRethy/vim-illuminate",
			"hrsh7th/cmp-nvim-lsp",
		},
		opts = function()
			return require("configs.nvim-lspconfig")
		end,
		config = function(_, opts)
			-- Neodev setup before LSP config
			require("neodev").setup()

			-- Diagnostic
			local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
			end

			local config = {
				virtual_text = true,
				signs = {
					active = signs,
				},
				update_in_insert = true,
				underline = true,
				severity_sort = true,
				float = {
					focusable = true,
					style = "minimal",
					border = "rounded",
					source = "always",
					header = "",
					prefix = "",
				},
			}
			vim.diagnostic.config(config)

			local lspconf = require("lspconfig")

			local on_attach = opts.on_attach
			local capabilities = opts.capabilities

			-- Lua
			lspconf.lua_ls.setup({
				on_attach = on_attach,
				capabilities = capabilities,
				settings = {
					Lua = {
						completion = {
							callSnippet = "Replace",
						},
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							library = {
								[vim.fn.expand("$VIMRUNTIME/lua")] = true,
								[vim.fn.stdpath("config") .. "/lua"] = true,
							},
						},
					},
				},
			})

			-- Go
			lspconf["gopls"].setup({
				on_attach = on_attach,
				capabilities = capabilities,
			})

			-- C / C++
			lspconf["ccls"].setup({
				on_attach = on_attach,
				capabilities = capabilities,
				init_options = {
					clang = {
						excludeArgs = { "-frounding-math" },
					},
				}
			})

			-- Python
			lspconf["pylsp"].setup({
				on_attach = on_attach,
				capabilities = capabilities,
				settings = {
					pylsp = {
						plugins = {
							flake8 = {
								enabled = true,
								maxLineLength = 88, -- Black's line length
							},
							-- Disable plugins overlapping with flake8
							pycodestyle = {
								enabled = false,
							},
							mccabe = {
								enabled = false,
							},
							pyflakes = {
								enabled = false,
							},
							-- Use Black as the formatter
							autopep8 = {
								enabled = false,
							},
						},
					},
				},
			})

			-- Webdev wihth deno
			vim.g.markdown_fenced_languages = {
				"ts=typescript",
			}
			lspconf.denols.setup({
				on_attach = on_attach,
				capabilities = capabilities,
				settings = {
					deno = {
						enable = true,
						suggest = {
							imports = {
								hosts = {
									["https://crux.land"] = true,
									["https://deno.land"] = true,
									["https://x.nest.land"] = true,
								},
							},
						},
					},
				},
			})

			-- HTML
			lspconf["html"].setup({
				on_attach = on_attach,
				capabilities = capabilities,
				init_options = {
					configurationSection = { "html", "css", "javascript" },
					embeddedLanguages = {
						css = true,
						javascript = true
					},
					provideFormatter = true
				}
			})

			-- Svelte
			lspconf["svelte"].setup({
				on_attach = on_attach,
				capabilities = capabilities,
			})

			-- Java
			lspconf["jdtls"].setup({
				on_attach = on_attach,
				capabilities = capabilities,
				cmd = {
					"jdt-language-server",
					"-configuration", "~/.cache/jdtls/config",
					"-data", "~/.cache/jdtls/workspace"
				}
			})

			-- Typst
			lspconf["typst_lsp"].setup {
				on_attach = on_attach,
				capabilities = capabilities,
			}

			-- Nix
			lspconf["nixd"].setup {
				on_attach = on_attach,
				capabilities = capabilities,
			}
		end,
	},
	{
		"simrat39/rust-tools.nvim",
		dependencies = "neovim/nvim-lspconfig",
		ft = "rust",
		opts = function()
			return require("configs.nvim-lspconfig")
		end,
		config = function(_, opts)
			require('rust-tools').setup({
				server = {
					on_attach = opts.on_attach,
					capabilities = opts.capabilities,
					root_dir = require("lspconfig/util").root_pattern("Cargo.toml"),
					settings = {
						["rust-analyzer"] = {
							check = {
								-- command = "clippy"
							},
							cargo = {
								allFeatures = true,
							},
						},
					}
				}
			})
		end
	}
}
