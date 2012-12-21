
" Section: Script Local Variables {{{1
let s:iswin = has('win16') || has('win32') || has('win64')
let s:strcmp = g:vproj_sort_nocase ? 's:_stricmp' : 's:_strcmp'
let s:sortgroups = copy(g:vproj_sort_order)





" }}}1

" Section: Public Functions {{{1
fu vproj#fs#load_filetree(name, rootdir, whitelists, blacklists)
	if !isdirectory(a:rootdir)
		throw 'Invalid root directory: '.a:rootdir
	endif

	let l:tree = s:new_tree(a:name, a:rootdir, a:whitelists, a:blacklists)
	call l:tree.reload()
	return l:tree
endf


fu vproj#fs#valid_filename(name)
	return a:name !~# '/\{2,}\|[?%*:]'
endf


fu vproj#fs#absolute_path(path, parent_dir)
	if a:path =~# '^[/~]'
		return fnamemodify(a:path, ':p')
	else
		let l:base = type(a:parent_dir) == type({}) ? a:parent_dir.path() : fnamemodify(a:parent_dir, ':p')
		return substitute(l:base, '/$', '', '').'/'.a:path
	endif
endf


fu vproj#fs#is_below_filetree(path, tree)
	" a:path must be absolute
	let l:path = a:path =~# '/$' ? a:path : a:path.'/'
	let l:root = a:tree.root().path()
	return l:path =~# '^'.l:root
endf


fu vproj#fs#normalize_path(path)
	" a:path must be absolute
	let l:path = substitute(a:path, '^/\?\(\.\.\/\)\+', '/', '')
	let l:path = substitute(l:path, '/\./', '/', 'g')
	let l:path = substitute(l:path, '^\./', '', '')
	let l:path = substitute(l:path, '/\.$', '/', '')
	if stridx(l:path, '..') < 0
		return l:path
	endif

	let l:resparts = []
	for l:part in split(l:path, '/')
		if l:part !=# '..'
			call add(l:resparts, l:part)
		elseif !empty(l:resparts)
			call remove(l:resparts, -1)
		endif
	endfor

	let l:suffix = l:path =~# '/$' ? '/' : ''
	return '/'.join(l:resparts, '/').l:suffix
endf


fu vproj#fs#create_file(path)
	" a:path must be absolute
	if a:path =~# '/$'
		call mkdir(substitute(a:path, '/$', '', ''), 'p')
		return 1
	elseif filereadable(a:path)
		return 1
	else
		return writefile([], a:path) == 0 ? 1 : 0
	endif
endf


fu vproj#fs#remove_file(path)
	" a:path must be absolute
	if !isdirectory(a:path)
		return delete(a:path) ? 0 : 1
	else
		let l:rm = s:iswin ? 'rmdir /s /q ' : 'rm -rf '
		let l:dir = shellescape(a:path)
		call system(l:rm.l:dir)
		return v:shell_error ? 0 : 1
	endif
endf


fu vproj#fs#filelist(dir)
	let l:fnames = []
	call s:add_to_filelist(a:dir, l:fnames, a:dir.relpath(), 's:filecmp')
	return l:fnames
endf

fu vproj#fs#rfilelist(dir)
	let l:fnames = []
	call s:add_to_filelist(a:dir, l:fnames, a:dir.relpath(), 's:rfilecmp')
	return l:fnames
endf





" }}}1

" Section: Classes {{{1
" Class: tree {{{2
fu s:new_tree(name, rootpath, whitelists, blacklists)
	let l:tree = {}
	" attributes
	let l:tree._root = s:new_root_directory(a:rootpath, a:name)
	let l:tree._filtgr = s:new_filtergroup(a:whitelists, a:blacklists)
	let l:tree._curfilt = '*'
	" methods
	let l:tree.root = function('vproj#fs#__tree_root')
	let l:tree.children = function('vproj#fs#__tree_children')
	let l:tree.find = function('vproj#fs#__tree_find')
	let l:tree.find_parent = function('vproj#fs#__tree_find_parent')
	let l:tree.refresh = function('vproj#fs#__tree_refresh')
	let l:tree.reload = function('vproj#fs#__tree_reload')
	let l:tree.remove = function('vproj#fs#__tree_remove')
	let l:tree.filters = function('vproj#fs#__tree_filters')
	let l:tree.set_filter = function('vproj#fs#__tree_set_filter')
	let l:tree.getfilt = function('s:__tree_getfilt')
	let l:tree.find_nearest = function('s:__tree_find_nearest')
	return l:tree
