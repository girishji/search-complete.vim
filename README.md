# search-complete.vim


Async search mode (`/` or `?`) completion with popup menu for Vim.

The only search mode completion you will ever need.

1. Does not interfere with `c|d|y` commands followed by `/pattern` workflow.
1. Async search does not get bogged down when searching large files.
1. Respects forward (`/`) and reverse (`?`) search when displaying menu items.
1. Does not interfere with history recall (using arrows).
1. Switch between vertical popup menu and (unobtrusive) horizontal menu (overlayed on statusline).
1. Can search across space and newline characters (multi-line search).
1. Does not interfere with search-highlighting and incremental-search.
1. Fully customizable colors and popup menu options.
1. Only `<tab>` and `<s-tab>` are mapped (to choose menu options) in cmdline-mode.
1. Written entirely in Vim9script for speed.



