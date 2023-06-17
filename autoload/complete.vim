vim9script

export var options: dict<any> = {
    enable: true,
    timeout: 100, # millisec
    maxheight: 12,
    highlight: 'SearchCompleteMenu',
    scrollbarhighlight: 'SearchCompleteSbar',
    thumbhighlight: 'SearchCompleteThumb',
}

def PopupOptions(): dict<any>
    return options->copy()->filter((k, _) => k !~ 'enable\|timeout')
enddef

# Encapsulate the state and operations of popup menu completion.
def NewPopup(isForwardSearch: bool): dict<any>
    var popup = {
	winid: -1,	    # id of popup window
	keywords: [],	    # keywords shown in popup menu
	candidates: [],	    # candidates for completion (could be phrases)
	index: 0,			# index to keywords and candidates array
	prefix: '',			# cached cmdline contents
	isForwardSearch: isForwardSearch,	# true for '/' and false for '?'
    }
    popup->extend({
	completeWord: function(CompleteWord, [popup]),
	selectItem: function(SelectItem, [popup]),
	updateMenu: function(UpdateMenu, [popup]),
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
    autocmd SearchComplete CmdlineChanged /,\? Complete()
enddef

def DisableCmdline()
    autocmd! SearchComplete CmdlineChanged /,\?
enddef

# Match prefix (commandline) even if it is multiword. Return a list of
# matches.
def MatchingStrings(popup: dict<any>): list<any>
    var p = popup
    var matches = []
    var found = {}
    var flags = $'w{p.isForwardSearch ? "" : "b"}' # use 'w' to match pattern under cursor
    var pattern = $'\k*{p.prefix}\k*' # XXX: test if \S is better

    var start = reltime()
    var [bline, bcol] = pattern->searchpos(flags, 0, options.timeout)
    var [startl, startc] = [bline, bcol]
    while [bline, bcol] != [0, 0]
	var [eline, ecol] = pattern->searchpos('ceW') # end of matching string
	var lines = getline(bline, eline)
	var mstr = ''
	if lines->len() == 1
	    mstr = lines[0]->strpart(bcol - 1, ecol - bcol + 1)
	else
	    var mlist = [lines[0]->strpart(bcol - 1)] + lines[1 : -2] + [lines[-1]->strpart(0, ecol)]
	    mstr = mlist->join('\n')
	endif
	if mstr != p.prefix && !found->has_key(mstr)
	    found[mstr] = 1
	    matches->add(mstr)
	endif
	[bline, bcol] = pattern->searchpos(flags, 0, options.timeout)
	if (startl == bline && startc == bcol) || (start->reltime()->reltimefloat() * 1000) > options.timeout
	    break
	endif
    endwhile
    return matches->copy()->filter((_, v) => v =~ $'^{p.prefix}') + matches->copy()->filter((_, v) => v !~ $'^{p.prefix}')
enddef

# Display a popup menu if necessary.
def UpdateMenu(popup: dict<any>, key: string)
    echom 'showMenu called'
    var p = popup
    var prefix = getcmdline()->strpart(0, getcmdpos() - 1) .. key
    var searchStartTime = reltime()
    if prefix !=# p.prefix
	p.prefix = prefix
	if p.prefix == '' || p.prefix =~ '^\s\+$'
	    return
	endif
	p.candidates = []
	p.candidates = p->MatchingStrings()
	p.keywords = p.candidates->copy()->map((_, val) => val->matchstr('\_s*\zs\S\+$'))
	if len(p.keywords) > 0
	    var lastword = p.prefix->matchstr('\s*\S\+$')
	    p.winid->popup_move({col: p.prefix->strridx(lastword) + 2})
	    p.winid->popup_settext(p.keywords)
	    p.winid->popup_setoptions({cursorline: false})
	    clearmatches(p.winid)
	    matchadd('SearchCompletePrefix', $'\c{p.prefix}', 10, -1, {window: p.winid})
	    p.winid->popup_show()
	    DisableCmdline()
	endif
    endif
enddef

# Select next/prev item in popup menu; wrap around at end of list.
def SelectItem(popup: dict<any>, direction: string)
    var p = popup
    var count = p.keywords->len()
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
    clearmatches()
    setcmdline(p.candidates[p.index])
    matchadd('Search', p.prefix)
    :redraw
enddef

# Filter function receives keys when popup is shown. It handles special
# keys for scrolling/dismissing popup menu. Other keys are fed back to Vim's
# main loop (through feedkeys).
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
	p.winid->popup_filter_menu('x') # <cr> callback called with result -1 (<cr>) and 0 (<esc>)
	var ret = p.winid->popup_filter_menu(key)
	EnableCmdline()
	return ret
    else
	clearmatches()
	p.winid->popup_hide() | :redraw
	EnableCmdline()
	p.updateMenu(key)
	return false # Let vim's usual mechanism (search highlighting) handle this
    endif
    return true
enddef

# Create a popup if necessary. When popup is not hidden the 'filter' function
# consumes the keys. When popup is not yet created or if it is hidden
# autocommand (tied to CmdlineChanged) handles the input keys.
def CompleteWord(popup: dict<any>)
    echom 'completeWord called'
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
	p.winid = popup_menu([], attr->extend(PopupOptions()))
	p.winid->popup_hide()
    endif
    p.updateMenu('')
    # timer_start(0, (_) => p.updateMenu(''))
enddef
