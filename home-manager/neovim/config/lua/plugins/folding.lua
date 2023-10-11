return {
	-- Better folds
	{
		"kevinhwang91/nvim-ufo",
		dependencies = "kevinhwang91/promise-async",
		config = function()
			require("ufo").setup({
				open_fold_hl_timeout = 0,
				close_fold_kinds = { "imports", "comment" },
			})
		end,
	},
}
