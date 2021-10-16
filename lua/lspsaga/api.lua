local M = {}

M.code_action_request = function(args)
  local winid, bufnr = args.winid or vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local method = "textDocument/codeAction"
  args.params.context = args.context
    or { diagnostics = vim.diagnostic.get(bufnr, { lnum = vim.api.nvim_win_get_cursor(winid)[1] - 1 }) }
  vim.lsp.buf_request_all(bufnr, method, args.params, args.cb { bufnr = bufnr, method = method, params = args.params })
end

local execute = function(client, action, ctx)
  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit)
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
  if
    not action.edit
    and client
    and type(client.resolved_capabilities.code_action) == "table"
    and client.resolved_capabilities.code_action.resolveProvider
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
