local map = require("helpers.keys").map

-- Quick access to some common actions
map("n", "<leader>fw", "<cmd>w<cr>", "Write")
map({ "n", "i" }, "<C-s>", "<cmd>w<cr>", "Write")
map("n", "<leader>fa", "<cmd>wa<cr>", "Write all")

map("n", "<leader>qq", "<cmd>q<cr>", "Quit")
map("n", "<leader>qa", "<cmd>qa!<cr>", "Quit all")
map("n", "<leader>qd", "<cmd>SessionDelete<cr><cmd>qa!<cr>", "Quit all and kill session")

-- Quick command
map("n", ";", ":", "Quick command")

-- Diagnostic keymaps
map("n", "gx", vim.diagnostic.open_float, "Show diagnostics under cursor")

-- Better window navigation
map("n", "<C-h>", "<C-w><C-h>", "Navigate windows to the left")
map("n", "<C-j>", "<C-w><C-j>", "Navigate windows down")
map("n", "<C-k>", "<C-w><C-k>", "Navigate windows up")
map("n", "<C-l>", "<C-w><C-l>", "Navigate windows to the right")

-- Move with shift-arrows
map("n", "<S-Left>", "<C-w><S-h>", "Move window to the left")
map("n", "<S-Down>", "<C-w><S-j>", "Move window down")
map("n", "<S-Up>", "<C-w><S-k>", "Move window up")
map("n", "<S-Right>", "<C-w><S-l>", "Move window to the right")

-- Resize with arrows
map("n", "<C-Up>", ":resize +2<CR>")
map("n", "<C-Down>", ":resize -2<CR>")
map("n", "<C-Left>", ":vertical resize +2<CR>")
map("n", "<C-Right>", ":vertical resize -2<CR>")

-- Deleting buffers
local buffers = require("helpers.buffers")
map("n", "<leader>dd", buffers.delete_this, "Current buffer")
map("n", "<leader>do", buffers.delete_others, "Other buffers")
map("n", "<leader>da", buffers.delete_all, "All buffers")
map("n", "<leader>dw", "<cmd>close<cr>", "Window")

-- Navigate buffers
map("n", "<S-l>", ":bnext<CR>")
map("n", "<S-h>", ":bprevious<CR>")

-- Stay in indent mode
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Clear after search
map("n", "<leader>ur", "<cmd>nohl<cr>", "Clear highlights")

-- Register history
map("n", "<leader>pp", ":Telescope neoclip<cr>", "Paste from register")

-- Open file explorer
map({ "n", "v" }, "<leader>e", "<cmd>Oil<cr>", "Open file explorer")

-- Open fold preview
map("n", "zp", function()
	local winid = require("ufo").peekFoldedLinesUnderCursor()
	if not winid then
		vim.fn.CocActionAsync("definitionHover")
		vim.lsp.buf.hover()
	end
end, "Peek definition")
