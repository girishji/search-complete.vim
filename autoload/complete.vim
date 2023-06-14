vim9script

export var options: dict<any> = {
    enable: true,
    popup: {
	maxheight: 14,
    },
}

const SearchRangeLineCount = 100

# Encapsulate the state and operations of popup menu completion.
def NewPopup(isForwardSearch: bool): dict<any>
    var popup = {
	winid: -1,	    # id of popup window
	keywords: [],	    # keywords shown in popup menu
	candidates: [],	    # candidates for completion (could be phrases)
	index: 0,			# index to keywords and candidates array
	prefix: '',			# cached cmdline contents
	isForwardSearch: isForwardSearch,	# true for '/' and false for '?'
	searchStartTime: [],		# timestamp at which search started
    }
    popup->extend({
	completeWord: function(CompleteWord, [popup]),
	selectItem: function(SelectItem, [popup]),
	showMenu: function(ShowMenu, [popup]),
    })
    return popup
enddef

var popupCompletor = {}

def Init()
    if options.enable
	popupCompletor = getcmdtype() == '/' ? NewPopup(true) : NewPopup(false)
    endif
enddef

def Teardown()
    options.enable ? popupCompletor.winid->popup_close() : true
    popupCompletor = {}
enddef

def Complete()
    options.enable ? popupCompletor.completeWord() : true
enddef

export def Setup()
    augroup SearchComplete | autocmd!
	autocmd CmdlineEnter /,\? Init()
	autocmd CmdlineChanged /,\? Complete()
	autocmd CmdlineLeave /,\? Teardown()
    augroup END
enddef

def EnableCmdline()
    [{
	group: 'SearchComplete',
	event: 'CmdlineChanged',
	pattern: ['/', '\?'],
	cmd: 'Complete()',
	replace: true,
    }]->autocmd_add()
enddef

def DisableCmdline()
    [{
	group: 'SearchComplete',
	event: 'CmdlineChanged',
	pattern: ['/', '\?'],
    }]->autocmd_delete()
enddef

# Match prefix (commandline) even if it is multiword. Return a list of
# matches.
def MatchingStrings(popup: dict<any>): list<any>
    var p = popup
    var matches = []
    var found = {}
    var flags = $'w{p.isForwardSearch ? "" : "b"}' # use 'w' to match pattern under cursor
    var pattern = $'\k*{p.prefix}\k*' # XXX: test if \S is better

    var [lnum, cnum] = pattern->searchpos(flags)
    var [startl, startc] = [lnum, cnum]
    while lnum != 0 && cnum != 0
	var mstr = getline(lnum)->strpart(cnum - 1)->substitute($'^\c\(\k*{p.prefix}\k*\).*$', $'\1', '')
	if mstr != p.prefix && !found->has_key(mstr)
	    found[mstr] = 1
	    matches->add(mstr)
	endif
	[lnum, cnum] = pattern->searchpos(flags)
	if startl == lnum && startc == cnum
	    break
	endif
    endwhile
    return matches->copy()->filter((_, v) => v =~ $'^{p.prefix}') + matches->copy()->filter((_, v) => v !~ $'^{p.prefix}')
enddef

# def SearchIntervals(popup: dict<any>): list<any>
def SearchIntervals(fwd: bool): list<any>
    const Range = 100
    var intervals = []
    var firstsearch = true
    var stopline = 0
    while firstsearch || stopline != (fwd ? line('$') : 1)
	var startline = firstsearch ? line('.') : stopline
	stopline = fwd ? min([startline + Range, line('$')]) : max([startline - Range, 1])
	intervals->add({startl: startline + (firstsearch ? 0 : fwd ? -5 : 5), 
	    startc: firstsearch ? col('.') : 1, stopl: stopline})
	firstsearch = false
    endwhile
    firstsearch = true
    while firstsearch || stopline != line('.')
	var startline = firstsearch ? fwd ? 1 : line('$') : stopline
	stopline = fwd ? min([startline + Range, line('.')]) : max([startline - Range, line('.')])
	intervals->add({startl: startline + (firstsearch ? 0 : fwd ? -5 : 5), startc: 1, stopl: stopline})
	firstsearch = false
    endwhile
    return intervals
