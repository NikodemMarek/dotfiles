return {
	-- Save and restore session automatically
	{
		"rmagatti/auto-session",
		config = function()
			require("auto-session").setup({
				auto_session_suppress_dirs = { "~/", "~/projects", "/" },
			})
		end,
	},
}
