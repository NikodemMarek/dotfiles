return {
	-- Dim inactive window
	{
		"sunjon/shade.nvim",
		config = function()
			require("shade").setup({
				overlay_opacity = 50,
				opacity_step = 1,
			})
		end,
	},
}
