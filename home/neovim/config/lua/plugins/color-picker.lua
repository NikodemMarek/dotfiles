return {
	-- Color picker
	{
		"uga-rosa/ccc.nvim",
		config = function()
			-- Enable true color
			vim.opt.termguicolors = true

			require("ccc").setup({
				highlighter = {
					auto_enable = true,
					lsp = true,
				},
			})
		end,
	},
}
