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
					nix = {
						require("formatter.filetypes.nix").nixpkgs_fmt,
					},
					json = {
						require("formatter.filetypes.json").denofmt,
					},

					["*"] = {
						require("formatter.filetypes.any").remove_trailing_whitespace,
					},
				},
			})
		end,
	},
}