endf


fu vproj#fs#__tree_root() dict
	return self._root
endf

fu vproj#fs#__tree_children(node) dict
	if !a:node.is_dir()
		return []
	else
		return s:sort_files(filter(a:node.children(), '!v:val.hidden()'))
	endif
endf

fu vproj#fs#__tree_find(path) dict
	let l:node = self.find_nearest(a:path)
	if !empty(l:node) && !l:node.hidden() && substitute(a:path, '/$', '', '') ==# substitute(l:node.path(), '/$', '', '')
		return l:node
	else
		return {}
	endif
endf

fu vproj#fs#__tree_find_parent(path) dict
	let l:path = fnamemodify(substitute(a:path, '/$', '', ''), ':h')
	return self.find(l:path)
endf

fu vproj#fs#__tree_refresh(node) dict
	if a:node.is_dir()
		call a:node.refresh(self._filtgr, self.getfilt())
	endif
endf

fu vproj#fs#__tree_reload() dict
	call self._root.reload(self._filtgr, self.getfilt())
endf

fu vproj#fs#__tree_remove(node) dict
	if a:node is self._root
		return 0
	else
		return a:node.parent().remove_child(a:node)
	endif
endf

fu vproj#fs#__tree_filters() dict
	return self._filtgr.filters()
endf

fu vproj#fs#__tree_set_filter(name) dict
	if !self._filtgr.has_filter(a:name)
		throw 'Unknown filter: '.a:name
	else
		let self._curfilt = a:name
		call self._root.filter(self.getfilt())
	endif
endf

fu s:__tree_getfilt() dict
	return self._filtgr.get_filter(self._curfilt)
endf

fu s:__tree_find_nearest(path) dict
	if !isdirectory(a:path) && !filereadable(a:path)
		return {}
	endif

	let l:path = fnamemodify(a:path, ':p')
	let l:dir = self._root
	if strpart(l:path, 0, strlen(l:dir.path())) !=# l:dir.path()
		" not below root
		return {}
	endif

	let l:path = strpart(l:path, strlen(l:dir.path()))
	let l:parts = split(l:path, '/')
	for l:idx in range(len(l:parts)-1)
		let l:child = l:dir.child(l:parts[l:idx])
		if empty(l:child) || !l:child.is_dir()
			return l:dir
		endif
		let l:dir = l:child
	endfor

	let l:child = l:dir.child(l:parts[-1])
	return empty(l:child) ? l:dir : l:child
endf





