-- Miscelaneous fun stuff
return {
	"tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically
	-- Keep cursor centered
	{
		"arnamak/stay-centered.nvim",
		config = true,
	},
	-- Picker windows
	"stevearc/dressing.nvim",
	-- Icons picker
	{
		"ziontee113/icon-picker.nvim",
		config = function()
			require("icon-picker").setup({
				disable_legacy_commands = true,
			})
		end,
	},
	-- Usage tracker
	{
		"gaborvecsei/usage-tracker.nvim",
		config = true,
	},
	-- Smooth scrolling
	{
		"karb94/neoscroll.nvim",
		config = function()
			require("neoscroll").setup({
				mappings = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb" },
				hide_cursor = false,
			})
		end,
	},
	-- Scrollbar with diagnostics
	{
		"petertriho/nvim-scrollbar",
		config = true,
	},
}
