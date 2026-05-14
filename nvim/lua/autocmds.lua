-- Restore cursor to last known position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- Highlight all references of the symbol under the cursor (replaces CocActionAsync highlight)
vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        for _, client in ipairs(clients) do
            if client.supports_method("textDocument/documentHighlight") then
                vim.lsp.buf.document_highlight()
                return
            end
        end
    end,
})

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    callback = function()
        pcall(vim.lsp.buf.clear_references)
    end,
})