" }}}2
" Class: directory {{{2
fu s:new_directory(name, parent, ...)
	let l:dir = a:0 > 0 ? s:new_file(a:name, a:parent, a:1) : s:new_file(a:name =~# '/$' ? a:name : a:name.'/', a:parent)
	" attributes
	let l:dir._sub = {}
	" methods
	let l:dir.children = function('s:__directory_children')
	let l:dir.child = function('s:__directory_child')
	let l:dir.add_child = function('s:__directory_add_child')
	let l:dir.remove_child = function('s:__directory_remove_child')
	let l:dir.refresh = function('s:__directory_refresh')
	let l:dir.reload = function('s:__directory_reload')
	let l:dir.filter = function('s:__directory_filter')
	return l:dir
endf

fu s:new_root_directory(path, name)
	return s:new_directory(a:name, {}, a:path =~# '/$' ? a:path : a:path.'/')
endf


fu s:__directory_children() dict
	return values(self._sub)
endf

fu s:__directory_child(name) dict
	let l:name = substitute(a:name, '/$', '', '')
	return has_key(self._sub, l:name) ? self._sub[l:name] : {}
endf

fu s:__directory_add_child(name) dict
	let l:name = substitute(a:name, '/$', '', '')
	if has_key(self._sub, l:name)
		return self._sub[l:name]
	else
		let l:child = isdirectory(self.path().l:name) ? s:new_directory(l:name, self) : s:new_file(l:name, self)
		let self._sub[l:name] = l:child
		return l:child
	endif
endf

fu s:__directory_remove_child(child) dict
	let l:name = substitute(type(a:child) == type({}) ? a:child.name() : a:child, '/$', '', '')
	if !has_key(self._sub, l:name)
		return 0
	else
		call remove(self._sub, l:name)
		return 1
	endif
endf

fu s:__directory_refresh(filtgr, filt) dict
	let l:dir = self.relpath()
	let l:newsub = {}
	for l:path in split(globpath(self.path(), '*', 1), "\n")
		let l:fname = fnamemodify(l:path, ':t')
		if l:path !~# '^\.\.\?$' && a:filtgr.evaluate(l:dir.l:fname)
			let l:newsub[l:fname] = isdirectory(self.path().l:fname) ? s:new_directory(l:fname, self) : s:new_file(l:fname, self)
		endif
	endfor

	call filter(self._sub, 'has_key(l:newsub, v:key)')
	call filter(l:newsub, '!has_key(self._sub, v:key)')
	for [l:key, l:val] in items(l:newsub)
		let self._sub[l:key] = l:val
	endfor

	for l:node in self.children()
		call l:node.hide(!a:filt.evaluate(l:dir.l:node.name()))
	endfor
endf

fu s:__directory_reload(filtgr, filt) dict
	let l:rootprefix = strlen(self.root().path())
	let l:myprefix = strlen(self.path())
	let self._sub = {}
	for l:path in split(globpath(self.path(), '**', 1), "\n")
		let l:path = fnamemodify(l:path, ':p')
		if l:path =~# '/\.\.\?/\?$' || !a:filtgr.evaluate(strpart(l:path, l:rootprefix))
			continue
		endif
		let l:parent = self
		for l:part in split(strpart(l:path, l:myprefix), '/')
			if has_key(l:parent._sub, l:part)
				let l:parent = l:parent._sub[l:part]
			else
				let l:parent = l:parent.add_child(l:part)
				call l:parent.hide(!a:filt.evaluate(strpart(l:parent.path(), l:rootprefix)))
			endif
		endfor
	endfor
endf

fu s:__directory_filter(filt, ...) dict
	let l:rootprefix = a:0 > 0 ? a:1 : strlen(self.root().path())
	for l:child in self.children()
		call l:child.hide(!a:filt.evaluate(strpart(l:child.path(), l:rootprefix)))
		if l:child.is_dir()
			call l:child.filter(a:filt, l:rootprefix)
		endif
	endfor
endf





" }}}2
" Class: file {{{2
fu s:new_file(name, parent, ...)
	let l:fl = {}
	" attributes
	let l:fl._par = a:parent
	let l:fl._name = a:name
	let l:fl._path = a:0 > 0 ? a:1 : a:parent._path.a:name
	" methods
	let l:fl.parent = function('vproj#fs#__file_parent')
	let l:fl.root = function('vproj#fs#__file_root')
	let l:fl.name = function('vproj#fs#__file_name')
	let l:fl.path = function('vproj#fs#__file_path')
	let l:fl.relpath = function('vproj#fs#__file_relpath')
	let l:fl.is_dir = function('vproj#fs#__file_is_dir')
	let l:fl.hidden = function('s:__file_hidden')
	let l:fl.hide = function('s:__file_hide')
	return l:fl
endf


fu vproj#fs#__file_parent() dict
	return self._par
endf

fu vproj#fs#__file_root() dict
	let l:root = self
	while !empty(l:root._par)
		let l:root = l:root._par
	endwhile
	return l:root
endf

fu vproj#fs#__file_name() dict
	return self._name
endf

fu vproj#fs#__file_path() dict
	return self._path
endf

fu vproj#fs#__file_relpath() dict
	return strpart(self._path, strlen(self.root()._path))
endf

fu vproj#fs#__file_is_dir() dict
	return has_key(self, 'children')
endf

fu s:__file_hidden() dict
	return has_key(self, '_hide')
endf

fu s:__file_hide(h) dict
	if a:h
		let self._hide = 1
	elseif has_key(self, '_hide')
		unlet self._hide
	endif
endf





" }}}2
" Class: filter {{{2
fu s:new_filter(whitelist, blacklist)
	let l:filt = {}
	" attributes
	let l:filt._wlst = a:whitelist
	let l:filt._blst = a:blacklist
	" methods
	let l:filt.whitelisted = function('s:__filter_whitelisted')
	let l:filt.blacklisted = function('s:__filter_blacklisted')
	let l:filt.evaluate = function('s:__filter_evaluate')
	return l:filt
endf


fu s:__filter_whitelisted(fname) dict
	for l:rx in self._wlst
		if a:fname =~# l:rx
			return 1
		endif
	endfor
	return 0
endf

fu s:__filter_blacklisted(fname) dict
	for l:rx in self._blst
		if a:fname =~# l:rx
			return 1
		endif
	endfor
	return 0
endf

fu s:__filter_evaluate(fname) dict
	return self.whitelisted(a:fname) && !self.blacklisted(a:fname)
endf





" }}}2
" Class: filtergroup {{{2
fu s:new_filtergroup(whitelists, blacklists)
	let l:generic_wlist = has_key(a:whitelists, '_') ? a:whitelists['_'] : []
	let l:generic_blist = has_key(a:blacklists, '_') ? a:blacklists['_'] : []

	let l:filters = {}
	for l:var in keys(a:whitelists)
		if l:var ==# '_'
			continue
		endif
		let l:wlist = a:whitelists[l:var]
		let l:blist = has_key(a:blacklists, l:var) ? a:blacklists[l:var] : []
		let l:filters[l:var] = s:new_filter(l:wlist + l:generic_wlist, l:blist + l:generic_blist)
	endfor

	let l:fg = {}
	" attributes
	let l:fg._filt = l:filters
	if empty(l:filters)
		let l:fg._generic = s:new_filter(empty(l:generic_wlist) ? ['.'] : l:generic_wlist, l:generic_blist)
	endif
	" methods
	let l:fg.filters = function('s:__filtergroup_filters')
	let l:fg.has_filter = function('s:__filtergroup_has_filter')
	let l:fg.get_filter = function('s:__filtergroup_get_filter')
	let l:fg.whitelisted = function('s:__filtergroup_whitelisted')
	let l:fg.blacklisted = function('s:__filtergroup_blacklisted')
	let l:fg.evaluate = function('s:__filtergroup_evaluate')
	return l:fg
endf


fu s:__filtergroup_filters() dict
	return ['*'] + keys(self._filt)
endf

fu s:__filtergroup_has_filter(name) dict
	return a:name ==# '*' || has_key(self._filt, a:name)
endf

fu s:__filtergroup_get_filter(name) dict
	if a:name ==# '*'
		return self
	else
		return self._filt[a:name]
	endif
endf

fu s:__filtergroup_whitelisted(fname) dict
	if empty(self._filt)
		return self._generic.whitelisted(a:fname)
	else
		for l:filt in values(self._filt)
			if l:filt.whitelisted(a:fname)
				return 1
			endif
		endfor
		return 0
	endif
endf

fu s:__filtergroup_blacklisted(fname) dict
	if empty(self._filt)
		return self._generic.blacklisted(a:fname)
	else
		for l:filt in values(self._filt)
			if l:filt.blacklisted(a:fname)
				return 1
			endif
		endfor
		return 0
	endif
endf

fu s:__filtergroup_evaluate(fname) dict
	return self.whitelisted(a:fname) && !self.blacklisted(a:fname)
endf





" }}}2
" }}}1

" Section: Private Functions {{{1
fu s:add_to_filelist(dir, files, prefix, sortfunc)
	for l:child in sort(a:dir.children(), a:sortfunc)
		if l:child.is_dir()
			call s:add_to_filelist(l:child, a:files, a:prefix.l:child.name(), a:sortfunc)
		else
			call add(a:files, a:prefix.l:child.name())
		endif
	endfor
endf



fu s:sort_files(files)
	return sort(a:files, 's:filecmp')
endf

fu s:filecmp(left, right)
	return s:fnamecmp(a:left.name(), a:right.name())
endf

fu s:rfilecmp(left, right)
	return 0 - s:fnamecmp(a:left.name(), a:right.name())
endf


fu s:fnamecmp(left, right)
	let [l:lg, l:rg] = [s:_sortgroup(a:left), s:_sortgroup(a:right)]
	if l:lg != l:rg
		return l:lg - l:rg
	else
		return call(s:strcmp, [substitute(a:left, '/$', '', ''), substitute(a:right, '/$', '', '')])
	endif
endf


fu s:_sortgroup(fname)
	let l:g = 0
	for l:rx in s:sortgroups
		if a:fname =~# l:rx
			break
		endif
		let l:g += 1
	endfor
	return l:g
endf

fu s:_strcmp(left, right)
	return a:left ==# a:right ? 0 : a:left <# a:right ? -1 : 1
endf

fu s:_stricmp(left, right)
	return a:left ==? a:right ? 0 : a:left <? a:right ? -1 : 1
endf


" }}}1

" vim:fen:fdm=marker:fmr={{{,}}}
