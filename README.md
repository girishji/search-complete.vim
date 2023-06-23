# search-complete.vim

Async search mode completion with popup menu for Vim. Once you start using it
you'll not want to go back.

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

This is the default choice since it leaves the main window fully visible.

[![asciicast](https://asciinema.org/a/DrvlJnoumCA9jWuMH8WGBCVJz.svg)](https://asciinema.org/a/DrvlJnoumCA9jWuMH8WGBCVJz)

# Features

- Does not interfere with `c|d|y /pattern` commands.
- Search command does not get bogged down when searching large files.
- Respects forward (`/`) and reverse (`?`) search when displaying menu items.
- Does not interfere with search-history recall (arrow keys, <Ctrl-N/P> are not mapped).
- Switch between vertical popup menu and horizontal menu (overlay on statusline).
- Can search across space and newline characters (multi-line search).
- Does not interfere with search-highlighting and incremental-search.
- Fully customizable colors and popup menu options.
- Only `<tab>` and `<shift-tab>` are mapped in cmdline-mode.
- Written in Vim9script for speed.

# Requirements

- Vim >= 9.0

# Installation

Install using [vim-plug](https://github.com/junegunn/vim-plug)

```
vim9script

plug#begin()

Plug 'girishji/search-complete.vim'

plug#end()
```

Or use Vim's builtin package manager.

# Configuration

There are two types of options that can be configured: 1) options passed directly to Vim's
[popup_create()](https://vimhelp.org/popup.txt.html#popup_create-arguments)
function, and 2) options used internally by this plugin. Any option accepted by
popup_create() is allowed. This includes `borderchars`, `border`, `maxheight`, etc.

`g:SearchCompleteSetup()` function is used to set options. It takes a dictionary argument.
If you are using
[vim-plug](https://github.com/junegunn/vim-plug), use `autocmd` to set options
(after calling `Plug`):

```
augroup MySearchComplete | autocmd!
    autocmd WinEnter,BufEnter * g:SearchCompleteSetup({
                \   borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
                \   horizontalMenu: false,
                \ })
augroup END
```

Options of interest:

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


### Highlight Groups

Customize the colors to your liking using highlight groups.

- `SearchCompleteMenu`: Menu items in popup menu, linked to `Pmenu`.
- `SearchCompleteSelect`: Selected item, linked to `PmenuSel`.
- `SearchCompletePrefix`: Fragment of menu item that matches text being searched, linked to `Statement`.
- `SearchCompleteSbar`: Vertical menu scroll bar, linked to `PmenuSbar`.
- `SearchCompleteThumb`: Vertical menu scroll bar thumb, linked to `PmenuThumb`.


# Performance

Great care is taken to ensure that responsiveness does not deteriorate when searching
large files. Large files are searched in installments. Each search attempt is
limited to 1000 lines (configurable). Between each search attempt input
keystrokes are allowed to be queued into Vim's main loop.

# Contributing

Pull requests are welcome.

# Similar Plugins

- [cmp-cmdline](https://github.com/hrsh7th/cmp-cmdline)
- [wilder.nvim](https://github.com/gelguy/wilder.nvim)
- [sherlock](https://github.com/vim-scripts/sherlock.vim)
