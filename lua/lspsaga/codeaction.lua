local libs = require "lspsaga.libs"
local window = require "lspsaga.codeaction.window"
local api = require "lspsaga.codeaction.api"
local M = {}

M.range_code_action = function(context, start_pos, end_pos)
  local active, msg = libs.check_lsp_active()
  if not active then
    print(msg)
    return
  end

  window.bufnr = vim.fn.bufnr()
  vim.validate { context = { context, "t", true } }
  context = context or { diagnostics = vim.diagnostic.get() }
  local params = vim.lsp.util.make_given_range_params(start_pos, end_pos)
  params.context = context
  vim.lsp.buf_request(0, "textDocument/codeAction", params, window.open)
end

M.code_action = function()
  local active, _ = libs.check_lsp_active()
  if not active then
    return
  end
  window.bufnr = vim.fn.bufnr()
  api.code_action_request(function(ctx)
    return window.prepare(ctx)
  end)
end

return M
