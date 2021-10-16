local M = {}

M.is_command = function(action)
  return type(action.command) == "table"
end

M.code_action_request = function(cb, winid)
  winid = winid or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = vim.api.nvim_win_get_cursor(winid)[1] - 1 })
  local method = "textDocument/codeAction"
  local params = vim.lsp.util.make_range_params()
  local ctx = { bufnr = bufnr, method = method, params = params }
  params.context = { diagnostics = diagnostics }
  vim.lsp.buf_request_all(bufnr, method, params, cb(ctx))
end

local execute = function(client, action, ctx)
  if type(action.edit) == "table" then
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

local resolve = function(client, action, ctx)
  if
    client
    and type(client.resolved_capabilities.code_action) == "table"
    and client.resolved_capabilities.code_action.resolveProvider
  then
    client.request(0, "codeAction/resolve", action, function(err, resolved_action)
      if err then
        vim.notify(err.code .. ": " .. err.message, vim.log.levels.ERROR)
        return
      end
      execute(client, resolved_action, ctx)
    end)
  end
end

M.code_action_execute = function(client_id, action, ctx)
  local client = vim.lsp.get_client_by_id(client_id)
  if not execute(client, action, ctx) then
    print "not found"
    resolve(client_id, action, ctx)
  end
end

return M
