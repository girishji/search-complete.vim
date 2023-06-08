vim9script

export var options: dict<any> = {
    setupKeybindings: true,
    previewWindow: true,
    previewWindowSize: 3,
    fuzzySearch: false,
    maxHeight: 0,
}

# Encapsulate the state and operations of popup menu completion.
def NewPopup(searchForward: bool): dict<any>
    var popup = {
	winid: -1,	    # id of popup window
	keywords: [],	    # cached keywords shown in popup menu
	candidates: [],	    # cached candidates for completion (could be phrases)
	index: 0,			# index to keywords and candidates array
	prefix: '',			# cached cmdline contents
	searchForward: searchForward,	# true for '/' and false for '?'
    }
    popup->extend({
	complete: function(PopupComplete, [popup]),
	selectItem: function(SelectItem, [popup]),
	menu: function(Menu, [popup]),
	multiWords: function(MultiWords, [popup]),
	# words: function(Words, [popup]),
    })
    return popup
enddef

var popupCompletor = {}

def Init()
    popupCompletor = getcmdtype() == '/' ? NewPopup(true) : NewPopup(false)
enddef

def Teardown()
    popupCompletor.winid->popup_close()
    popupCompletor = {}
enddef

def Complete()
    popupCompletor.complete()
enddef

export def Setup()
    augroup SearchComplete | autocmd!
	autocmd CmdlineEnter /,\? Init()
	autocmd CmdlineChanged /,\? Complete()
	autocmd CmdlineLeave /,\? Teardown()
    augroup END
enddef

def EnableCmdline()
    # autocmd SearchComplete CmdlineChanged /,\? Complete()
    # [{
	# group: 'SearchComplete',
	# event: 'CmdlineChanged',
	# pattern: ['/', '\?'],
	# cmd: 'Complete()',
	# replace: true,
    # }]->autocmd_add()
enddef

def DisableCmdline()
    # autocmd! SearchComplete CmdlineChanged
    # [{
	# group: 'SearchComplete',
	# event: 'CmdlineChanged',
	# pattern: ['/', '\?'],
    # }]->autocmd_delete()
enddef

# # Return a list of keywords suitable for completion, sorted according to
# # distance from cursor.
# def Words(popup: dict<any>): list<any>
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
#     var candidates = words->filter((_, val) =>
# 		\ (icase ? val->tolower()->stridx(p.prefix) : val->stridx(p.prefix)) == 0)
#     return candidates->sort((x, y) => dist[x] < dist[y] ? -1 : 1)
# enddef

# Match entire prefix (commandline contents) even if it is multiword. Return a
# list of matches. Useful when user continues to search after first keyword.
def MultiWords(popup: dict<any>): list<any>
    var p = popup
    var matches = []
    var found = {}
    var flags = $'w{p.searchForward ? "" : "b"}' # use 'w' to match pattern under cursor
    var pattern = $'{p.prefix}\k*' # XXX: test if \S is better
    var [lnum, cnum] = pattern->searchpos(flags)
    var [startl, startc] = [lnum, cnum]

    while lnum != 0 && cnum != 0
	var mstr = getline(lnum)->strpart(cnum - 1)->substitute($'^{p.prefix}\(\k*\).*$', $'{p.prefix}\1', '')
	if mstr != p.prefix && !found->has_key(mstr)
	    found[mstr] = 1
	    matches->add(mstr)
	endif
	[lnum, cnum] = pattern->searchpos(flags)
	if startl == lnum && startc == cnum
	    break
	endif
    endwhile
    return matches
enddef


# Display a popup menu if necessary.
def Menu(popup: dict<any>)
    var p = popup
    var prefix = getcmdline()->strpart(0, getcmdpos() - 1)
    if prefix !=# p.prefix
	p.prefix = prefix
	if p.prefix == '' || p.prefix =~ '\s\+$'
	    return
	endif
	p.candidates = {}
	# if p.prefix !~ '\s'
	#     p.candidates = p.words()
	#     if len(p.candidates) > 0
	# 	p.keywords = p.candidates
	#     endif
	# endif
	if len(p.candidates) == 0
	    p.candidates = p.multiWords()
	    p.keywords = p.candidates->copy()->map((_, val) => val->matchstr('\s*\S\+$'))
	endif
    endif
    if len(p.keywords) > 0
	var lastword = p.prefix->matchstr('\s*\S\+$')
	p.winid->popup_move({col: p.prefix->strridx(lastword) + 2})
	p.winid->popup_settext(p.keywords)
	p.winid->popup_setoptions({cursorline: false})
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
    'Search'->matchadd(p.prefix)
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
    else
	clearmatches()
	if key ==# "\<c-e>"
	    p.winid->popup_hide()
	    setcmdline('')
	    feedkeys(p.prefix, 'n')
	    :redraw!
	    timer_start(0, (_) => EnableCmdline()) # que this after feeding keys
	elseif key ==? "\<cr>" || key ==? "\<esc>"
	    p.winid->popup_filter_menu('x')
	    var ret = p.winid->popup_filter_menu(key)
	    EnableCmdline()
	    return ret
	else
	    p.winid->popup_hide() | :redraw
	    EnableCmdline()
	    feedkeys(key, 'n')
	endif
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
	p.winid = popup_menu([], {
	    cursorline: false, # Do not automatically select the first item
	    pos: 'botleft',
	    line: &lines - &cmdheight,
	    # highlight: 'SearchCompleteNormal' # Popup PopupSel
	    drag: false,
	    filtermode: 'c',
	    filter: Filter,
	    callback: (winid, result) => {
		if result == -1 # popup force closed due to <c-c> or cursor mvmt
		    p.winid->popup_filter_menu('Esc')
		    feedkeys("\<c-c>", 'n')
		endif
	    },
	})
	p.winid->popup_hide()
	DisableCmdline() # So that only filter fn of popup consumes keys
    endif
    p.menu()
enddef
