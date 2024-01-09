return {
	-- Move stuff with <M-j> and <M-k> in both normal and visual mode
	{
		"echasnovski/mini.move",
		config = function()
			require("mini.move").setup({
				mappings = {
					left = "<A-Left>",
					right = "<A-Right>",
					down = "<A-Down>",
					up = "<A-Up>",

					line_left = "<A-Left>",
					line_right = "<A-Right>",
					line_down = "<A-Down>",
					line_up = "<A-Up>",
				},
			})
		end,
	},
}
