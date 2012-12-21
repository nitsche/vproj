
" Section: Global Plugin Variables {{{1
if !exists('g:vproj_explorer_mapping') || empty(g:vproj_explorer_mapping)
	let g:vproj_explorer_mapping = '<C-E>'
endif

if !exists('g:vproj_filesearch_mapping') || empty(g:vproj_filesearch_mapping)
	let g:vproj_filesearch_mapping = '<C-F>'
endif

if !exists('g:vproj_project_path') || empty(g:vproj_project_path)
	let g:vproj_project_path = '%project%.vproj'
endif

if !exists('g:vproj_explorer_name') || empty(g:vproj_explorer_name)
	let g:vproj_explorer_name = 'ProjectExplorer'
endif

if !exists('g:vproj_explorer_size') || g:vproj_explorer_size < 0
	let g:vproj_explorer_size = 32
endif

if !exists('g:vproj_explorer_position') || (g:vproj_explorer_position !=? 'left' && g:vproj_explorer_position !=? 'right')
	let g:vproj_explorer_position = 'left'
endif

if !exists('g:vproj_filesearch_name') || empty(g:vproj_filesearch_name)
	let g:vproj_filesearch_name = 'FileSearch'
endif

if !exists('g:vproj_filesearch_height') || g:vproj_filesearch_height < 1
	let g:vproj_filesearch_height = 10
endif

if !exists('g:vproj_sort_order')
	let g:vproj_sort_order = ['/$']
endif

if !exists('g:vproj_sort_nocase')
	let g:vproj_sort_nocase = 0
endif

if !exists('g:vproj_split_vertical')
	let g:vproj_split_vertical = 0
endif

if !exists('g:vproj_foldicons') || empty(g:vproj_foldicons)
	let g:vproj_foldicons = ["\u25b8 ", "\u25be "]
endif

if !exists('g:vproj_listmarker') || empty(g:vproj_listmarker)
	let g:vproj_listmarker = "\u25ba "
endif

if !exists('g:vproj_tree_indent') || g:vproj_tree_indent < 1
	let g:vproj_tree_indent = 2
endif





" }}}1

" Section: Script Local Variables {{{1
let s:project = {}
let s:filetree = {}
let s:explorer = {}

" mappings
let s:mappings = {}
let s:mappings[g:vproj_explorer_mapping] = ':call vproj#focus_explorer()'
let s:mappings[g:vproj_filesearch_mapping] = ':call vproj#start_filesearch()'





" }}}1

" Section: Public Functions {{{1
fu vproj#is_open()
	return !empty(s:project)
endf

fu vproj#get_project()
	return s:project
endf


fu vproj#open(name)
	try
		let l:proj = s:load_project(a:name)
		let l:ftree = l:proj.filetree()
		let l:expl = empty(s:explorer) ? s:new_explorer() : s:explorer

		call s:print_info('loading project: '.l:proj.name())
		call l:expl.reload(l:ftree)

		" set global mappings
		for [l:key, l:cmd] in items(s:mappings)
			if !empty(l:key)
				sil! exe 'nunmap! '.l:key
				sil! exe 'nnoremap <silent> '.l:key.' '.l:cmd.'<CR>'
			endif
		endfor

		let s:project = l:proj
		let s:filetree = l:ftree
		let s:explorer = l:expl
		exe 'cd '.s:project.rootdir()

		call s:print_info('project loaded: '.l:proj.name())
	catch
		call s:print_err(v:exception)
	endtry
endf


fu vproj#close(...)
	if !vproj#is_open()
		call s:print_err('No open project')
		return
	endif

	" clear global mappings
	for l:key in keys(s:mappings)
		if !empty(l:key)
			sil! exe 'nunmap! '.l:key
		endif
	endfor

	if s:explorer.bufnum() > 0
		sil! exe 'bwipe! '.s:explorer.bufnum()
	endif

	let s:project = {}
	let s:explorer = {}
endf


fu vproj#reload()
	if !vproj#is_open()
		call s:print_err('No open project')
		return 0
	endif

	try
		call s:print_info('reloading project: '.s:project.name())
		call s:project.reload()
		let s:filetree = s:project.filetree()
		call s:explorer.reload(s:filetree)
		exe 'cd '.s:project.rootdir()

		call s:print_info('project reloaded: '.s:project.name())
		return 1
	catch
		call s:print_err(v:exception)
		return 0
	endtry
endf


fu vproj#reload_filetree()
	if !vproj#is_open()
		return {}
	else
		call s:print_info('reloading tree...')
		let s:filetree = s:project.filetree()
		call s:print_info('reloading tree... done')
		return s:filetree
	endif
endf


fu vproj#focus_explorer()
	let l:winnum = empty(s:explorer) ? -1 : s:explorer.winnum()
	if l:winnum > 0
		sil! exe l:winnum.'wincmd w'
	endif
endf


fu vproj#start_filesearch(...)
	if empty(s:filetree)
		return
	endif

	let l:fsearch = s:new_filesearch(a:0 > 0 ? a:1 : s:filetree.root())
	if a:0 > 1
		call l:fsearch.set_input(a:2)
	endif
	call l:fsearch.start()
