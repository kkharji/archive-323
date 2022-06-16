local api = vim.api
local npcall = vim.F.npcall
local libs = {}
local server_filetype_map = require("lspsaga").config_values.server_filetype_map

function libs.is_windows()
  return vim.loop.os_uname().sysname:find("Windows", 1, true) and true
end

local path_sep = libs.is_windows() and "\\" or "/"

function libs.get_home_dir()
  if libs.is_windows() then
    return os.getenv "USERPROFILE"
  end
  return os.getenv "HOME"
end

-- check index in table
function libs.has_key(tab, idx)
  for index, _ in pairs(tab) do
    if index == idx then
      return true
    end
  end
  return false
end

function libs.has_value(tbl, val)
  for _, v in pairs(tbl) do
    if v == val then
      return true
    end
  end
  return false
end

function libs.nvim_create_augroup(group_name, definitions)
  vim.api.nvim_command("augroup " .. group_name)
  vim.api.nvim_command "autocmd!"
  for _, def in ipairs(definitions) do
    local command = table.concat(vim.tbl_flatten { "autocmd", def }, " ")
    vim.api.nvim_command(command)
  end
  vim.api.nvim_command "augroup END"
end

function libs.nvim_create_keymap(definitions, lhs)
  for _, def in pairs(definitions) do
    local bufnr = def[1]
    local mode = def[2]
    local key = def[3]
    local rhs = def[4]
    api.nvim_buf_set_keymap(bufnr, mode, key, rhs, lhs)
  end
end

function libs.check_lsp_active()
  local active_clients = vim.lsp.get_active_clients()
  if next(active_clients) == nil then
    return false, "[lspsaga] No lsp client available"
  end
  return true, nil
end

function libs.result_isempty(res)
  if type(res) ~= "table" then
    print "[Lspsaga] Server return wrong response"
    return
  end
  for _, v in pairs(res) do
    if next(v) == nil then
      return true
    end
    if not v.result then
      return true
    end
    if next(v.result) == nil then
      return true
    end
  end
  return false
end

function libs.split_by_pathsep(text, start_pos)
  local pattern = libs.is_windows() and path_sep or "/" .. path_sep
  local short_text = ""
  local split_table = {}
  for word in text:gmatch("[^" .. pattern .. "]+") do
    table.insert(split_table, word)
  end

  for i = start_pos, #split_table, 1 do
    short_text = short_text .. split_table[i]
    if i ~= #split_table then
      short_text = short_text .. path_sep
    end
  end
  return short_text
end

function libs.get_lsp_root_dir()
  local active, msg = libs.check_lsp_active()
  if not active then
    print(msg)
    return
  end
  local clients = vim.lsp.get_active_clients()
  for _, client in pairs(clients) do
    if client.config.filetypes and client.config.root_dir then
      if type(client.config.filetypes) == "table" then
        if libs.has_value(client.config.filetypes, vim.bo.filetype) then
          return client.config.root_dir
        end
      elseif type(client.config.filetypes) == "string" then
        if client.config.filetypes == vim.bo.filetype then
          return client.config.root_dir
        end
      end
    else
      for name, fts in pairs(server_filetype_map) do
        for _, ft in pairs(fts) do
          if ft == vim.bo.filetype and client.config.name == name and client.config.root_dir then
            return client.config.root_dir
          end
        end
      end
    end
  end
  return ""
end

function libs.apply_keys(ns, actions)
  local map = function(func, keys)
    keys = type(keys) == "string" and { keys } or keys
    local fmt = "nnoremap <buffer><nowait><silent>%s <cmd>lua require('lspsaga.%s').%s()<CR>"

    vim.tbl_map(function(key)
      api.nvim_command(string.format(fmt, key, ns, func))
    end, keys)
  end
  if actions then
    for func, keys in pairs(actions) do
      map(func, keys)
    end
  else
    return map
  end
end

function libs.close_preview_autocmd(events, winid)
  local events_str = table.concat(events, ',')
  local cmd = string.format('autocmd %s <buffer> ++once lua pcall(vim.api.nvim_win_close, %d, true)', events_str, winid)
  vim.api.nvim_command(cmd)
end

local function find_window_by_var(name, value)
  for _, win in ipairs(api.nvim_list_wins()) do
    if npcall(api.nvim_win_get_var, win, name) == value then
      return win
    end
  end
end

function libs.focusable_float(unique_name, fn)
  -- Go back to previous window if we are in a focusable one
  if npcall(api.nvim_win_get_var, 0, unique_name) then
    return api.nvim_command "wincmd p"
  end
  local bufnr = api.nvim_get_current_buf()
  -- Currently, this function is reused by both hover and signaturehelp
  -- according to the vim.lsp.buf.signature_help(), we shouldn't jump
  -- to the preview window in this case. Since many users will automatically
  -- trigger signature_help with CursorHoldI event, check for #81 more info
  -- https://github.com/tami5/lspsaga.nvim/issues/81
  if string.find(string.lower(unique_name), "hover") ~= nil then -- in case the unique_name will change in the future
    local win = find_window_by_var(unique_name, bufnr)
    if win and api.nvim_win_is_valid(win) and vim.fn.pumvisible() == 0 then
      api.nvim_set_current_win(win)
      api.nvim_command "stopinsert"
      return
    end
  end
  local pbufnr, pwinnr, _, _ = fn()
  if pbufnr then
    api.nvim_win_set_var(pwinnr, unique_name, bufnr)
    return pbufnr, pwinnr
  end
end


return libs
