-- lsp diagnostic
local window = require "lspsaga.window"
local libs = require "lspsaga.libs"
local wrap = require "lspsaga.wrap"
local config = require("lspsaga").config_values
local if_nil = vim.F.if_nil
local hover = require "lspsaga.hover"
local fmt = string.format
local M = {}

M.highlights = {
  [vim.diagnostic.severity.ERROR] = "DiagnosticFloatingError",
  [vim.diagnostic.severity.WARN] = "DiagnosticFloatingWarn",
  [vim.diagnostic.severity.INFO] = "DiagnosticFloatingInfo",
  [vim.diagnostic.severity.HINT] = "DiagnosticFloatingHint",
}

local get_line_diagnostics = function(lnum, bufnr)
  return function()
    local buf = bufnr or vim.api.nvim_get_current_buf()
    local line_num = lnum or (vim.api.nvim_win_get_cursor(0)[1] - 1)

    return vim.diagnostic.get(buf, { lnum = line_num  })
  end
end

local format_message = function(diagnostic)
    local message = string.gsub(config.diagnostic_message_format, '%%m', diagnostic.message)

    if diagnostic.user_data and diagnostic.user_data.lsp and diagnostic.user_data.lsp.code then
        message = string.gsub(message, '%%c', '[' .. diagnostic.user_data.lsp.code .. ']')
    else
        message = string.gsub(message, '%%c', '')
    end

    return vim.fn.trim(message)
end

M.yank_line_messages = function(opts, lnum, bufnr)
  local diagnostics = get_line_diagnostics(lnum, bufnr)()
  local messages = {}
  for _, diagnostic in ipairs(diagnostics) do
    table.insert(messages, format_message(diagnostic))
  end
  if #messages == 0 then
    print('No diagnostics found')
    return
  end
  local reg = opts or '+' -- yank to + by default
  local message = messages[1]
  for i = 2, #messages do
    message = message .. '\n' .. messages[i]
  end
  print('Copied to registry ' .. reg)
  vim.fn.setreg(reg, message)
end

