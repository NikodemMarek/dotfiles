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
	-- Work with paired characters
	{
		"echasnovski/mini.pairs",
		config = function()
			require("mini.pairs").setup()
		end,
	},
	-- Split / join lines
	{
		"echasnovski/mini.splitjoin",
		config = function()
			require("mini.splitjoin").setup()
		end,
	},
	-- Surround text with characters
	{
		"echasnovski/mini.surround",
		config = function()
			require("mini.surround").setup()
		end,
	},
	-- Trail whitespace
	{
		"echasnovski/mini.trailspace",
		config = function()
			require("mini.trailspace").setup()
		end,
	},
}
