return {
	fmt = vim.api.nvim_create_augroup("FormatAutogroup", {}),
	lint = vim.api.nvim_create_augroup("LintAutogroup", {}),
}
