return {
	-- Better Netrw
	{
		"prichrd/netrw.nvim",
		lazy = false,
		config = function()
			vim.api.nvim_buf_set_keymap(0, "n", "o", "<Nop>", { noremap = true, silent = true })

			require("netrw").setup({
				use_devicons = true,
				mappings = {
					["o"] = function(payload)
						vim.ui.input({ prompt = "filename: " }, function(filename)
							if filename == nil then
								return
							end

							if filename == "" then
								vim.notify("filename cannot be empty", "error")
								return
							end

							local path = vim.fs.normalize(payload.dir .. "/" .. filename)

							if vim.fn.filereadable(path) == 1 then
								vim.cmd("edit " .. path)
								print("file exists")
								return
							end

							vim.fn.writefile({ "" }, path)

							vim.cmd("edit " .. path)
						end)
					end,
					["O"] = function(payload)
						vim.ui.input({ prompt = "dirname: " }, function(dirname)
							if dirname == nil then
								return
							end

							if dirname == "" then
								vim.notify("dirname cannot be empty", "error")
								return
							end

							local path = vim.fs.normalize(payload.dir .. "/" .. dirname .. "/")

							if vim.fn.isdirectory(path) == 1 then
								print("directory exists")
								vim.cmd("e")
								return
							end

							vim.fn.mkdir(path, "p")
							vim.cmd("e")
						end)
					end,
				},
			})
		end,
	},
}