endf





" }}}1

" Section: Classes {{{1
" Class: Explorer {{{2
fu s:new_explorer()
	let l:expl = {}
	" attributes
	let l:expl._buf = -1
	let l:expl._size = g:vproj_explorer_size
	let l:expl._tree = {}
	let l:expl._nodes = []
	let l:expl._indent = g:vproj_tree_indent
	let l:expl._foldicons = [g:vproj_foldicons[0], g:vproj_foldicons[1]]
	" methods
	let l:expl.bufnum = function('vproj#__explorer_bufnum')
	let l:expl.winnum = function('vproj#__explorer_winnum')
	let l:expl.size = function('vproj#__explorer_size')
	let l:expl.resize = function('vproj#__explorer_resize')
	let l:expl.selected = function('vproj#__explorer_selected')
	let l:expl.select = function('vproj#__explorer_select')
	let l:expl.select_child = function('vproj#__explorer_select_child')
	let l:expl.select_line = function('vproj#__explorer_select_line')
	let l:expl.collapsed = function('vproj#__explorer_collapsed')
	let l:expl.expand = function('vproj#__explorer_expand')
	let l:expl.collapse = function('vproj#__explorer_collapse')
	let l:expl.show = function('vproj#__explorer_show')
	let l:expl.climb_up = function('vproj#__explorer_climb_up')
	let l:expl.climb_down = function('vproj#__explorer_climb_down')
	let l:expl.execute = function('vproj#__explorer_execute')
	let l:expl.repaint = function('vproj#__explorer_repaint')
	let l:expl.refresh = function('vproj#__explorer_refresh')
	let l:expl.remove = function('vproj#__explorer_remove')
	let l:expl.reload = function('vproj#__explorer_reload')
	let l:expl.filters = function('vproj#__explorer_filters')
	let l:expl.set_filter = function('vproj#__explorer_set_filter')
	let l:expl.new_file = function('vproj#__explorer_new_file')
	let l:expl.rm_file = function('vproj#__explorer_rm_file')
	let l:expl.request_new_file = function('vproj#__explorer_request_new_file')
	let l:expl.request_rm_file = function('vproj#__explorer_request_rm_file')
	let l:expl._lines = function('s:__explorer_lines')
	let l:expl._subnodes = function('s:__explorer_subnodes')
	let l:expl._insert_subnodes = function('s:__explorer_insert_subnodes')
	let l:expl._remove_nodes = function('s:__explorer_remove_nodes')
	return l:expl
endf



fu vproj#__explorer_bufnum() dict
	return self._buf
endf

fu vproj#__explorer_winnum() dict
	return self._buf < 0 ? -1 : bufwinnr(self._buf)
endf

fu vproj#__explorer_size() dict
	return self._size
endf

fu vproj#__explorer_resize(newsize) dict
	if a:newsize < 0
		return
	endif

	let self._size = a:newsize
	let l:mywin = self.winnum()
	if l:mywin > 0 && self._size != winwidth(l:mywin)
		let l:curwin = winnr()
		sil! exe l:mywin.'wincmd w'
		sil! exe 'vert resize '.self._size
		sil! exe l:curwin.'wincmd w'
	endif
endf

fu vproj#__explorer_selected() dict
	let l:idx = line('.') - 1
	return 0 <= l:idx && l:idx < len(self._nodes) ? self._nodes[l:idx] : {}
endf

fu vproj#__explorer_select(node) dict
	if has_key(a:node, '__idx')
		call self.select_line(a:node.__idx + 1)
	endif
endf

fu vproj#__explorer_select_child(node) dict
	if has_key(a:node, '__idx')
		let l:child = a:node.__idx+1 < len(self._nodes) ? self._nodes[a:node.__idx+1] : a:node
		call self.select(l:child.parent() is a:node ? l:child : a:node)
	endif
endf

fu vproj#__explorer_select_line(line) dict
	let l:line = a:line < 1 ? 1 : a:line > line('$') ? line('$') : a:line
	if l:line < 1 || l:line > len(self._nodes)
		call cursor(l:line, 1)
	else
		let l:node = self._nodes[l:line-1]
		let l:indent = s:__explorer_indent_lvl(l:node) * self._indent
		if l:node.is_dir() && l:node.__idx != 0
			let l:icon = self._foldicons[l:node.__folded ? 0 : 1]
			let l:indent += strlen(l:icon) - strwidth(l:icon)
		endif
		call cursor(l:line, l:indent < 1 ? 1 : l:indent)
	endif
endf

fu vproj#__explorer_collapsed(node) dict
	return has_key(a:node, '__folded') && a:node.__folded
endf

