vim9script

export var options: dict<any> = {
    enable: true,
    maxheight: 12,				# line count of vertical menu
    highlight: 'SearchCompleteMenu',
    scrollbarhighlight: 'SearchCompleteSbar',
    thumbhighlight: 'SearchCompleteThumb',
    flatMenu: true,				# 'true' for flat menu, 'false' for vertical menu
    searchRange: 1000,				# line count per search attemp
    timeout: 100,				# millisec to search, when non-async is specified
    async: true,				# async search
}

def PopupOptions(): dict<any>
    if options.flatMenu && !options->has_key('border')
	options.border = [0, 0, 0, 0]
    endif
    if options.searchRange < 10
	options.searchRange = 10
    endif
    return options->copy()->filter((k, _) => k !~ 'enable\|flatMenu\|searchRange\|timeout\|async')
enddef

# Encapsulate the state and operations of search menu completion.
def NewPopup(isForwardSearch: bool): dict<any>
    var popup = {
	winid: -1,	    # id of popup window
	keywords: [],	    # keywords shown in popup menu
	candidates: [],	    # candidates for completion (could be phrases)
	index: 0,	    # index to keywords and candidates array
	prefix: '',	    # cached cmdline contents
	isForwardSearch: isForwardSearch,	# true for '/' and false for '?'
	searchStartTime: [],		# timestamp at which search started
	firstMatchPos: [],  # workaround for vim bug 12538
    }
    popup->extend({
	completeWord: function(CompleteWord, [popup]),
	selectItem: function(SelectItem, [popup]),
	updateMenu: function(UpdateMenu, [popup]),
	matchingStrings: function(MatchingStrings, [popup]),
	showPopupMenu: function(ShowPopupMenu, [popup]),
    })
    # Due to vim bug 12538 highlighting has to be provoked explicitly during
    # async search. The redraw command causes some flickering of highlighted
    # text. So do async search only when file is large.
    if options.async
	popup->extend({async: (line('$') < options.searchRange ? false : true)})
	options.timeout = 2000
    else
	popup->extend({async: false})
    endif
    return popup
enddef

var popupCompletor = {}

def Init()
    if options.enable
	popupCompletor = getcmdtype() == '/' ? NewPopup(true) : NewPopup(false)
    endif
    EnableCmdline()
enddef

def Teardown()
    if options.enable
	popupCompletor.winid->popup_close()
    endif
    popupCompletor = {}
enddef

def Complete()
    if options.enable
	popupCompletor.completeWord()
    endif
enddef

export def Setup()
    augroup SearchComplete | autocmd!
	autocmd CmdlineEnter /,\?   Init()
	autocmd CmdlineChanged /,\? Complete()
	autocmd CmdlineLeave /,\?   Teardown()
    augroup END
enddef

def EnableCmdline()
    autocmd! SearchComplete CmdlineChanged /,\? Complete()
enddef

def DisableCmdline()
    autocmd! SearchComplete CmdlineChanged /,\?
enddef

# Return a list containing range of lines to search in each worker iteration.
def SearchIntervals(fwd: bool, range: number): list<any>
    var intervals = []
    var firstsearch = true
    var stopline = 0
    #  Note: startl <- start line, startc <- start column, etc.
    while firstsearch || stopline != (fwd ? line('$') : 1)
	var startline = firstsearch ? line('.') : stopline
	stopline = fwd ? min([startline + range, line('$')]) : max([startline - range, 1])
	intervals->add({startl: startline + (firstsearch ? 0 : fwd ? -5 : 5), 
	    startc: firstsearch ? col('.') : 1, stopl: stopline})
	firstsearch = false
    endwhile
    firstsearch = true
    while firstsearch || stopline != line('.')
	var startline = firstsearch ? fwd ? 1 : line('$') : stopline
	stopline = fwd ? min([startline + range, line('.')]) : max([startline - range, line('.')])
	intervals->add({startl: startline + (firstsearch ? 0 : fwd ? -5 : 5), startc: 1, stopl: stopline})
	firstsearch = false
    endwhile
    return intervals
enddef


