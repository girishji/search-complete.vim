# search-complete.vim

Async search mode completion with popup menu. Vim only, no Neovim for now.

- Search using `/` or `?`.
- `<Tab>` and `<Shift-tab>` will select menu items.
- `<Ctrl-e>` dismisses popup menu.
- `Enter` to accept selection, and `<Esc>` to dismiss search.
- `<Ctrl-c>` will force close popup menu.
- Type `Space` after the first word to include the second word in search.
- Type `\n` at the end of last word to continue to next line.

### Vertical Popup Menu

[![asciicast](https://asciinema.org/a/dGNdbLbsTMSdaL8E4PonxQDKL.svg)](https://asciinema.org/a/dGNdbLbsTMSdaL8E4PonxQDKL)


### Horizontal Popup Menu

This is the default choice since it does not cover up text in main window.

[![asciicast](https://asciinema.org/a/DrvlJnoumCA9jWuMH8WGBCVJz.svg)](https://asciinema.org/a/DrvlJnoumCA9jWuMH8WGBCVJz)

# Features

1. Does not interfere with `c|d|y /pattern` commands.
1. Search command does not get bogged down when searching large files.
1. Respects forward (`/`) and reverse (`?`) search when displaying menu items.
1. Does not interfere with search-history recall (arrow keys are not mapped).
1. Switch between vertical popup menu and (unobtrusive) horizontal menu (overlay on statusline).
1. Can search across space and newline characters (multi-line search).
1. Does not interfere with search-highlighting and incremental-search.
1. Fully customizable colors and popup menu options.
1. Only `<tab>` and `<s-tab>` are mapped (to choose menu options) in cmdline-mode.
1. Written entirely in Vim9script for speed.

# Requirements

- Vim >= 9.0

# Installation

Install using [vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'girishji/search-complete.vim'
```

Or use Vim's builtin package manager.

# Configuration

There are two types of options that can be configured: 1) options passed directly to Vim's
[popup_create()](https://vimhelp.org/popup.txt.html#popup_create-arguments)
function, and 2) options used internally by this plugin. Any option accepted by
popup_create() can be configured. This includes `borderchars`, `border`, `maxheight`, etc.

`g:SearchCompleteSetup()` function is used to set options. It takes a dictionary argument.
If you are using
[vim-plug](https://github.com/junegunn/vim-plug), use `autocmd` to set options
(after calling `Plug`):

```
augroup MySearchComplete | autocmd!
    autocmd WinEnter,BufEnter * g:SearchCompleteSetup({
                \   borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
                \   horizontalMenu: true,
                \ })
augroup END
```

Other options of interest:

```
var options: dict<any> = {
    maxheight: 12,              # Line count of vertical menu
    horizontalMenu: true,       # 'true' for horizontal menu, 'false' for vertical menu
    searchRange: 1000,          # Lines per search iteration
}
```

Disable and re-enable this plugin through commands:

- `:SearchCompleteDisable`
- `:SearchCompleteEnable`

Hide statusline when popup menu is shown:

```
autocmd CmdlineEnter /,\? set laststatus=0 noshowmode noruler
autocmd CmdlineLeave /,\? set laststatus=2 showmode ruler
```

### Highlight Groups

Customize the colors to your liking using highlight groups.

- `SearchCompleteMenu`: Menu items in popup menu, linked to `Pmenu`.
- `SearchCompleteSelect`: Selected item, linked to `PmenuSel`.
- `SearchCompletePrefix`: Fragment of menu item that matches text typed in command-line, linked to `Statement`.
- `SearchCompleteSbar`: Vertical menu scroll bar, linked to `PmenuSbar`.
- `SearchCompleteThumb`: Vertical menu scroll bar thumb, linked to `PmenuThumb`.


# Performance

Great care is taken to ensure that response does not deteriorate when searching
large files. Large files are searched in installments. Each search attempt is
limited to 1000 lines (configurable). Between each search attempt input
keystrokes are allowed to be queued into Vim's main loop.

# Contributing

Pull requests are welcome.

