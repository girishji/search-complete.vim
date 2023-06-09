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
    if opts->has_key('popup')
	var popts = c.options.popup->extend(opts.popup)
	c.options->extend(opts)
	c.opts.popup = popts
    else
	c.options->extend(opts)
    endif
enddef

# SearchComplete
# SearchCompleteBorderHighlight
# SearchCompleteScrollbarHighlight
# SearchCompleteThumbHighlight
	# borderhighlight: 'SearchCompleteBorderHighlight',
	# scrollbarhighlight: 'SearchCompleteScrollbarHighlight',
	# thumbhighlight: 'SearchCompleteThumbHighlight',
# hi SearchComplete ctermbg=none

hi! link SearchCompletePrefix Statement
