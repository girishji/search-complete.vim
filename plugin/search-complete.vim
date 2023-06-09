" Search mode completion plugin for Vim >= v9.0

if !has('vim9script') ||  v:version < 900 || has('nvim')
  " Needs Vim version 9.0 and above
  finish
endif

vim9script

g:loaded_search_complete = true

import autoload '../autoload/complete.vim' as c
c.Setup()

def! g:SearchCompleteSetup(opts: dict<any>)
    c.options->extend(opts)
enddef

# SearchComplete
# SearchCompleteBorderHighlight
# SearchCompleteScrollbarHighlight
# SearchCompleteThumbHighlight

