return {
	-- Surround stuff with the ys-, cs-, ds- commands
	"tpope/vim-surround",
	{
		"AckslD/nvim-neoclip.lua",
		dependencies = {
			-- you'll need at least one of these
			"nvim-telescope/telescope.nvim",
			-- {'ibhagwan/fzf-lua'},
		},
		config = function()
			require("neoclip").setup({
				preview = true,
				content_spec_column = false,
				default_register = '"',
			})
			require("telescope").load_extension("neoclip")
		end,
	},
}
