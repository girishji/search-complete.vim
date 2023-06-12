vim9script

export var options: dict<any> = {
    enable: true,
    popup: {
	maxheight: 14,
    },
}

const SearchRangeLineCount = 100

# Encapsulate the state and operations of popup menu completion.
def NewPopup(searchForward: bool): dict<any>
    var popup = {
	winid: -1,	    # id of popup window
	keywords: [],	    # keywords shown in popup menu
	candidates: [],	    # candidates for completion (could be phrases)
	index: 0,			# index to keywords and candidates array
	prefix: '',			# cached cmdline contents
	searchForward: searchForward,	# true for '/' and false for '?'
    }
    popup->extend({
	complete: function(PopupComplete, [popup]),
	selectItem: function(SelectItem, [popup]),
	menu: function(Menu, [popup]),
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
    options.enable ? popupCompletor.complete() : true
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

# # Return a list of keywords suitable for completion, sorted according to
# # distance from cursor.
# def WordMatch(popup: dict<any>): list<any>
#     var p = popup
#     var words = []
#     var dist = {}
#     var linenum = 1
#     for line in getline(1, '$')
# 	for word in line->split('\W\+')
# 	    if word->len() > 1
# 		var curdist = abs(linenum - line('.'))
# 		if dist->has_key(word)
# 		    dist[word] = curdist < dist[word] ? curdist : dist[word]
# 		else
# 		    dist[word] = curdist
# 		    words->add(word)
# 		endif
# 	    endif
# 	endfor
# 	linenum += 1
#     endfor

#     var icase: bool = &ignorecase
#     if &ignorecase && &smartcase && p.prefix =~ '\u\+'
# 	icase = false
#     endif
#     var candidates = words->copy()->filter((_, val) =>
# 		\ (icase ? val->tolower()->stridx(p.prefix) : val->stridx(p.prefix)) == 0)
#     return candidates->sort((x, y) => dist[x] < dist[y] ? -1 : 1)
# enddef

# Match prefix (commandline) even if it is multiword. Return a list of
# matches.
def MatchingStrings(popup: dict<any>): list<any>
    var p = popup
    var matches = []
    var found = {}
    var flags = $'w{p.searchForward ? "" : "b"}' # use 'w' to match pattern under cursor
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

# def MatchesWorker(popup: dict<any>, range: dict<any>, searchBeginTime: string, timer: number)
#     var p = popup
#     if p.searchBeginTime != searchBeginTime
# 	return
#     endif
#     var flags = $'w{p.searchForward ? "" : "b"}' # use 'w' to match pattern under cursor
#     var pattern = $'\k*{p.prefix}\k*' # XXX: test if \S is better
#     var stopline = line('$') <= SearchRangeLineCount ? 0 : (line('.') + SearchRangeLineCount) % line('$')
#     var [lnum, cnum] = pattern->searchpos(flags, stopline)
#     if [lnum, cnum] == [0, 0]
# 	if line('$') <= SearchRangeLineCount
# 	    return
# 	endif
# 	# xxx
# 	return timer_start(0, function(MatchesWorker, [searchBeginTime]))
#     endif
#     var [startl, startc] = [lnum, cnum]
#     while lnum != 0 && cnum != 0
# 	var mstr = getline(lnum)->strpart(cnum - 1)->substitute($'^\c\(\k*{p.prefix}\k*\).*$', $'\1', '')
# 	if mstr != p.prefix && !found->has_key(mstr)
# 	    found[mstr] = 1
# 	    matches->add(mstr)
# 	endif
# 	[lnum, cnum] = pattern->searchpos(flags)
# 	if startl == lnum && startc == cnum
# 	    break
# 	endif
#     endwhile

# enddef

# def Matches(popup: dict<any>): list<any>
#     var p = popup
#     var matches = []
#     var found = {}
#     var flags = $'w{p.searchForward ? "" : "b"}' # use 'w' to match pattern under cursor
#     var pattern = $'\k*{p.prefix}\k*' # XXX: test if \S is better

#     var [lnum, cnum] = pattern->searchpos(flags)
#     var [startl, startc] = [lnum, cnum]
#     while lnum != 0 && cnum != 0
# 	var mstr = getline(lnum)->strpart(cnum - 1)->substitute($'^\c\(\k*{p.prefix}\k*\).*$', $'\1', '')
# 	if mstr != p.prefix && !found->has_key(mstr)
# 	    found[mstr] = 1
# 	    matches->add(mstr)
# 	endif
# 	[lnum, cnum] = pattern->searchpos(flags)
# 	if startl == lnum && startc == cnum
# 	    break
# 	endif
#     endwhile
#     return matches->copy()->filter((_, v) => v =~ $'^{p.prefix}') + matches->copy()->filter((_, v) => v !~ $'^{p.prefix}')
# enddef

# def SetStopline(attr: dict<any>): bool
#     var p = attr.popup
#     if attr.sartpos[1] == line('.') && col('.') == p.searchForward ? col('$') : 1
# 	return false # search has wrapped around, nothing more to search
#     endif
#     if attr.startpos != getpos('.') # not first search worker attempt
# 	# start subsequent searches +-5 lines, to cover multiline search
# 	cursor(line('.') - (p.searchForward ? 5 : -5), 1)
#     endif
#     attr.stopline += p.searchForward ? SearchRangeLineCount : -SearchRangeLineCount
#     if p.searchForward && if attr.stopLine > line('$')
# 	cursor(1, 1)
# 	attr.stopline = SearchRangeLineCount
#     elseif attr.stopLine < 1
# 	cursor(line('$'), 1)
# 	attr.stopline = line('$') - SearchRangeLineCount
#     endif
#     return true
# enddef

def SearchIntervals(popup: dict<any>): list<any>
    var p = popup
    const Range = 100
    var intervals = []
    var startpos = {line: line('.'), col: col('.')}
    var endpos = startpos
    var lookback = false # multiline searches at interval boundary needs to include a few lines before start
    while endpos != {line: p.searchForward ? line('$') : 1, col: strwidth(getline('$'))}
	var spos = endpos->copy()
	var stopline = p.searchForward ? min([endpos.line + Range, line('$')]) :  max([endpos.line - Range, line('$')])
	endpos = {line: stopline, col: strwidth(getline(stopline))}
	intervals->add([lookback ? {line: spos.line + (p.searchForward ? -5 : 5), col: 1} : spos, stopline])
	echom $' {intervals[-1][0].line} : {intervals[-1][0].col}, stop: {stopline}'
	lookback = true
    endwhile
    lookback = false
    endpos = p.searchForward ? {line: 1, col: 1} : {line: line('$'), col: 1}
    while endpos != {line: startpos.line, col: strwidth(getline(startpos.line))}
	var spos = endpos->copy()
	var stopline = p.searchForward ? min([endpos.line + Range, startpos.line]) :  max([endpos.line - Range, startpos.line])
	endpos = {line: stopline, col: strwidth(getline(stopline))}
	intervals->add([{line: spos.line + (lookback ? (p.searchForward ? -5 : 5) : 0), col: 1}, stopline])
	echom $' {intervals[-1][0].line} : {intervals[-1][0].col}, stop: {stopline}'
	lookback = true
    endwhile
    return intervals
enddef

# def SearchWorker(attr: dict<any>, timer: number)
#     if reltime(attr.popup.searchStartTime, attr.searchStartTime) < 0 # state search, a new search is in progress
# 	return
#     endif
#     var p = attr.popup

#     var flags = $'w{p.searchForward ? "" : "b"}' # use 'w' to match pattern under cursor
#     var pattern = $'\k*{p.prefix}\k*' # XXX: test if \S is better

#     if SetStopline(searchWorkerAttr)
# 	timer_start(0, function(SearchWorker, [searchWorkerAttr]))
#     endif

# 	# p.candidates = p->MatchingStrings()
# 	# p.keywords = p.candidates->copy()->map((_, val) => val->matchstr('\s*\zs\S\+$'))
#     # if len(p.keywords) > 0
# 	# var lastword = p.prefix->matchstr('\s*\S\+$')
# 	# p.winid->popup_move({col: p.prefix->strridx(lastword) + 2})
# 	# p.winid->popup_settext(p.keywords)
# 	# p.winid->popup_setoptions({cursorline: false})
# 	# matchadd('SearchCompletePrefix', $'\c{p.prefix}', 10, -1, {window: p.winid})
# 	# p.winid->popup_show()
# 	# DisableCmdline()
#     # endif
# enddef

# # Display a popup menu if necessary.
# def Menux(popup: dict<any>)
#     var p = popup
#     var p.prefix = getcmdline()->strpart(0, getcmdpos() - 1)
#     if p.prefix == '' || p.prefix =~ '\s\+$'
# 	return
#     endif
#     p.candidates = {}
#     p.keywords = {}
#     p.startTime = reltime()
#     var searchWorkerAttr = {
# 	popup: p,
# 	searttime: p.starttime,
# 	startpos: getpos('.'),
# 	stopline: -1,
#     }
#     if SetStopline(searchWorkerAttr)
# 	timer_start(0, function(SearchWorker, [searchWorkerAttr]))
#     endif
# enddef

# Display a popup menu if necessary.
def Menu(popup: dict<any>)
    var p = popup
    p->SearchIntervals()
    var prefix = getcmdline()->strpart(0, getcmdpos() - 1)
    var searchStartTime = reltime()
    if prefix !=# p.prefix
	p.prefix = prefix
	if p.prefix == '' || p.prefix =~ '\s\+$'
	    return
	endif
	p.candidates = {}
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

# Select next/prev item in popup menu, and wrap around at end of list.
# The 'wrap around' mechanism adds a bit of complexity.
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
def PopupComplete(popup: dict<any>)
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
    p.menu()
enddef
