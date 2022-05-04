local M = { servers = {} }
local _config = require("lspsaga").config_values
local config = _config.code_action_prompt
local icon = _config.code_action_icon
local libs = require "lspsaga.libs"
local window = require "lspsaga.codeaction.window"
local api = require "lspsaga.api"

M.group = "sagalightbulb"
M.sign_name = "LspSagaLightBulb"

if vim.tbl_isempty(vim.fn.sign_getdefined(M.sign_name)) then
  vim.fn.sign_define(M.sign_name, { text = icon, texthl = "LspSagaLightBulbSign" })
end

M.require_diagnostics = {
  ["go"] = true,
  ["python"] = true,
}

M.special_buffers = {
  ["LspsagaCodeAction"] = true,
  ["LspsagaFinder"] = true,
  ["NvimTree"] = true,
  ["vist"] = true,
  ["lspinfo"] = true,
  ["markdown"] = true,
  ["text"] = true,
}

M.update = function(winid, line)
  if config.virtual_text then
    local namespace = vim.api.nvim_create_namespace "sagalightbulb"
    vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)

    if line then
      vim.api.nvim_buf_set_extmark(0, namespace, line, -1, {
        virt_text = { { "  " .. icon, M.sign_name } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end
  end

  if config.sign then
    if not window[winid] then
      return
    end

    if window[winid].lightbulb_line ~= 0 then
      vim.fn.sign_unplace(M.group, { id = window[winid].lightbulb_line, buffer = "%" })
    end

    if line and window[winid] then
      vim.fn.sign_place(line, M.group, M.sign_name, "%", {
        lnum = line + 1,
        priority = config.sign_priority,
      })
      window[winid].lightbulb_line = line
    end
  end
end

M.check = function()
  local active, _ = libs.check_lsp_active()
  local current_file = vim.api.nvim_buf_get_name(0)
  local is_file = vim.loop.fs_stat(current_file) ~= nil

  if not active or not is_file or M.special_buffers[vim.bo.filetype] then
    -- Lsp could become active after some time so we should not
    -- use `M.server[current_file] = false` here
    return
  end

  if M.servers[current_file] == nil then
    vim.lsp.for_each_buffer_client(vim.api.nvim_get_current_buf(), function(client)
        if M.servers[current_file] then return end
        local is_nightly = vim.fn.has("nvim-0.8.0")
        local code_action_provider = nil
        if is_nightly then
          code_action_provider = client.server_capabilities.codeActionProvider
        else
          code_action_provider = client.resolved_capabilities.code_action
        end
        if code_action_provider and client.supports_method "code_action"
        then
          M.servers[current_file] = true
        end
      end
    )

    if M.servers[current_file] == nil then
      M.servers[current_file] = false
    end
  end

  if M.servers[current_file] == false then
    return
  end

  local winid = vim.api.nvim_get_current_win()
  window[winid] = window[winid] or {}
  window[winid].lightbulb_line = window[winid].lightbulb_line or 0

  api.code_action_request {
    params = vim.lsp.util.make_range_params(),
    callback = function(ctx)
      local line = ctx.params.range.start.line
      local fail_to_have_diagnostics = M.require_diagnostics[vim.bo.filetype] and ctx.params.diagnostics and next(ctx.params.diagnostics) == nil
      local no_action = true

      return function(res)
        for _, result in pairs(res) do
          if result.result and next(result.result) ~= nil then
            no_action = false
            break
          end
        end

        if no_action or fail_to_have_diagnostics then
          return M.update(winid, nil)
        else
          return M.update(winid, line)
        end
      end
    end,
    winid = winid,
  }
end

M.attach = function()
  vim.cmd [[autocmd CursorHold,CursorHoldI * lua require'lspsaga.codeaction.indicator'.check()]]
end

return M
