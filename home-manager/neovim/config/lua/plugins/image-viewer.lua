return {
	-- ASCII image viewer
	{
		"samodostal/image.nvim",
		dependencies = { "nvim-lua/plenary.nvim", "m00qek/baleia.nvim" },
		config = function()
			require("image").setup({
				render = {
					foreground_color = true,
					background_color = true,
				},
				events = {
					update_on_nvim_resize = true,
				},
			})
		end,
	},
}