fu vproj#__explorer_expand(node) dict
	if !has_key(a:node, '__idx') || !a:node.is_dir() || !a:node.__folded
		return
	endif

	let a:node.__folded = 0
	let l:count = len(self._insert_subnodes(a:node))

	setl modifiable
	let l:line = a:node.__idx + 1
	let l:lines = self._lines(a:node)
	call setline(l:line, l:lines[0])
	if l:count > 0
		call s:insert_lines(l:lines[1:], l:line + 1)
	endif
	setl nomodifiable
	call self.select_line(l:line)
endf

fu vproj#__explorer_collapse(node) dict
	if !has_key(a:node, '__idx') || !a:node.is_dir() || a:node.__folded
		return
	endif

	let a:node.__folded = 1
	let l:count = len(self._subnodes(a:node))
	if l:count > 0
		call self._remove_nodes(a:node.__idx + 1, a:node.__idx + l:count)
	endif

	setl modifiable
	let l:line = a:node.__idx + 1
	call setline(l:line, self._lines(a:node)[0])
	if l:count > 0
		call s:remove_lines(l:line + 1, l:line + l:count)
	endif
	setl nomodifiable
	call self.select_line(l:line)
endf

fu vproj#__explorer_show(path) dict
	let l:node = type(a:path) == type({}) ? a:path : self._tree.find(a:path)
	if empty(l:node) || has_key(l:node, '__idx')
		return l:node
	endif

	let l:parents = [l:node.parent()]
	while !has_key(l:parents[0], '__idx')
		call insert(l:parents, l:parents[0].parent(), 0)
	endwhile

	for l:par in l:parents
		call self.expand(l:par)
	endfor
	return l:node
endf

fu vproj#__explorer_climb_up() dict
	let l:node = self.selected()
	if empty(l:node)
		return
	elseif !l:node.is_dir() || self.collapsed(l:node)
		call self.select(l:node.parent())
	else
		call self.collapse(l:node)
	endif
endf

fu vproj#__explorer_climb_down() dict
	let l:node = self.selected()
	if empty(l:node)
		return
	elseif self.collapsed(l:node)
		call self.expand(l:node)
	else
		call self.select_child(l:node)
	endif
endf

fu vproj#__explorer_execute(node, split) dict
	if empty(a:node)
		return
	elseif !a:node.is_dir()
		call s:open_file(a:node.path(), a:split)
	elseif a:node is self._nodes[0]
		return
	elseif self.collapsed(a:node)
		call self.expand(a:node)
	else
		call self.collapse(a:node)
	endif
endf

fu vproj#__explorer_repaint() dict
	setl modifiable

	let l:curline = line('.')
	let l:curcol = col('.')
	let l:topline = line('w0')
	call s:set_lines(self._lines())
	sil! exe l:topline.'normal! zt'
	call cursor(l:curline, l:curcol)

	setl nomodifiable
endf

fu vproj#__explorer_refresh(node) dict
	if empty(a:node)
		return
	endif

	let l:node = a:node.is_dir() ? a:node : a:node.parent()
	if !has_key(l:node, '__idx') || l:node.__folded
		call self._tree.refresh(l:node)
		return
	endif
	setl modifiable

	" remove old nodes
	let l:nold = len(self._subnodes(l:node))
	if l:nold > 0
		let l:idx0 = l:node.__idx + 1
		let l:idx1 = l:node.__idx + l:nold
		call self._remove_nodes(l:idx0, l:idx1)
		if l:mywin > 0
			call s:remove_lines(l:idx0 + 1, l:idx1 + 1)
		endif
	endif

	" insert new nodes
	call self._tree.refresh(l:node)
	let l:nnew = len(self._insert_subnodes(l:node))
	if l:nnew > 0 && l:mywin > 0
		call s:insert_lines(self._lines(l:node)[1:], l:node.__idx + 2)
	endif

	setl nomodifiable
	call self.select(l:node)
endf

fu vproj#__explorer_remove(node) dict
	if empty(a:node) || a:node is self._tree.root()
		return 0
	endif

	call self._tree.remove(a:node)
	if !has_key(a:node, '__idx')
		return 0
	endif

	let l:count = len(self._subnodes(a:node))
	let l:idx0 = a:node.__idx
	let l:idx1 = l:idx0 + l:count
	call self._remove_nodes(l:idx0, l:idx1)

	setl modifiable
	call s:remove_lines(l:idx0 + 1, l:idx1 + 1)
	setl nomodifiable
	return 1
endf

fu vproj#__explorer_reload(filetree) dict
	if empty(a:filetree)
		return
	endif

	let l:rootnode = a:filetree.root()
	let l:rootnode.__idx = 0
	let l:rootnode.__folded = 1

	let self._tree = a:filetree
	let self._nodes = [l:rootnode]

	if self.winnum() > 0
		sil! exe self.winnum().'wincmd w'
	else
		call s:__explorer_create_win(self)
	endif
	call self.expand(l:rootnode)
	call self.repaint()
endf

fu vproj#__explorer_filters(...) dict
	let l:filters = copy(self._tree.filters())
	if a:0 == 0 || empty(a:1)
		return l:filters
	else
		let l:rx = '^\V'.a:1
		return filter(l:filters, 'v:val =~# l:rx')
	endif
endf