# Return a list of strings (can have spaces and newlines) that match the pattern
def MatchingStrings(popup: dict<any>, interval: dict<any>): list<any>
    var p = popup
    var flags = p.async ? (p.isForwardSearch ? '' : 'b') : (p.isForwardSearch ? 'w' : 'wb')
    if p.async && p.firstMatchPos == [] # find first match to highlight (vim bug 12538)
	var [lnum, cnum] = p.prefix->searchpos(flags, interval.stopl)
	if [lnum, cnum] != [0, 0]
	    p.firstMatchPos = [lnum, cnum, p.prefix->len()]
	endif
    endif
    var pattern = $'\k*{p.prefix}\k*' # XXX: test if \S is better
    var [lnum, cnum] = [0, 0]
    var [startl, startc] = [0, 0]
    if p.async
	[lnum, cnum] = pattern->searchpos(flags, interval.stopl)
    else
	[lnum, cnum] = pattern->searchpos(flags, 0, options.timeout)
	[startl, startc] = [lnum, cnum]
    endif

    var matches = []
    var found = {}
    for item in p.candidates
	found[item] = 1
    endfor
    var searchStartTime = p.searchStartTime
    var timeout = options.timeout
    while [lnum, cnum] != [0, 0]
	var [endl, endc] = pattern->searchpos('ceW') # end of matching string
	var lines = getline(lnum, endl)
	var mstr = '' # fragment that matches pattern (can be multiline)
	if lines->len() == 1
	    mstr = lines[0]->strpart(cnum - 1, endc - cnum + 1)
	else
	    var mlist = [lines[0]->strpart(cnum - 1)] + lines[1 : -2] + [lines[-1]->strpart(0, endc)]
	    mstr = mlist->join('\n')
	endif
	if mstr != p.prefix && !found->has_key(mstr)
	    found[mstr] = 1
	    matches->add(mstr)
	endif
	cursor(lnum, cnum) # restore cursor to beginning of pattern, otherwise '?' does not work
	[lnum, cnum] = p.async ? pattern->searchpos(flags, interval.stopl) :
	    pattern->searchpos(flags, 0, timeout)

	if !p.async && ([startl, startc] == [lnum, cnum] ||
		(searchStartTime->reltime()->reltimefloat() * 1000) > timeout)
	    break
	endif
    endwhile
    return matches
enddef

# Menu width for flat menu is obtained as needed since user can resize window.
def HMenuWidth(): number
    return winwidth(0) - 4
enddef

# Display popup menu.
def ShowPopupMenu(popup: dict<any>)
    var p = popup
    if options.flatMenu
	var hmenu = p.keywords->join(' ')
	if hmenu->len() > HMenuWidth()
	    var lastSpaceChar = match(hmenu[0 : HMenuWidth() - 4], '.*\zs\s')
	    hmenu = hmenu->slice(0, lastSpaceChar == -1 ? 0 : lastSpaceChar) .. ' ...'
	endif
	hmenu->setbufline(p.winid->winbufnr(), 1)
    else
	var lastword = p.prefix->matchstr('\s*\S\+$')
	p.winid->popup_move({col: p.prefix->strridx(lastword) + 2})
	p.winid->popup_settext(p.keywords)
    endif
    p.index = -1
    p.winid->popup_setoptions({cursorline: false})
    clearmatches(p.winid)
    matchadd('SearchCompletePrefix', $'\c{p.prefix}', 10, -1, {window: p.winid})
    p.winid->popup_show()
    if !&incsearch # redraw only when noincsearch, otherwise highlight flickers
       :redraw
    endif
    DisableCmdline()
enddef

