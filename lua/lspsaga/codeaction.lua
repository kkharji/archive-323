local libs = require "lspsaga.libs"
local window = require "lspsaga.codeaction.window"
local api = require "lspsaga.api"
local M = {}

M.range_code_action = function(context, start_pos, end_pos)
  local active, msg = libs.check_lsp_active()
  if not active then
    print(msg)
    return
  end
  api.code_action_request {
    params = vim.lsp.util.make_given_range_params(start_pos, end_pos),
    context = context,
    callback = function(ctx)
      return window.prepare(ctx)
    end,
  }
end

M.code_action = function()
  local active, _ = libs.check_lsp_active()
  if not active then
    return
  end
  api.code_action_request {
    params = vim.lsp.util.make_range_params(),
    callback = function(ctx)
      return window.prepare(ctx)
    end,
  }
end

return M