fu vproj#__explorer_set_filter(name) dict
	try
		call self._tree.set_filter(a:name)
	catch
		call s:print_err(v:exception)
		return
	endtry

	if len(self._nodes) > 1
		call self._remove_nodes(1, len(self._nodes)-1)
	endif
	call self._insert_subnodes(self._nodes[0])
	call self.repaint()
	call self.select_line(1)
endf

fu vproj#__explorer_new_file(...) dict
	if a:0 == 0
		return
	endif

	let l:parent_nodes = {}
	for l:fname in a:000
		if !vproj#fs#valid_filename(l:fname)
			call s:print_err('Invalid filename: '.l:fname)
			continue
		endif

		let l:path = vproj#fs#absolute_path(l:fname, self._tree.root())
		let l:path = vproj#fs#normalize_path(l:path)
		if isdirectory(l:path) || filereadable(l:path)
			call s:print_err('File already exists: '.l:fname)
			continue
		elseif !vproj#fs#is_below_filetree(l:path, self._tree)
			call s:print_err('File is not below root path: '.l:fname)
			continue
		elseif !vproj#fs#create_file(l:path)
			call s:print_err('Could not create '.l:fname)
			continue
		else
			call s:print_msg(l:fname.' created')
		endif

		let l:node = self._tree.find_parent(l:path)
		if !empty(l:node)
			let l:parent_nodes[l:node.path()] = l:node
		endif
	endfor

	for l:node in values(l:parent_nodes)
		call self.refresh(l:node)
	endfor

	let l:node = self.show(l:path)
	if !empty(l:node)
		call self.select(l:node)
	endif
endf

fu vproj#__explorer_rm_file(...) dict
	if a:0 == 0
		return
	endif

	let l:selected_node = self.selected()
	let l:selected_line = has_key(l:selected_node, '__idx') ? l:selected_node.__idx+1 : -1

	for l:fname in a:000
		let l:path = vproj#fs#absolute_path(l:fname, self._tree.root())
		let l:path = vproj#fs#normalize_path(l:path)
		if !isdirectory(l:path) && !filereadable(l:path)
			call s:print_err('Could not find '.l:fname)
			continue
		elseif !vproj#fs#is_below_filetree(l:path, self._tree)
			call s:print_err('File is not below root path: '.l:fname)
			continue
		endif

		let l:node = self._tree.find(l:path)
		if !vproj#fs#remove_file(l:path)
			call s:print_err('Could not delete '.l:fname)
			continue
		else
			call s:print_msg(l:fname.' removed')
		endif

		if !empty(l:node)
			call self.remove(l:node)
		endif
	endfor

	call self.repaint()
	if has_key(l:selected_node, '__idx')
		call self.select(l:selected_node)
	elseif l:selected_line > 1
		call self.select_line(l:selected_line - 1)
	endif
endf

fu vproj#__explorer_request_new_file(node) dict
	if empty(a:node)
		return
	endif

	let l:parent = a:node.is_dir() ? a:node : a:node.parent()
	let l:relpath = l:parent.relpath()
	call inputsave()
	let l:fname = input('New '.l:relpath)
	call inputrestore()
	if empty(l:fname)
		return
	elseif !vproj#fs#valid_filename(l:fname)
		call s:print_err('Invalid filename: '.l:fname)
	else
		call self.new_file(l:relpath.l:fname)
	endif
endf

fu vproj#__explorer_request_rm_file(node, confirm) dict
	if empty(a:node)
		return
	endif

	let l:fname = a:node.relpath()
	if a:confirm
		call inputsave()
		echohl Question
		let l:ans = input('Remove '.l:fname.' [yes/no]? ')
		echohl None
		call inputrestore()
		if l:ans !=? 'y' && l:ans !=? 'yes'
			return
		endif
	endif
	call self.rm_file(l:fname)
endf


fu s:__explorer_lines(...) dict
	let l:node = a:0 > 0 ? a:1 : self._nodes[0]
	let l:indent = repeat(' ', s:__explorer_indent_lvl(l:node) * self._indent)

	if !has_key(l:node, '__idx')
		return []
	elseif !l:node.is_dir()
		return [l:indent.l:node.name()]
	elseif l:node.__folded
		let l:icon = self._foldicons[0]
		return l:node.__idx == 0 ? [l:indent.l:node.name()] : [strpart(l:indent, strwidth(l:icon)).l:icon.l:node.name()]
	endif

	let l:icons = self._foldicons
	let l:iconwidths = [strwidth(l:icons[0]), strwidth(l:icons[1])]
	let l:idx = l:node.__idx
	let l:parent = l:node.parent()

	let l:lines = []
	while l:idx < len(self._nodes)
		let l:curnode = self._nodes[l:idx]
		if s:__explorer_siblings(l:node, l:curnode)
			break
		elseif l:curnode.parent() isnot l:parent
			if l:curnode.parent().parent() is l:parent
				" increment level
				let l:parent = l:curnode.parent()
				let l:indent .= repeat(' ', self._indent)
			else
				" decrement level
				while l:curnode.parent() isnot l:parent
					let l:parent = l:parent.parent()
					let l:indent = strpart(l:indent, self._indent)
				endwhile
			endif
		endif
		if !l:curnode.is_dir() || l:curnode.__idx == 0
			call add(l:lines, l:indent.l:curnode.name())
		else
			let l:iconidx = l:curnode.__folded ? 0 : 1
			call add(l:lines, strpart(l:indent, l:iconwidths[l:iconidx]).l:icons[l:iconidx].l:curnode.name())
		endif
		let l:idx += 1
	endwhile
	return l:lines