# A worker task for async search.
def SearchWorker(popup: dict<any>, attr: dict<any>, timer: number)
    var p = popup
    var timediff = p.searchStartTime->reltime(attr.searchStartTime)->reltimefloat()
    var prefix = getcmdline()->strpart(0, getcmdpos() - 1)
    if prefix !=# p.prefix || timediff < 0 || attr.index >= attr.intervals->len()
	return
    endif

    var interval = attr.intervals[attr.index]
    var cursorpos = [line('.'), col('.')]
    cursor(interval.startl, interval.startc)
    var matches = p.matchingStrings(interval)
    cursor(cursorpos)

    # Add matched fragments to list of candidates and segregate
    var candidates = timediff > 0 ? matches : p.candidates + matches
    p.candidates = candidates->copy()->filter((_, v) => v =~# $'^{p.prefix}') +
	candidates->copy()->filter((_, v) => v !~# $'^{p.prefix}')
    p.keywords = p.candidates->copy()->map((_, val) => val->matchstr('\s*\zs\S\+$'))

    if len(p.keywords) > 0
	p.showPopupMenu()
	# Workaround for vim bug 12538: Explicitly call matchadd and matchaddpos
	# https://github.com/vim/vim/issues/12538
	if &hlsearch
	    matchadd('Search', &ignorecase ? $'\c{p.prefix}' : p.prefix, 11)
	    :redraw
	endif
	if &incsearch && p.firstMatchPos != []
	    matchaddpos('IncSearch', [p.firstMatchPos], 12)
	    :redraw
	endif
    endif

    attr.index += 1
    timer_start(0, function(SearchWorker, [popup, attr]))
enddef

# Populate popup menu and display it.
def UpdateMenu(popup: dict<any>, key: string)
    var p = popup
    var prefix = getcmdline()->strpart(0, getcmdpos() - 1) .. key
    if prefix == '' || prefix =~ '^\s\+$'
	return
    endif
    p.prefix = prefix
    p.searchStartTime = reltime()
    p.candidates = []
    p.keywords = []
    if p.async
	var searchWorkerAttr = {
	    searchStartTime: p.searchStartTime,
	    intervals: p.isForwardSearch->SearchIntervals(options.searchRange),
	    index: 0,
	}
	p->SearchWorker(searchWorkerAttr, 0)
    else
	var cursorpos = [line('.'), col('.')]
	var matches = p.matchingStrings({})
	cursor(cursorpos)
	p.candidates = matches->copy()->filter((_, v) => v =~# $'^{p.prefix}') +
	    matches->copy()->filter((_, v) => v !~# $'^{p.prefix}')
	p.keywords = p.candidates->copy()->map((_, val) => val->matchstr('\s*\zs\S\+$'))
	if len(p.keywords) > 0
	    p.showPopupMenu()
	endif
    endif
enddef

# Select next/prev item in popup menu; wrap around at end of list.
def SelectItem(popup: dict<any>, direction: string)
    var p = popup
    var count = p.keywords->len()
    def SelectVert()
	if p.winid->popup_getoptions().cursorline
	    if p.index == (direction ==# 'j' ? count - 1 : 0)
		for _ in range(count - 1)
		    p.winid->popup_filter_menu(direction ==# 'j' ? 'k' : 'j')
		endfor
		p.index = (direction ==# 'j' ? 0 : count - 1)
	    else
		p.winid->popup_filter_menu(direction)
		p.index += (direction ==# 'j' ? 1 : -1)
	    endif
	else
	    p.winid->popup_setoptions({cursorline: true})
	    for _ in range(count - 1) # rewind to first item
		p.winid->popup_filter_menu('k')
	    endfor
	    p.index = 0
	endif
    enddef

    def SelectHoriz()
	var rotate = false
	if p.index == -1
	    p.index = direction ==# 'j' ? 0 : count - 1
	    rotate = true
	else
	    if p.index == (direction ==# 'j' ? count - 1 : 0)
		p.index = (direction ==# 'j' ? 0 : count - 1)
		rotate = true
	    else
		p.index += (direction ==# 'j' ? 1 : -1)
	    endif
	endif
	var hmenustr = getbufline(p.winid->winbufnr(), 1)[0]
	var kwordpat = $'\<{p.keywords[p.index]}\>'
	if hmenustr !~# kwordpat
	    def HMenuStr(kwidx: number, position: string): string
		var selected = [p.keywords[kwidx]]
		var atleft = position ==# 'left'
		var overflowl = kwidx > 0
		var overflowr = kwidx < p.keywords->len() - 1
		var idx = kwidx
		while (atleft && idx < p.keywords->len() - 1) ||
			(!atleft && idx > 0)
		    idx += (atleft ? 1 : -1)
		    var last = (atleft ? idx == p.keywords->len() - 1 : idx == 0)
		    if selected->join(' ')->len() + p.keywords[idx]->len() + 1 <
			    HMenuWidth() - (last ? 0 : 4)
			if atleft
			    selected->add(p.keywords[idx])
			else
			    selected->insert(p.keywords[idx])
			endif
		    else 
			idx -= (atleft ? 1 : -1)
			break
		    endif
		endwhile
		if atleft
		    overflowr = idx < p.keywords->len() - 1 
		else
		    overflowl = idx > 0
		endif
		return (overflowl ? '... ' : '') .. selected->join(' ') .. (overflowr ? ' ...' : '')
	    enddef
	    var hmenu = ''
	    if direction ==# 'j'
		hmenu = rotate ? HMenuStr(0, 'left') : HMenuStr(p.index, 'right')
	    else 
		hmenu = rotate ? HMenuStr(p.keywords->len() - 1, 'right') : HMenuStr(p.index, 'left')
	    endif
	    hmenu->setbufline(p.winid->winbufnr(), 1)
	endif
	clearmatches(p.winid)
	matchadd('SearchCompletePrefix', $'\c{p.prefix}', 10, -1, {window: p.winid})
	matchadd('SearchCompleteSelect', kwordpat, 11, -1, {window: p.winid})
    enddef

    options.flatMenu ? SelectHoriz() : SelectVert()
    clearmatches()
    setcmdline(p.candidates[p.index])
    if &hlsearch
	matchadd('Search', &ignorecase ? $'\c{p.prefix}' : p.prefix, 11)
    endif
    :redraw # Both flatmenu and vertical menu needs redraw after they change selection
enddef


# Filter function receives keys when popup is shown. It handles special
# keys for scrolling/dismissing popup menu. Other keys are fed back to Vim's
# main loop (through feedkeys).
def Filter(winid: number, key: string): bool
    var p = popupCompletor
    # Note: do not include arrow keys or <c-n> <c-p> since they are used for history lookup
    if key ==? "\<tab>"
	p.selectItem('j') # next item
    elseif key ==? "\<s-tab>"
	p.selectItem('k') # prev item
    elseif key ==? "\<c-e>"
	clearmatches()
	p.winid->popup_hide()
	setcmdline('')
	feedkeys(p.prefix, 'n')
	:redraw!
	timer_start(0, (_) => EnableCmdline()) # timer will que this after feedkeys
    elseif key ==? "\<cr>" || key ==? "\<esc>"
	p.winid->popup_filter_menu('x') # <cr> callback called with result -1 (<cr>) and 0 (<esc>)
	var ret = p.winid->popup_filter_menu(key)
	EnableCmdline()
	return ret
    else
	clearmatches()
	p.winid->popup_hide()
	EnableCmdline()
	p.updateMenu(key)
	return false # Let vim's usual mechanism (search highlighting) handle this
    endif
    return true
enddef

# Create a popup if necessary. When popup is not hidden the filter function
# consumes the keys. When popup is not yet created or if it is hidden
# input keys come through autocommand (tied to CmdlineChanged).
def CompleteWord(popup: dict<any>)
    var p = popup
    if p.winid->popup_getoptions() == {} # popup does not exist, create it
	var attr = {
	    cursorline: false, # Do not automatically select the first item
	    pos: 'botleft',
	    line: &lines - &cmdheight,
	    col: 2,
	    drag: false,
	    filtermode: 'c',
	    filter: Filter,
	    callback: (winid, result) => {
		clearmatches()
		if result == -1 # popup force closed due to <c-c> or cursor mvmt
		    p.winid->popup_filter_menu('Esc')
		    feedkeys("\<c-c>", 'n')
		    EnableCmdline()
		endif
	    },
	}
	p.winid = popup_menu([], attr->extend(PopupOptions()))
	p.winid->popup_hide()
    endif
    p.updateMenu('')
enddef
