# lspsaga.nvim

A maintained fork of glepnir/lspsaga.nvim.

Lspsaga is light-weight lsp plugin based on neovim built-in lsp with highly a performant UI. [SEE IN ACTION](https://github.com/tami5/lspsaga.nvim/wiki)

## Features

TODO .......

## Install

### Packer

```lua
use { 'tami5/lspsaga.nvim' }  -- nightly
use { 'tami5/lspsaga.nvim', branch = 'nvim6.0' or 'nvim51' } -- for specific version
```

## Requirements

- neovim/nvim-lspconfig

## Setup

Lspsaga support use command `Lspsaga` with completion or use lua function.

```lua
local lspsaga = require 'lspsaga'
lspsaga.setup { -- defaults ...
  debug = false,
  use_saga_diagnostic_sign = true,
  -- diagnostic sign
  error_sign = "",
  warn_sign = "",
  hint_sign = "",
  infor_sign = "",
  diagnostic_header_icon = "   ",
  -- code action title icon
  code_action_icon = " ",
  code_action_prompt = {
    enable = true,
    sign = true,
    sign_priority = 40,
    virtual_text = true,
  },
  finder_definition_icon = "  ",
  finder_reference_icon = "  ",
  max_preview_lines = 10,
  finder_action_keys = {
    open = "o",
    vsplit = "s",
    split = "i",
    quit = "q",
    scroll_down = "<C-f>",
    scroll_up = "<C-b>",
  },
  code_action_keys = {
    quit = "q",
    exec = "<CR>",
  },
  rename_action_keys = {
    quit = "<C-c>",
    exec = "<CR>",
  },
  definition_preview_icon = "  ",
  border_style = "single",
  rename_prompt_prefix = "➤",
  rename_output_qflist = {
    enable = false,
    auto_open_qflist = false,
  },
  server_filetype_map = {},
  diagnostic_prefix_format = "%d. ",
  diagnostic_message_format = "%m %c",
  highlight_prefix = false,
}
```
## Example Keymapings

```lua
--- In lsp attach function
local map = vim.api.nvim_buf_set_keymap
map(0, "n", "gr", "<cmd>Lspsaga rename<cr>", {silent = true, noremap = true})
map(0, "n", "gx", "<cmd>Lspsaga code_action<cr>", {silent = true, noremap = true})
map(0, "x", "gx", ":<c-u>Lspsaga range_code_action<cr>", {silent = true, noremap = true})
map(0, "n", "K",  "<cmd>Lspsaga hover_doc<cr>", {silent = true, noremap = true})
map(0, "n", "go", "<cmd>Lspsaga show_line_diagnostics<cr>", {silent = true, noremap = true})
map(0, "n", "gj", "<cmd>Lspsaga diagnostic_jump_next<cr>", {silent = true, noremap = true})
map(0, "n", "gk", "<cmd>Lspsaga diagnostic_jump_prev<cr>", {silent = true, noremap = true})
map(0, "n", "<C-u>", "<cmd>lua require('lspsaga.action').smart_scroll_with_saga(-1, '<c-u>')<cr>", {})
map(0, "n", "<C-d>", "<cmd>lua require('lspsaga.action').smart_scroll_with_saga(1, '<c-d>')<cr>", {})
```

## Customize Appearance

### Colors

Colors can be simply changed by overwriting the default highlights groups LspSaga is using.

```vim
highlight link LspSagaFinderSelection Search
" or
highlight link LspSagaFinderSelection guifg='#ff0000' guibg='#00ff00' gui='bold'
```

The available highlight groups are:

| Group Name               | Description                                                      |
| :----------------------- | :----------------------------------------------------------------|
| `LspSagaFinderSelection` | Currently active entry in the finder window that gets previewed. |
| `LspFloatWinNormal` | |
| `LspFloatWinBorder` | |
| `LspSagaBorderTitle` | |
| `TargetWord` | |
| `ReferencesCount` | |
| `DefinitionCount` | |
| `TargetFileName` | |
| `DefinitionIcon` | |
| `ReferencesIcon` | |
| `ProviderTruncateLine` | |
| `SagaShadow` | |
| `LspSagaFinderSelection` | |
| `DiagnosticTruncateLine` | |
| `DiagnosticError` | |
| `DiagnosticWarning` | |
| `DiagnosticInformation` | |
| `DiagnosticHint` | |
| `DefinitionPreviewTitle` | |
| `LspSagaShTruncateLine` | |
| `LspSagaDocTruncateLine` | |
| `LineDiagTuncateLine` | |
| `LspSagaCodeActionTitle` | |
| `LspSagaCodeActionTruncateLine` | |
| `LspSagaCodeActionContent` | |
| `LspSagaRenamePromptPrefix` | |
| `LspSagaRenameBorder` | |
| `LspSagaHoverBorder` | |
| `LspSagaSignatureHelpBorder` | |
| `LspSagaCodeActionBorder` | |
| `LspSagaAutoPreview` | |
| `LspSagaDefPreviewBorder` | |
| `LspLinesDiagBorder` | |

## Filetypes

Autocmds can be added for dedicated filetypes of LspSaga floating windows.
For example, one can use `<Esc>` to close the hover window when jumping into it by calling `:Lspsaga hover_doc` twice.
```vim
augroup lspsaga_filetypes
  autocmd!
  autocmd FileType LspsagaHover nnoremap <buffer><nowait><silent> <Esc> <cmd>close!<cr>
augroup END
```

The available filetypes are:
* `LspsagaCodeAction`
* `LspsagaDiagnostic`
* `LspsagaFinder`
* `LspsagaFloaterm`
* `LspsagaHover`
* `LspsagaRename`
* `LspsagaSignatureHelp`

# License

MIT
