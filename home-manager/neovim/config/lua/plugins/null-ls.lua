return {
	{
		"mhartington/formatter.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		config = function()
			require("formatter").setup({
				filetype = {
					lua = {
						require("formatter.filetypes.lua").stylua,
					},
					cpp = {
						require("formatter.filetypes.cpp").ccls,
					},
					rust = {
						require("formatter.filetypes.rust").rustfmt,
					},

					["*"] = {
						require("formatter.filetypes.any").remove_trailing_whitespace,
					},
				},
			})
		end,
	},
	{
		"mfussenegger/nvim-lint",
		config = function()
			require("lint").linters_by_ft = {
				lua = { "luacheck" },
				rust = { "cargo" },
			}
		end,
	},
}
