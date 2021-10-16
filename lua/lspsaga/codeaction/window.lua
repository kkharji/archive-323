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

M.__index = M

local actions_from_other_servers = function(response)
  local actions = {}
  for _, action in pairs(response) do
    M.actions[#M.actions + 1] = action
    local action_title = "[" .. #M.actions .. "]" .. " " .. action.title
    actions[#actions + 1] = action_title
  end
  return actions
end

M.no_actions = function(actions)
  if actions == nil or next(actions) == nil then
    print "No code actions available."
    return true
  end
end

M.setup_actions = function(response)
  if M.actions and next(M.actions) ~= nil then
    local other_actions = actions_from_other_servers(response)
    if next(other_actions) ~= nil then
      vim.tbl_extend("force", M.actions, other_actions)
    end
    vim.api.nvim_buf_set_option(M.action_bufnr, "modifiable", true)
    vim.fn.append(vim.fn.line "$", other_actions)
    vim.cmd("resize " .. #M.actions + 2)
    for i, _ in pairs(other_actions) do
      vim.fn.matchadd("LspSagaCodeActionContent", "\\%" .. #M.actions + 1 + i .. "l")
    end
  else
    M.actions = response
    for index, action in pairs(response) do
      local action_title = "[" .. index .. "]" .. " " .. action.title
      table.insert(M.content, action_title)
    end
  end
end

M.open = function(_, actions)
  if M.no_actions(actions) then
    return
  end
  M.content = {
    M.title,
  }
  M.setup_actions(actions)
  if #M.content == 1 then
    return
  end

  table.insert(M.content, 2, wrap.add_truncate_line(M.content))
  local content_opts = {
    contents = M.content,
    filetype = "LspSagaCodeAction",
    enter = true,
    highlight = "LspSagaCodeActionBorder",
  }

  M.action_bufnr, M.action_winid = window.create_win_with_border(content_opts)
  vim.api.nvim_command 'autocmd CursorMoved <buffer> lua require("lspsaga.codeaction.window").set_cursor()'
  vim.api.nvim_command "autocmd QuitPre <buffer> lua require('lspsaga.codeaction.window').close()"

  vim.api.nvim_buf_add_highlight(M.action_bufnr, -1, "LspSagaCodeActionTitle", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(M.action_bufnr, -1, "LspSagaCodeActionTruncateLine", 1, 0, -1)

  for i = 1, #M.content - 2, 1 do
    vim.api.nvim_buf_add_highlight(M.action_bufnr, -1, "LspSagaCodeActionContent", 1 + i, 0, -1)
  end

  for func, keys in pairs {
    ["close"] = config.code_action_keys.quit,
    ["execute"] = config.code_action_keys.exec,
  } do
    apply_keys(func, keys)
  end
end

M.close = function()
  if M.action_bufnr ~= 0 and M.action_winid ~= 0 then
    window.nvim_close_valid_window(M.action_winid)
    M.actions = {}
    M.bufnr, M.action_bufnr, M.action_winid = 0, 0, 0
  end
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

M.execute = function()
  local number = tonumber(vim.fn.expand "<cword>")
  local action = M.actions[number]
  api.code_action_execute(action)
  M.close()
end

return M
