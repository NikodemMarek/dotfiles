return {
	"LeonHeidelbach/trailblazer.nvim",
	config = function()
		require("trailblazer").setup({
			mappings = {
				nv = {
					motions = {
						peek_move_next_down = "<A-j>",
						peek_move_previous_up = "<A-k>",
					},
				},
			},
		})
	end,
}