endf

fu s:__explorer_subnodes(parent) dict
	let l:subnodes = []
	for l:node in self._tree.children(a:parent)
		call add(l:subnodes, l:node)
		if has_key(l:node, '__folded') && !l:node.__folded
			call extend(l:subnodes, self._subnodes(l:node))
		elseif l:node.is_dir()
			let l:node.__folded = 1
		endif
	endfor
	return l:subnodes
endf

fu s:__explorer_insert_subnodes(parent) dict
	let l:nodes = self._subnodes(a:parent)
	if empty(l:nodes)
		return []
	endif

	let l:idx = a:parent.__idx
	for l:node in l:nodes
		let l:idx += 1
		let l:node.__idx = l:idx
		call insert(self._nodes, l:node, l:idx)
	endfor

	let l:idx += 1
	while l:idx < len(self._nodes)
		let self._nodes[l:idx].__idx = l:idx
		let l:idx += 1
	endwhile
	return l:nodes
endf

fu s:__explorer_remove_nodes(idx0, idx1) dict
	let l:removed = remove(self._nodes, a:idx0, a:idx1)
	for l:node in l:removed
		unlet l:node.__idx
	endfor

	" update following indices
	for l:idx in range(a:idx0, len(self._nodes)-1)
		let self._nodes[l:idx].__idx = l:idx
	endfor
	return l:removed
endf


fu s:__explorer_indent_lvl(node)
	let l:lvl = 0
	let l:par = a:node.parent()
	while !empty(l:par)
		let l:lvl += 1
		let l:par = l:par.parent()
	endwhile
	return l:lvl
endf

fu s:__explorer_siblings(left, right)
	return a:left isnot a:right && a:left.parent() is a:right.parent()
endf

