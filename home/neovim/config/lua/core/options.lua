local opts = {
	shiftwidth = 4,
	tabstop = 4,
	expandtab = true,
	termguicolors = true,
	number = true,
	relativenumber = true,
	clipboard = "unnamedplus",
	wrap = true,
	foldcolumn = "1",
	fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]],
	foldlevel = 99,
	foldlevelstart = 99,
	foldenable = true,
	signcolumn = "number",
}
local gopts = {
	netrw_banner = 0,
}

-- Set options from table
for opt, val in pairs(opts) do
	vim.o[opt] = val
end
for opt, val in pairs(gopts) do
	vim.g[opt] = val
end

-- Set other options
local colorscheme = require("helpers.colorscheme")
vim.cmd.colorscheme(colorscheme)
