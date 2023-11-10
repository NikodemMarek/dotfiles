local augroup = require("helpers.autogroups").fmt

-- This function gets run when an LSP connects to a particular buffer.
local on_attach = function(client, bufnr)
    local lsp_map = require("helpers.keys").lsp_map

    lsp_map("<leader>lr", vim.lsp.buf.rename, bufnr, "Rename symbol")
    lsp_map("<leader>la", vim.lsp.buf.code_action, bufnr, "Code action")
    lsp_map("<leader>ld", vim.lsp.buf.type_definition, bufnr, "Type definition")
    lsp_map("<leader>ls", require("telescope.builtin").lsp_document_symbols, bufnr, "Document symbols")

    lsp_map("gd", vim.lsp.buf.definition, bufnr, "Goto Definition")
    lsp_map("gr", require("telescope.builtin").lsp_references, bufnr, "Goto References")
    lsp_map("gI", vim.lsp.buf.implementation, bufnr, "Goto Implementation")
    lsp_map("K", vim.lsp.buf.hover, bufnr, "Hover Documentation")
    lsp_map("gD", vim.lsp.buf.declaration, bufnr, "Goto Declaration")

    -- Create a command `:Format` local to the LSP buffer
    vim.api.nvim_buf_create_user_command(bufnr, "Format", function(_)
        vim.lsp.buf.format()
    end, { desc = "Format current buffer with LSP" })
    lsp_map("<leader>ff", "<cmd>Format<cr>", bufnr, "Format")

    -- Format on save
    if client.supports_method("textDocument/formatting") then
        vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
        vim.api.nvim_create_autocmd("BufWritePre", {
            group = augroup,
            buffer = bufnr,
            callback = function()
                vim.lsp.buf.format({ async = false })
            end,
        })
    end

    -- Attach and configure vim-illuminate
    require("illuminate").on_attach(client)
end

-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
capabilities.textDocument.foldingRange = {
    dynamicRegistration = false,
    lineFoldingOnly = true,
}

return {
    on_attach = on_attach,
    capabilities = capabilities,
}
