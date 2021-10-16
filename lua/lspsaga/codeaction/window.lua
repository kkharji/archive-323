local config = require("lspsaga").config_values
local wrap = require "lspsaga.wrap"
local window = require "lspsaga.window"
local libs = require "lspsaga.libs"
local apply_keys = libs.apply_keys "codeaction.window"
local api = require "lspsaga.codeaction.api"

local M = {
  title = config.code_action_icon .. "CodeActions:",
  actions = {},
  bufnr = 0,
  action_bufnr = 0,
  action_winid = 0,
  content = {},
}

-- if M.actions and next(M.actions) ~= nil then
--   local other_actions = actions_from_other_servers(response)
--   if next(other_actions) ~= nil then
--     vim.tbl_extend("force", M.actions, other_actions)
--   end
--   vim.api.nvim_buf_set_option(M.action_bufnr, "modifiable", true)
--   vim.fn.append(vim.fn.line "$", other_actions)
--   vim.cmd("resize " .. #M.actions + 2)
--   for i, _ in pairs(other_actions) do
--     vim.fn.matchadd("LspSagaCodeActionContent", "\\%" .. #M.actions + 1 + i .. "l")
--   end
-- else
--   M.actions = response
--   for index, action in pairs(response) do
--     local action_title = "[" .. index .. "]" .. " " .. action.title
--     table.insert(M.content, action_title)
--   end
-- end

M.__index = M

M.create_window = function(opts)
  local cmd, hl = vim.api.nvim_command, vim.api.nvim_buf_add_highlight
  M.action_bufnr, M.action_winid = window.create_win_with_border(opts)

  cmd 'autocmd CursorMoved <buffer> lua require("lspsaga.codeaction.window").set_cursor()'
  cmd "autocmd QuitPre <buffer> lua require('lspsaga.codeaction.window').close()"
  hl(M.action_bufnr, -1, "LspSagaCodeActionTitle", 0, 0, -1)
  hl(M.action_bufnr, -1, "LspSagaCodeActionTruncateLine", 1, 0, -1)

  for i = 1, #M.content - 2, 1 do
    hl(M.action_bufnr, -1, "LspSagaCodeActionContent", 1 + i, 0, -1)
  end
end

M.setup_actions = function(response)
  for client_id, result in pairs(response or {}) do
    for index, action in pairs(result.result or {}) do
      table.insert(M.actions, { client_id, action })
      table.insert(M.content, "[" .. index .. "]" .. " " .. action.title)
    end
  end

  if #M.actions == 0 then
    vim.notify("No code actions available", vim.log.levels.INFO)
    return
  end
end

M.attach_mappings = function()
  for func, keys in pairs {
    ["close"] = config.code_action_keys.quit,
    ["execute"] = config.code_action_keys.exec,
  } do
    apply_keys(func, keys)
  end
end

M.prepare = function(_, ctx)
  M.current_ctx = ctx
  return M.open
end

M.open = function(_, response)
  M.content = {
    M.title,
  }
  M.setup_actions(response)
  if #M.content == 1 then
    return
  end

  table.insert(M.content, 2, wrap.add_truncate_line(M.content))

  M.create_window {
    contents = M.content,
    filetype = "LspSagaCodeAction",
    enter = true,
    highlight = "LspSagaCodeActionBorder",
  }

  M.attach_mappings()
end

M.set_cursor = function()
  local column = 2
  local current_line = vim.fn.line "."

  if current_line == 1 then
    vim.fn.cursor(3, column)
  elseif current_line == 2 then
    vim.fn.cursor(2 + #M.actions, column)
  elseif current_line == #M.actions + 3 then
    vim.fn.cursor(3, column)
  end
end

M.close = function()
  if M.action_bufnr ~= 0 and M.action_winid ~= 0 then
    window.nvim_close_valid_window(M.action_winid)
    M.actions = {}
    M.bufnr, M.action_bufnr, M.action_winid, M.current_ctx = 0, 0, 0, nil
  end
end

M.execute = function()
  local number = tonumber(vim.fn.expand "<cword>")
  local choice = M.actions[number]
  local client_id, action = choice[1], choice[2]
  api.code_action_execute(client_id, action, M.current_ctx)
  M.close()
end

return M