enddef

def SearchWorker(attr: dict<any>, timer: number)
    var p = attr.popup
    var prefix = getcmdline()->strpart(0, getcmdpos() - 1)
    var timediff = reltime(attr.popup.searchStartTime, attr.starttime)
    var isStaleSearch = timediff[0] < 0 || timediff[1] < 0
    var isNewerSearch = timediff[0] > 0 || timediff[1] > 0
    if prefix !=# p.prefix || isStaleSearch || attr.index == attr.intervals->len()
	return
    endif

    var pattern = $'\k*{p.prefix}\k*' # XXX: test if \S is better
    var interval = attr.intervals[attr.index]
    var cursorpos = [line('.'), col('.')]
    var curpos = getpos('.')
    cursor(interval.startl, interval.startc)
    var [lnum, cnum] = [0, 0]
    var flags = p.isForwardSearch ? '' : 'b'
    # if attr.index == 0 # first search
	# [lnum, cnum] = pattern->searchpos($'{flags}c')
    # endif
    if [lnum, cnum] == [0, 0]
	[lnum, cnum] = pattern->searchpos(flags, interval.stopl)
    endif
    var found = {}
    var matches = []
    while [lnum, cnum] != [0, 0]
	if !attr.matchfound
	    attr.matchfound = true
	    if &incsearch
		cursorpos = [lnum, cnum]
	    endif
	endif
	var mstr = getline(lnum)->strpart(cnum - 1)->substitute($'^\c\(\k*{p.prefix}\k*\).*$', $'\1', '')
	if mstr != p.prefix && !found->has_key(mstr)
	    found[mstr] = 1
	    matches->add(mstr)
	endif
	[lnum, cnum] = pattern->searchpos(flags, interval.stopl)
    endwhile

    # p.candidates = []
    # p.candidates = p->MatchingStrings()
    # p.keywords = p.candidates->copy()->map((_, val) => val->matchstr('\s*\zs\S\+$'))




    var candidates = isNewerSearch ? matches : p.candidates + matches
    p.candidates = candidates->copy()->filter((_, v) => v =~ $'^{p.prefix}') +
       	candidates->copy()->filter((_, v) => v !~ $'^{p.prefix}')
    p.keywords = p.candidates->copy()->map((_, val) => val->matchstr('\s*\zs\S\+$'))

    if len(p.keywords) > 0
	var lastword = p.prefix->matchstr('\s*\S\+$')
	p.winid->popup_move({col: p.prefix->strridx(lastword) + 2})
	p.winid->popup_settext(p.keywords)
	p.winid->popup_setoptions({cursorline: false})
	matchadd('SearchCompletePrefix', $'\c{p.prefix}', 10, -1, {window: p.winid})
	p.winid->popup_show()
	DisableCmdline()
    endif

    attr.index += 1

    # var view = winsaveview()
    # echom view
    # # echom 'cur befor ' .. cursorpos[0] .. ' ' .. cursorpos[1]
    cursor(cursorpos)
    # # echom 'cur after ' .. cursorpos[0] .. ' ' .. cursorpos[1]
    # # winrestview({lnum: 1, col: 2})
    # setpos()
    # echom 'winid ' .. win_getid()
    timer_start(0, function(SearchWorker, [attr]))
enddef

# Display a popup menu if necessary.
def ShowMenu(popup: dict<any>)
    var p = popup
    p.prefix = getcmdline()->strpart(0, getcmdpos() - 1)
    if p.prefix == '' || p.prefix =~ '\s\+$'
	return
    endif
    p.candidates = []
    p.keywords = []
    p.searchStartTime = reltime()
    var searchWorkerAttr = {
	popup: p,
	starttime: p.searchStartTime,
	matchfound: false,
	intervals: p.isForwardSearch->SearchIntervals(),
	index: 0,
    }
    echom 'menu winid ' .. win_getid()
    timer_start(0, function(SearchWorker, [searchWorkerAttr]))
    # SearchWorker(searchWorkerAttr, 0)
enddef