---TODO(refactor): move to popup.lua
local show_diagnostics = function(opts, get_diagnostics)
  local close_hover = opts.close_hover or false
  -- if we have a hover rendered, don't show diagnostics due to this usually
  -- being bound to CursorHold which triggers after hover show
  if not close_hover and hover.has_saga_hover() then
    return
  end

  local active, _ = libs.check_lsp_active()
  if not active then
    return
  end
  local max_width = window.get_max_float_width() - 2

  -- if there already has diagnostic float window did not show show lines diagnostic window
  local has_var, diag_float_winid = pcall(vim.api.nvim_buf_get_var, 0, "diagnostic_float_window")
  if has_var and diag_float_winid ~= nil then
    if vim.api.nvim_win_is_valid(diag_float_winid[1]) and vim.api.nvim_win_is_valid(diag_float_winid[2]) then
      return
    end
  end

  local severity_sort = if_nil(opts.severity_sort, true)
  local show_header = if_nil(opts.show_header, true)

  local lines = {}
  local highlights = {}

  if show_header then
    lines[1] = config.diagnostic_header_icon .. "Diagnostics:"
    highlights[1] = { 0, "LspSagaDiagnosticHeader" }
  end

  local diagnostics = get_diagnostics()

  if vim.tbl_isempty(diagnostics) then
    return
  elseif severity_sort then
    table.sort(diagnostics, function(a, b)
      return a["severity"] < b["severity"]
    end)
  end

  local signs = {
    config.error_sign,
    config.warn_sign,
    config.infor_sign,
    config.hint_sign
  }

  for i, diagnostic in ipairs(diagnostics) do
    local hiname = M.highlights[diagnostic.severity]
    assert(hiname, "unknown severity: " .. tostring(diagnostic.severity))

    local prefix = string.gsub(config.diagnostic_prefix_format, '%%s', signs[diagnostic.severity])
    prefix = string.gsub(prefix, '%%d', i)

    local message = format_message(diagnostic)

    local message_lines = vim.split(message, "\n", true)
    message_lines[1] = prefix .. message_lines[1]
    for j = 2, #message_lines do
        message_lines[j] = string.rep(' ', #prefix) .. message_lines[j]
    end
    local wrap_message = wrap.wrap_contents(message_lines, max_width, { fill = true, pad_left = #prefix })

    for j = 1, #wrap_message do
      table.insert(lines, wrap_message[j])

      if not config.highlight_prefix then
        table.insert(highlights, { #prefix, hiname })
      else
        table.insert(highlights, { 0, hiname })
      end
    end
  end

  if show_header then
    local truncate_line = wrap.add_truncate_line(lines)
    table.insert(lines, 2, truncate_line)
    table.insert(highlights, 2, { 0, 'LspSagaDiagnosticTruncateLine' })
  end

  local content_opts = { contents = lines, filetype = "LspsagaDiagnostic", highlight = "LspSagaDiagnosticBorder" }
  local bufnr, winid = window.create_win_with_border(content_opts, opts)

  for i, hi in ipairs(highlights) do
    local prefix, hiname = unpack(hi)
    vim.api.nvim_buf_add_highlight(bufnr, -1, hiname, i - 1, prefix, -1)
  end

  libs.close_preview_autocmd({ "CursorMoved", "CursorMovedI", "BufHidden", "BufLeave" }, winid)
  vim.api.nvim_win_set_var(0, "show_line_diag_winids", winid)
  vim.api.nvim_win_set_option(winid, "wrap", false)

  return winid
end

M.show_cursor_diagnostics = function(opts, bufnr)
  return show_diagnostics(opts or {}, function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local lnum, cnum = cursor[1] - 1, cursor[2]

    return vim.tbl_filter(
      function(diagnostic)
        local start_line, start_char = diagnostic['lnum'], diagnostic["col"]
        local end_line, end_char = diagnostic["end_lnum"], diagnostic["end_col"]
        local one_line_diag = start_line == end_line

        if one_line_diag and start_line == lnum then
          if cnum >= start_char and cnum < end_char then
            return true
          end
          -- multi line diagnostic
        else
          if lnum == start_line and cnum >= start_char then
            return true
          elseif lnum == end_line and cnum < end_char then
            return true
          elseif lnum > start_line and lnum < end_line then
            return true
          end
        end

        return false
      end,
      vim.diagnostic.get(bufnr, {
        lnum = lnum,
      })
    )
  end)
end

M.show_line_diagnostics = function(opts, lnum, bufnr)
  return show_diagnostics(opts or {}, get_line_diagnostics(lnum, bufnr))
end

M.navigate = function(direction)
  return function(opts)
    opts = opts or {}
    local pos = vim.diagnostic[fmt("get_%s_pos", direction)](opts)
    if not pos then
      --- TODO: move to notify.lua, notify.diagnostics.no_more_diagnostics(direction:gsub("^%l", string.upper)))
      return print(fmt("Diagnostic%s: No more valid diagnostics to move to.", direction:gsub("^%l", string.upper)))
    end

    local win_id = opts.win_id or vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(win_id, { pos[1] + 1, pos[2] })

    vim.schedule(function()
      M.show_line_diagnostics(opts.popup_opts, nil, vim.api.nvim_win_get_buf(win_id))
    end)
  end
end

M.toggle_virtual_text = function()
  config.use_diagnostic_virtual_text = not config.use_diagnostic_virtual_text
  vim.diagnostic.config({virtual_text = config.use_diagnostic_virtual_text})
end

--- TODO: at some point just use builtin function to preview diagnostics
--- Missing borders and formating of title
-- vim.diagnostic.show_position_diagnostics {
--   focusable = false,
--   close_event = { "CursorMoved", "CursorMovedI", "BufHidden", "BufLeave" },
--   source = false,
--   show_header = true,
--   border = "rounded",
--   format = function(info)
--     local lines = {}
--     if config.diagnostic_show_source then
--       lines[#lines + 1] = info.source:gsub("%.", ":")
--     end
--     lines[#lines + 1] = info.message
--     if config.diagnostic_show_code then
--       lines[#lines + 1] = fmt("(%s)", info.user_data.lsp.code)
--     end
--     return table.concat(lines, " ")
--   end,
-- }

return M
