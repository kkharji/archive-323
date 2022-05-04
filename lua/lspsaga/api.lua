local M = {}

M.methods = {
  code_action = "textDocument/codeAction",
}

M.code_action_request = function(args)
  local bufnr = vim.api.nvim_get_current_buf()
  args.params.context = args.context or { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
  local callback = args.callback { bufnr = bufnr, method = M.methods.code_action, params = args.params }
  vim.lsp.buf_request_all(bufnr, M.methods.code_action, args.params, callback)
end

local execute = function(client, action, ctx)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
  end

  if action.command then
    local command = type(action.command) == "table" and action.command or action
    local fn = vim.lsp.commands[command.command]
    if fn then
      local enriched_ctx = vim.deepcopy(ctx)
      enriched_ctx.client_id = client.id
      fn(command, ctx)
    else
      vim.lsp.buf.execute_command(command)
    end
  end
end

M.code_action_execute = function(client_id, action, ctx)
  local client = vim.lsp.get_client_by_id(client_id)

  local code_action_provide = nil
  if vim.fn.has("nvim-0.8.0") then
    code_action_provide = client.server_capabilities.codeActionProvider
  else
    code_action_provide = client.resolved_capabilities.code_action
  end

  if
    not action.edit
    and client
    and type(code_action_provide) == "table"
    and code_action_provide.resolveProvider
  then
    client.request("codeAction/resolve", action, function(err, resolved_action)
      if err then
        vim.notify(err.code .. ": " .. err.message, vim.log.levels.ERROR)
        return
      end
      execute(client, resolved_action, ctx)
    end)
  else
    execute(client, action, ctx)
  end
end

return M