fu s:__explorer_create_win(expl)
	let l:pos = g:vproj_explorer_position ==? 'right' ? 'botright' : 'topleft'
	if a:expl._buf > 0
		sil! exe l:pos.' vert sb '.a:expl._buf
		sil! exe 'vert resize '.a:expl._size
	else
		sil! exe l:pos.' vert '.a:expl._size.' new '.g:vproj_explorer_name
		let a:expl._buf = bufnr('%')

		" options
		abc <buffer>
		setl noswapfile
		setl buftype=nofile
		setl bufhidden=hide
		setl nobuflisted
		setl nonumber
		setl nowrap
		setl nospell
		setl cursorline
		setl nocursorcolumn
		setl nomodifiable

		" mappings
		nnoremap <buffer> <silent> h             :<C-U>call b:explorer.climb_up()<CR>
		nnoremap <buffer> <silent> l             :<C-U>call b:explorer.climb_down()<CR>
		nnoremap <buffer> <silent> k             :<C-U>call b:explorer.select_line(line('.')-v:count1)<CR>
		nnoremap <buffer> <silent> j             :<C-U>call b:explorer.select_line(line('.')+v:count1)<CR>
		nnoremap <buffer> <silent> v             <Nop>
		nnoremap <buffer> <silent> V             <Nop>
		nnoremap <buffer> <silent> r             :<C-U>call b:explorer.refresh(b:explorer.selected())<CR>
		nnoremap <buffer> <silent> n             :<C-U>call b:explorer.request_new_file(b:explorer.selected())<CR>
		nnoremap <buffer> <silent> d             :<C-U>call b:explorer.request_rm_file(b:explorer.selected(), 1)<CR>
		nnoremap <buffer> <silent> D             :<C-U>call b:explorer.request_rm_file(b:explorer.selected(), 0)<CR>
		nmap     <buffer> <silent> <Return>      :<C-U>call b:explorer.execute(b:explorer.selected(), 0)<CR>
		nmap     <buffer> <silent> <C-Return>    :<C-U>call b:explorer.execute(b:explorer.selected(), 1)<CR>
		nmap     <buffer> <silent> <Left>        h
		nmap     <buffer> <silent> <C-Left>      h
		nmap     <buffer> <silent> <Right>       l
		nmap     <buffer> <silent> <C-Right>     l
		nmap     <buffer> <silent> <Up>          k
		nmap     <buffer> <silent> <C-Up>        k
		nmap     <buffer> <silent> <Down>        j
		nmap     <buffer> <silent> <C-Down>      j
		nmap     <buffer> <silent> <F5>          r
		nmap     <buffer> <silent> <Del>         d
		nmap     <buffer> <silent> <S-Del>       D
		nmap     <buffer> <silent> <LeftMouse>   <LeftMouse>:if exists('b:explorer') <bar> call b:explorer.select_line(line('.')) <bar> endif<CR>
		nmap     <buffer> <silent> <2-LeftMouse> <Return>
		nmap     <buffer> <silent> <RightMouse>  <Nop>

		" autocommands
		aug vproj
			au! * <buffer>
			au BufEnter    <buffer> setl cursorline
			au BufLeave    <buffer> setl nocursorline
			au BufDelete   <buffer> call b:explorer._buf = -1
			au BufWinEnter <buffer> if exists('b:selected_line') | call b:explorer.select_line(b:selected_line) | unlet b:selected_line | endif
			au BufWinLeave <buffer> let b:selected_line = line('.')
			au WinLeave    <buffer> call b:explorer.resize(winwidth(0))
		aug end

		" commands
		com! -buffer -nargs=0 Reload :call b:explorer.reload(vproj#reload_filetree())
		com! -buffer -nargs=+ -complete=file New :call b:explorer.new_file(<f-args>)
		com! -buffer -nargs=+ -complete=file Remove :call b:explorer.rm_file(<f-args>)
		com! -buffer -nargs=1 -complete=customlist,b:explorer.filters Filter :call b:explorer.set_filter(<f-args>)

		" syntax
		if s:has_syntax()
			let l:icons = '\%('.a:expl._foldicons[0].'\|'.a:expl._foldicons[1].'\)'
			sil! exe 'sy match vprojProjectRoot ''^\[.*\]$'''
			sil! exe 'sy match vprojFile        ''^\s\+\zs[^/\\]\+$'''
			sil! exe 'sy match vprojDirectory   ''^\s*\zs'.l:icons.'[^/\\]\+[/\\]$'' contains=vprojPathSep,vprojFoldIcon'
			sil! exe 'sy match vprojPathSep     ''[/\\]'' contained'
			sil! exe 'sy match vprojFoldIcon    ''\%(^\s*\)\@<='.l:icons.''' contained'

			sil! exe 'hi link vprojProjectRoot Directory'
			sil! exe 'hi link vprojDirectory   Directory'
			sil! exe 'hi link vprojPathSep     Delimiter'
			sil! exe 'hi link vprojFoldIcon    Delimiter'
		endif
	endif
	let b:explorer = a:expl
	let &l:statusline = bufname(a:expl._buf)
endf





" }}}2
" Class: Filesearch {{{2
fu s:new_filesearch(dir)
	let l:filenames = vproj#fs#rfilelist(a:dir)
	let l:fs = {}
	" attributes
	let l:fs._inp = ''
	let l:fs._rx = ['']
	let l:fs._fnames = copy(l:filenames)
	let l:fs._allfnames = l:filenames
	let l:fs._marker = g:vproj_listmarker
	let l:fs._nomatches = '** NO MATCHES **'
	let l:fs._maxsize = g:vproj_filesearch_height
	let l:fs._bufname = g:vproj_filesearch_name
	" methods
	let l:fs.filenames = function('s:__filesearch_filenames')
	let l:fs.refresh = function('s:__filesearch_refresh')
	let l:fs.set_input = function('s:__filesearch_set_input')
	let l:fs.start = function('s:__filesearch_start')
	let l:fs._regex = function('s:__filesearch_regex')
	let l:fs._add_char = function('s:__filesearch_add_char')
	let l:fs._rm_last_char = function('s:__filesearch_rm_last_char')
	let l:fs._update_window = function('s:__filesearch_update_window')
	let l:fs._select_line = function('s:__filesearch_select_line')
	return l:fs
endf


fu s:__filesearch_filenames() dict
	return self._fnames
endf

fu s:__filesearch_refresh() dict
	let l:rx = self._regex()
	let self._fnames = []
	for l:fname in self._allfnames
		if s:__filesearch_match(l:fname, l:rx)
			call add(self._fnames, l:fname)
		endif
	endfor
endf

fu s:__filesearch_set_input(inp) dict
	let l:parts = split(a:inp, '[/\\]')
	let self._inp = a:inp
	let self._rx = [s:__filesearch_to_regex(l:parts[0])]
	if len(l:parts) > 1
		let l:idx = 1
		while l:idx < len(l:parts)-1
			call add(self._rx, '[^/\\]*'.s:__filesearch_to_regex(l:parts[l:idx]))
			let l:idx += 1
		endwhile
		call add(self._rx, empty(l:parts[-1]) ? '' : '[^/\\]*'.s:__filesearch_to_regex(l:parts[-1]))
	endif
	call self.refresh()
endf

fu s:__filesearch_start() dict
	sil! exe 'botright 1new '.self._bufname
	setl noswapfile
	setl buftype=nofile
	setl bufhidden=wipe
	setl nobuflisted
	setl winfixheight
	setl nonumber
	setl nowrap
	setl nospell
	setl cursorline
	setl nocursorcolumn
	setl nomodifiable
	if s:has_syntax()
		sil! exe 'sy match vprojListMarker ''^\V'.escape(self._marker, '\').''''
		sil! exe 'sy match vprojNoMatches  ''^\V'.escape(self._nomatches, '\').'$'''
		sil! exe 'hi link vprojFileMatch  Special'
		sil! exe 'hi link vprojListMarker Delimiter'
	endif
	call self._update_window()

	let l:bufnum = bufnr('%')
	while l:bufnum > 0
		let l:key = s:getch()
		if l:key ==? "\<Esc>" || l:key ==? "\<C-C>"
			sil! exe 'bwipe! '.l:bufnum
			call s:print_info('')
			return
		elseif l:key ==? "\<Return>" || l:key ==? "\<C-Return>"
			let l:idx = line('.') - 1
			sil! exe 'bwipe! '.l:bufnum
			call s:print_info('')
			call s:open_file(self._fnames[l:idx], getcharmod() == 4)
			return
		elseif l:key ==? "\<Up>"
			call self._select_line(line('.') - 1)
		elseif l:key ==? "\<Down>"
			call self._select_line(line('.') + 1)
		elseif l:key ==? "\<BS>"
			call self._rm_last_char()
			call self._update_window()
		elseif l:key[0] !=# "\x80" && self._add_char(l:key)
			call self._update_window()
		endif
	endwhile
endf


fu s:__filesearch_regex() dict
	return join(self._rx, '[^/\\]*[/\\]')
endf

fu s:__filesearch_add_char(ch) dict
	if empty(a:ch)
		return 1
	elseif !s:__filesearch_valid_input(a:ch)
		return 0
	elseif a:ch =~# '[/\\]'
		call add(self._rx, '')
	else
		let self._rx[-1] .= (len(self._rx) > 1 && !empty(self._rx[-1]) ? '[^/\\]*' : '').s:__filesearch_to_regex(a:ch)
	endif
	let self._inp .= a:ch
	let l:rx = self._regex()
	call filter(self._fnames, 's:__filesearch_match(v:val, l:rx)')
	return 1
endf

fu s:__filesearch_rm_last_char() dict
	if self._inp =~# '[/\\]$'
		let self._inp = substitute(self._inp, '[/\\]$', '', '')
		call remove(self._rx, -1)
	else
		let self._inp = substitute(self._inp, '.$', '', '')
		if len(self._rx) == 1
			let self._rx[0] = s:__filesearch_to_regex(self._inp)
		else
			let l:part = strpart(self._inp, match(self._inp, '[/\\]', 0, len(self._rx)-1) + 1)
			let self._rx[-1] = empty(l:part) ? '' : '[^/\\]*'.s:__filesearch_to_regex(l:part)
		endif
	endif
	call self.refresh()
endf

fu s:__filesearch_update_window() dict
	let l:lines = []
	let l:prefix = repeat(' ', strwidth(self._marker))
	for l:fname in self.filenames()
		call add(l:lines, l:prefix.l:fname)
	endfor

	setl modifiable
	call s:set_lines(empty(l:lines) ? [self._nomatches] : l:lines)
	sil! exe 'resize '.min([empty(l:lines) ? 1 : len(l:lines), self._maxsize])
	sil! exe len(l:lines).'normal! zb'
	setl nomodifiable

	if s:has_syntax()
		call clearmatches()
		call matchadd('vprojFileMatch', '^.*\zs'.self._regex().'\ze.*$')
	endif
	let &l:statusline = self._bufname.' ('.len(l:lines).' files)'
	call self._select_line(len(l:lines))
endf

fu s:__filesearch_select_line(line) dict
	if !empty(self._fnames)
		let l:curln = line('.')
		let l:newln = a:line < 1 ? 1 : a:line > line('$') ? line('$') : a:line

		setl modifiable
		let l:markerwidth = strwidth(self._marker)
		call setline(l:curln, substitute(getline(l:curln), '^'.self._marker, repeat(' ', l:markerwidth), ''))
		call setline(l:newln, substitute(getline(l:newln), '^\s\{'.l:markerwidth.'}', self._marker, ''))
		call cursor(l:newln, 1)
		setl nomodifiable
	endif
	call s:print_info('> '.self._inp)
endf


fu s:__filesearch_to_regex(str)
	let l:rx = escape(a:str, '^.\~[]')
	let l:rx = substitute(l:rx, '^\*\+', '', '')
	let l:rx = substitute(l:rx, '\*\+$', '', '')
	let l:rx = substitute(l:rx, '?', '[^/\\]', 'g')
	let l:rx = substitute(l:rx, '\*', '[^/\\]*', 'g')
	return l:rx
endf

fu s:__filesearch_valid_input(str)
	return a:str =~# '^[^%:]$'
endf

fu s:__filesearch_match(fname, rx)
	return empty(a:rx) || a:fname =~ a:rx
endf





" }}}2
" Class: Project {{{2
fu s:load_project(name)
	let l:fname = s:__project_fname(a:name)
	if empty(l:fname)
		throw 'Cannot find project: 'a:name
	endif

	let l:proj = {}
	" attributes
	let l:proj._cfg = s:__project_read_cfg(l:fname)
	" methods
	let l:proj.name = function('s:__project_name')
	let l:proj.filename = function('s:__project_filename')
	let l:proj.rootdir = function('s:__project_rootdir')
	let l:proj.whitelists = function('s:__project_whitelists')
	let l:proj.blacklists = function('s:__project_blacklists')
	let l:proj.reload = function('s:__project_reload')
	let l:proj.filetree = function('s:__project_filetree')
	return l:proj
endf


fu s:__project_name() dict
	return self._cfg.get_value('project', 'name')
endf

fu s:__project_filename() dict
	return self._cfg.filename()
endf

fu s:__project_rootdir() dict
	return self._cfg.get_value('project', 'root')
endf

fu s:__project_whitelists() dict
	return self._cfg.section('filter')
endf

fu s:__project_blacklists() dict
	return self._cfg.section('ignore')
endf

fu s:__project_reload() dict
	let self._cfg = s:__project_read_cfg(self._cfg.filename())
endf

fu s:__project_filetree() dict
	return vproj#fs#load_filetree('['.self.name().']', self.rootdir(), self.whitelists(), self.blacklists())
endf


fu s:__project_fname(name)
	let l:fname = fnamemodify(a:name, ':p')
	if filereadable(l:fname)
		return l:fname
	endif

	for l:path in type(g:vproj_project_path) == type([]) ? g:vproj_project_path : [g:vproj_project_path]
		let l:fname = fnamemodify(substitute(l:path, '%project%', a:name, 'g'), ':p')
		if filereadable(l:fname)
			return l:fname
		endif
	endfor
	return ''
endf

fu s:__project_read_cfg(fname)
	let l:cfg = vproj#conf#read_config_file(a:fname)

	let l:name = l:cfg.get_value('project', 'name')
	if empty(l:name)
		call l:cfg.set_value('project', 'name', fnamemodify(a:fname, ':t:r'))
	endif

	let l:root = l:cfg.get_value('project', 'root')
	if empty(l:root)
		let l:root = fnamemodify(a:fname, ':h')
	else
		let l:root = vproj#fs#absolute_path(l:root, fnamemodify(a:fname, ':p:h'))
	endif
	call l:cfg.set_value('project', 'root', vproj#fs#normalize_path(l:root))

	if !isdirectory(l:root)
		throw 'Invalid root directory in '.a:fname
	endif
	return l:cfg
endf





" }}}2
" }}}1
"
" Section: Private Functions {{{1
fu s:print_msg(msg)
	redraw
	for l:line in type(a:msg) == type([]) ? a:msg : split(a:msg, "\n")
		echomsg l:line
	endfor
endf

fu s:print_err(msg)
	echohl ErrorMsg
	call s:print_msg(a:msg)
	echohl None
endf

fu s:print_info(text)
	redraw
	echo a:text
endf

fu s:has_syntax()
	return has('syntax') && exists('g:syntax_on')
endf

fu s:remove_lines(ln, ...)
	let l:rng = a:0 > 0 ? a:ln.','.a:1 : a:ln
	sil! exe l:rng.'d _'
endf

fu s:insert_lines(lines, ln)
	let l:oldreg = @"
	let @" = type(a:lines) == type([]) ? join(a:lines, "\n") : a:lines
	if a:ln == 1
		sil! exe a:ln.'put! "'
	else
		sil! exe (a:ln-1).'put "'
	endif
	let @" = l:oldreg
endf

fu s:set_lines(lines)
	call s:remove_lines('%')
	call setline(1, a:lines)
endf

fu s:getch()
	try
		let l:char = getchar()
		return type(l:char) == type(0) ? nr2char(l:char) : l:char
	catch /^Vim:Interrupt$/
		return "\<Esc>"
	endtry
endf

fu s:open_file(fname, split)
	let l:wincount = winnr('$')
	let l:focused = winnr() == s:explorer.winnum()
	if l:wincount == 1 && l:focused
		" create new window
		let l:pos = g:vproj_explorer_position ==? 'right' ? 'topleft' : 'botright'
		exe l:pos.' vert new '.a:fname
		sil! exe 'wincmd p'
		sil! exe 'vert resize '.e:explorer.size()
		sil! exe 'wincmd p'
		return
	elseif l:focused
		sil! exe 'wincmd p'
	endif

	let l:openwin = winnr()
	if !buflisted(winbufnr(l:openwin))
		let l:curwin = winnr('$')
		while l:curwin > 0
			let l:curbuf = winbufnr(l:curwin)
			if bufexists(l:curbuf) && buflisted(l:curbuf)
				let l:openwin = l:curwin
				break
			endif
			let l:curwin -= 1
		endwhile
	endif

	sil! exe l:openwin.'wincmd w'
	let l:cmd = !a:split ? 'e' : g:vproj_split_vertical ? 'vs' : 'sp'
	exe l:cmd.' '.a:fname
endf




" }}}1

" vim:fen:fdm=marker:fmr={{{,}}}
