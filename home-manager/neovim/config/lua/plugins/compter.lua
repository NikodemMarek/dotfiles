return {
	-- Incremet and decrement custom values
	{
		"RutaTang/compter.nvim",
		config = function()
			require("compter").setup({
				templates = {
					-- for numbers
					{
						pattern = [[-\?\d\+]],
						priority = 0,
						increase = function(content)
							content = tonumber(content)
							return content + 1, true
						end,
						decrease = function(content)
							content = tonumber(content)
							return content - 1, true
						end,
					},
					-- for boolean
					{
						pattern = [[\<\(true\|false\|TRUE\|FALSE\|True\|False\)\>]],
						priority = 100,
						increase = function(content)
							local switch = {
								["true"] = "false",
								["false"] = "true",
								["True"] = "False",
								["False"] = "True",
								["TRUE"] = "FALSE",
								["FALSE"] = "TRUE",
							}
							return switch[content], true
						end,
						decrease = function(content)
							local switch = {
								["true"] = "false",
								["false"] = "true",
								["True"] = "False",
								["False"] = "True",
								["TRUE"] = "FALSE",
								["FALSE"] = "TRUE",
							}
							return switch[content], true
						end,
					},
				},
				fallback = true,
			})
		end,
	},
}