# Display a popup menu if necessary.
def ShowMenux(popup: dict<any>)
    var p = popup
    var prefix = getcmdline()->strpart(0, getcmdpos() - 1)
    var searchStartTime = reltime()
    if prefix !=# p.prefix
	p.prefix = prefix
	if p.prefix == '' || p.prefix =~ '\s\+$'
	    return
	endif
	p.candidates = []
	p.candidates = p->MatchingStrings()
	p.keywords = p.candidates->copy()->map((_, val) => val->matchstr('\s*\zs\S\+$'))
    endif
    if len(p.keywords) > 0
	var lastword = p.prefix->matchstr('\s*\S\+$')
	p.winid->popup_move({col: p.prefix->strridx(lastword) + 2})
	p.winid->popup_settext(p.keywords)
	p.winid->popup_setoptions({cursorline: false})
	matchadd('SearchCompletePrefix', $'\c{p.prefix}', 10, -1, {window: p.winid})
	p.winid->popup_show()
	DisableCmdline()
    endif
enddef

# Select next/prev item in popup menu; wrap around at end of list.
def SelectItem(popup: dict<any>, dir: string)
    var p = popup
    var count = p.keywords->len()
    if p.winid->popup_getoptions().cursorline
	if p.index == (dir ==# 'j' ? count - 1 : 0)
	    for _ in range(count - 1)
		p.winid->popup_filter_menu(dir ==# 'j' ? 'k' : 'j')
	    endfor
	    p.index = (dir ==# 'j' ? 0 : count - 1)
	else
	    p.winid->popup_filter_menu(dir)
	    p.index += (dir ==# 'j' ? 1 : -1)
	endif
    else
	p.winid->popup_setoptions({cursorline: true})
	for _ in range(count - 1) # rewind to first item
	    p.winid->popup_filter_menu('k')
	endfor
	p.index = 0
    endif
    clearmatches()
    setcmdline(p.candidates[p.index])
    matchadd('Search', p.prefix)
    :redraw
enddef

# Filter function receives keys when popup is not hidden. It handles special
# keys for scrolling popup menu, accepting/dismissing selection, etc.
# Other keys are fed back to Vim's main loop (through feedkeys) for the
# autocommand (CmdlineChanged) to consume.
def Filter(winid: number, key: string): bool
    var p = popupCompletor
    if key ==# "\<tab>" || key ==# "\<c-n>" || key ==# "\<down>"
	p.selectItem('j') # next item
    elseif key ==# "\<s-tab>" || key ==# "\<c-p>" || key ==# "\<up>"
	p.selectItem('k') # prev item
    elseif key ==# "\<c-e>"
	clearmatches()
	p.winid->popup_hide()
	setcmdline('')
	feedkeys(p.prefix, 'n')
	:redraw!
	timer_start(0, (_) => EnableCmdline()) # timer will que this after feedkeys
    elseif key ==? "\<cr>" || key ==? "\<esc>"
	p.winid->popup_filter_menu('x')
	var ret = p.winid->popup_filter_menu(key)
	EnableCmdline()
	return ret # <cr> calls callback with result -1 and <esc> with 0
    else
	clearmatches()
	p.winid->popup_hide() | :redraw
	EnableCmdline()
	feedkeys(key, 'n')
    endif
    return true
enddef

# Create a popup if necessary. When popup is not hidden the 'filter' function
# consumes the keys. When popup is not yet created or if it is hidden
# autocommand (tied to CmdlineChanged) handles the input keys. These two
# mechanisms are kept mutually exclusive by enabling and disabling autocommand.
def CompleteWord(popup: dict<any>)
    var p = popup
    if p.winid->popup_getoptions() == {} # popup does not exist, create it
	var attr = {
	    cursorline: false, # Do not automatically select the first item
	    pos: 'botleft',
	    line: &lines - &cmdheight,
	    drag: false,
	    filtermode: 'c',
	    filter: Filter,
	    callback: (winid, result) => {
		clearmatches()
		if result == -1 # popup force closed due to <c-c> or cursor mvmt
		    p.winid->popup_filter_menu('Esc')
		    feedkeys("\<c-c>", 'n')
		endif
	    },
	}
	p.winid = popup_menu([], attr->extend(options.popup))
	p.winid->popup_hide()
    endif
    p.showMenu()
enddef
