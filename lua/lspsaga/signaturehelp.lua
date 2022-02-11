local util, api = vim.lsp.util, vim.api
local npcall = vim.F.npcall
local window = require "lspsaga.window"
local config = require("lspsaga").config_values
local wrap = require "lspsaga.wrap"
local libs = require "lspsaga.libs"
local action = require "lspsaga.action"

-- disable signature help when only efm-langserver
-- issue #103
local function check_server_support_signaturehelp()
  local active, msg = libs.check_lsp_active()
  if not active then
    print(msg)
    return
  end
  local clients = vim.lsp.buf_get_clients()
  for _, client in pairs(clients) do
    if client.resolved_capabilities.signature_help == true then
      return true
    end
  end
  return false
end

local function apply_syntax_to_region(ft, start, finish)
  if ft == "" then
    return
  end
  local name = ft .. "signature"
  local lang = "@" .. ft:upper()
  -- TODO(ashkan): better validation before this.
  if not pcall(vim.cmd, string.format("syntax include %s syntax/%s.vim", lang, ft)) then
    return
  end
  vim.cmd(string.format("syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s", name, start, finish + 1, lang))
end

local function focusable_preview(unique_name, fn)
  return libs.focusable_float(unique_name, function()
    local contents, _ = fn()
    local filetype = api.nvim_buf_get_option(0, "filetype")
    vim.validate { contents = { contents, "t" }, filetype = { filetype, "s", true } }
    local opts = {}
    -- Clean up input: trim empty lines from the end, pad
    contents = util._trim(contents, opts)
    -- Compute size of float needed to show (wrapped) lines
    opts.wrap_at = opts.wrap_at or (vim.wo["wrap"] and api.nvim_win_get_width(0))
    local width, _ = util._make_floating_popup_size(contents, opts)
    local first_line = contents[1]

    if width > #contents[1] then
      width = #contents[1]
    end

    local max_width = window.get_max_float_width()

    if width ~= max_width then
      width = max_width
    end
    contents = wrap.wrap_contents(contents, width)

    local WIN_HEIGHT = vim.fn.winheight(0)
    local max_height = math.ceil((WIN_HEIGHT - 4) * 0.5)
    if #contents + 4 > max_height then
      opts.height = max_height
    end

    local wrap_index = #wrap.wrap_text(first_line, width)
    if #contents ~= 1 then
      local truncate_line = wrap.add_truncate_line(contents)
      table.insert(contents, wrap_index + 1, truncate_line)
    end

    local content_opts = {
      contents = contents,
      filetype = "sagasignature",
      highlight = "LspSagaSignatureHelpBorder",
    }

    local bufnr, winid = window.create_win_with_border(content_opts, opts)
    api.nvim_buf_add_highlight(bufnr, -1, "LspSagaShTruncateLine", wrap_index, 0, -1)
    api.nvim_buf_set_var(0, "saga_signature_help_win", { winid, 1, #contents, max_height })
    local cwin = api.nvim_get_current_win()
    api.nvim_set_current_win(winid)
    apply_syntax_to_region(filetype, 1, wrap_index)
    api.nvim_set_current_win(cwin)
    libs.close_preview_autocmd({ "CursorMoved", "CursorMovedI", "BufHidden", "BufLeave" }, winid)
    return bufnr, winid
  end)
end

local has_saga_signature = function()
  local saga_signature_win = npcall(api.nvim_buf_get_var, 0, "saga_signature_help_win")
  if saga_signature_win and api.nvim_win_is_valid(saga_signature_win[1]) then
    return true
  end
  return false
end

local scroll_in_signature = function(direction)
  if not has_saga_signature() then
    return
  end
  local sdata = api.nvim_buf_get_var(0, "saga_signature_help_win")
  local swin, current_win_lnum, last_lnum, height = sdata[1], sdata[2], sdata[3], sdata[4]
  current_win_lnum = action.scroll_in_win(swin, direction, current_win_lnum, last_lnum, height)
  api.nvim_buf_set_var(0, "saga_signature_help_win", { swin, current_win_lnum, last_lnum, height })
end

local call_back = function(_, result, ctx, _)
  if not (result and result.signatures and result.signatures[1]) then
    --     print('No signature help available')
    return
  end
  local lines = util.convert_signature_help_to_markdown_lines(result)
  lines = util.trim_empty_lines(lines)
  if vim.tbl_isempty(lines) then
    print "No signature help available"
    return
  end
  focusable_preview(ctx.method, function()
    return lines, util.try_trim_markdown_code_blocks(lines)
  end)
end

local signature_help = function()
  -- check the server support the signature help
  if not check_server_support_signaturehelp() then
    return
  end
  local params = util.make_position_params()
  vim.lsp.buf_request(0, "textDocument/signatureHelp", params, call_back)
end

return {
  signature_help = signature_help,
  focusable_preview = focusable_preview,
  has_saga_signature = has_saga_signature,
  scroll_in_signature = scroll_in_signature,
}
