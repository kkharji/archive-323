local config = require("lspsaga").config_values
local window = require "lspsaga.window"
local libs = require "lspsaga.libs"

local api = require "lspsaga.api"
local M = { title = config.code_action_icon .. "CodeActions:" }

M.apply_keys = function()
  libs.apply_keys("codeaction.window", {
    ["close"] = config.code_action_keys.quit,
    ["execute"] = config.code_action_keys.exec,
    ["execute_one"] = '1',
    ["execute_two"] = '2',
    ["execute_three"] = '3',
    ["execute_four"] = '4',
    ["execute_five"] = '5',
    ["execute_six"] = '6',
    ["execute_seven"] = '7',
    ["execute_eight"] = '8',
    ["execute_nine"] = '9',
  })
end

M.open = function(opts)
  local cmd, hl = vim.api.nvim_command, vim.api.nvim_buf_add_highlight
  M.action_bufnr, M.action_winid = window.create_win_with_border(opts)

  cmd 'autocmd CursorMoved <buffer> lua require("lspsaga.codeaction.window").set_cursor()'
  cmd "autocmd QuitPre <buffer> lua require('lspsaga.codeaction.window').close()"
  hl(M.action_bufnr, -1, "LspSagaCodeActionTitle", 0, 0, -1)
  hl(M.action_bufnr, -1, "LspSagaCodeActionTruncateLine", 1, 0, -1)

  for i = 1, #M.content - 2, 1 do
    hl(M.action_bufnr, -1, "LspSagaCodeActionContent", 1 + i, 0, -1)
  end
  M.apply_keys()
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
    M.actions, M.bufnr, M.action_bufnr, M.action_winid, M.ctx = {}, 0, 0, 0, nil
  end
end

M.execute = function(choice_num)
  local choice = M.actions[choice_num or tonumber(vim.fn.expand "<cword>")]
  if choice then
    M.close()
    local client_id, action = choice[1], choice[2]
    api.code_action_execute(client_id, action, M.ctx)
    return
  end
  M.close()
end

M.execute_one = function() M.execute(1) end
M.execute_two = function() M.execute(2) end
M.execute_three = function() M.execute(3) end
M.execute_four = function() M.execute(4) end
M.execute_five = function() M.execute(5) end
M.execute_six = function() M.execute(6) end
M.execute_seven = function() M.execute(7) end
M.execute_eight = function() M.execute(8) end
M.execute_nine = function() M.execute(9) end

return M
