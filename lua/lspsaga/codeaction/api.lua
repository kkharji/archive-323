local M = {}

M.code_action_request = function(cb, winid)
  winid = winid or vim.api.nvim_get_current_win()
  local diagnostics = vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(winid)[1] - 1 })
  local params = vim.lsp.util.make_range_params()
  params.context = { diagnostics = diagnostics }
  vim.lsp.buf_request(0, "textDocument/codeAction", params, cb(params.range.start.line, diagnostics))
end

M.code_action_execute = function(action)
  I(action)
  if action.edit or type(action.command) == "table" then
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit)
    end
    if type(action.command) == "table" then
      vim.lsp.buf_request(M.bufnr, "workspace/executeCommand", action.command)
    end
  else
    vim.lsp.buf_request(M.bufnr, "workspace/executeCommand", action)
  end
end

return M
