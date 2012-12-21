

fu vproj#conf#read_config_file(filename)
	if !filereadable(a:filename)
		throw 'Cannot read "'.a:filename.'".'
	endif

	let l:sections = {}
	let l:cursec = {}
	let l:linenum = 0
	for l:line in readfile(a:filename)
		let l:linenum += 1
		if s:is_empty(l:line) || s:is_comment(l:line)
			continue
		elseif s:is_section(l:line)
			let l:secname = s:get_section_name(l:line)
			if has_key(l:sections, l:secname)
				let l:cursec = l:sections[l:secname]
			else
				let l:cursec = s:new_section()
				let l:sections[l:secname] = l:cursec
			endif
		elseif empty(l:cursec)
			throw 'File "'.a:filename.'" does not start with a section.'
		elseif !s:is_vardecl(l:line)
			throw 'File "'.a:filename.'" contains an invalid variable declaration (see line '.l:linenum.').'
		else
			let l:nv = s:get_name_value_pair(l:line)
			call l:cursec.add_value(l:nv[0], l:nv[1])
		endif
	endfor
	return s:new_config(a:filename, l:sections)
endf





" config class
fu s:new_config(filename, sections)
	let l:cfg = {}
	" attributes
	let l:cfg._fname = a:filename
	let l:cfg._secs = a:sections
	" methods
	let l:cfg.filename = function('vproj#conf#__config_filename')
	let l:cfg.sections = function('vproj#conf#__config_sections')
	let l:cfg.section = function('vproj#conf#__config_section')
	let l:cfg.variables = function('vproj#conf#__config_variables')
	let l:cfg.count_values = function('vproj#conf#__config_count_values')
	let l:cfg.get_values = function('vproj#conf#__config_get_values')
	let l:cfg.get_value = function('vproj#conf#__config_get_value')
	let l:cfg.set_value = function('vproj#conf#__config_set_value')
	let l:cfg.add_value = function('vproj#conf#__config_add_value')
	return l:cfg
endf


fu vproj#conf#__config_filename() dict
	return self._fname
endf


fu vproj#conf#__config_sections() dict
	return keys(self._secs)
endf


fu vproj#conf#__config_section(sec) dict
	if !has_key(self._secs, a:sec)
		return {}
	endif

	let l:vars = {}
	for l:var in self.variables(a:sec)
		let l:vars[l:var] = self.get_values(a:sec, l:var)
	endfor
	return l:vars
endf


fu vproj#conf#__config_variables(sec) dict
	return has_key(self._secs, a:sec) ? self._secs[a:sec].variables() : []
endf


fu vproj#conf#__config_count_values(sec, var) dict
	return has_key(self._secs, a:sec) ? self._secs[a:sec].count_values(a:var) : 0
endf


fu vproj#conf#__config_get_values(sec, var) dict
	return has_key(self._secs, a:sec) ? self._secs[a:sec].get_values(a:var) : []
endf


fu vproj#conf#__config_get_value(sec, var, ...) dict
	return has_key(self._secs, a:sec) ? self._secs[a:sec].get_value(a:var, a:0 > 0 ? a:1 : -1) : ''
endf


fu vproj#conf#__config_set_value(sec, var, val) dict
	if !has_key(self._secs, a:sec)
		let self._secs[a:sec] = s:new_section()
	endif
	call self._secs[a:sec].set_value(a:var, a:val)
endf


fu vproj#conf#__config_add_value(sec, var, val) dict
	if !has_key(self._secs, a:sec)
		let self._secs[a:sec] = s:new_section()
	endif
	call self._secs[a:sec].add_value(a:var, a:val)
endf





" Class: section
fu s:new_section()
	let l:sec = {}
	" attributes
	let l:sec._vars = {}
	" methods
	let l:sec.variables = function('s:__section_variables')
	let l:sec.count_values= function('s:__section_count_values')
	let l:sec.set_value = function('s:__section_set_value')
	let l:sec.add_value = function('s:__section_add_value')
	let l:sec.get_values = function('s:__section_get_values')
	let l:sec.get_value = function('s:__section_get_value')
	return l:sec
endf


fu s:__section_variables() dict
	return keys(self._vars)
endf


fu s:__section_count_values(name) dict
	return has_key(self._vars, a:name) ? len(self._vars[a:name]) : 0
endf


fu s:__section_set_value(name, val) dict
	if type(a:val) == type([])
		let self._vars[a:name] = a:val
	else
		let self._vars[a:name] = [a:val]
	endif
endf


fu s:__section_add_value(name, val) dict
	if !has_key(self._vars, a:name)
		call self.set_value(a:name, a:val)
	elseif type(a:val) == type([])
		call extend(self._vars[a:name], a:val)
	else
		call add(self._vars[a:name], a:val)
	endif
endf


fu s:__section_get_values(name) dict
	return has_key(self._vars, a:name) ? self._vars[a:name] : []
endf


fu s:__section_get_value(name, idx) dict
	if !has_key(self._vars, a:name)
		return ''
	endif

	let l:val = self._vars[a:name][a:idx]
	if s:is_true_string(l:val)
		return 1
	elseif s:is_false_string(l:val)
		return 0
	else
		return l:val
	endif
endf





" Section: Private functions
fu s:trim_front(line)
	return substitute(a:line, '^\s*', '', '')
endf


fu s:trim_back(line)
	return substitute(a:line, '\s*$', '', '')
endf


fu s:is_true_string(s)
	return a:s ==? 'true' || a:s ==? 'yes' || a:s ==? 'on'
endf


fu s:is_false_string(s)
	return a:s ==? 'false' || a:s ==? 'no' || a:s ==? 'off'
endf



fu s:is_empty(line)
	return a:line =~# '^\s*$'
endf


fu s:is_comment(line)
	return a:line =~# '^\s*#.*$'
endf


fu s:is_section(line)
	return a:line =~# '^\s*\[[[:alnum:]_.-]\+\]\s*\(#.*\)\?$'
endf


fu s:is_vardecl(line)
	if a:line =~# '^\s*[[:alnum:]_.-]\+\s*\(#.*\)\?$'
		return 1
	elseif a:line =~# '^\s*[[:alnum:]_.-]\+\s*=\s*"\([^"\\]\|\\["nb\\]\)*"\s*\(#.*\)\?$'
		return 1
	elseif a:line =~# '^\s*[[:alnum:]_.-]\+\s*=\s*\([^[:space:]"#\\]\|\\["nb\\]\)\([^#\\]\|\\["nb\\]\)*\s*\(#.*\)\?$'
		return 1
	else
		return 0
	endif
endf



fu s:get_section_name(line)
	" a:line is a valid section
	let l:name = s:trim_front(a:line)
	let l:name = substitute(l:name, '\s*#.*$', '', '')	" strip comment and trailing whitespaces
	return strpart(l:name, 1, strlen(l:name)-2)
endf



fu s:get_name_value_pair(line)
	" a:line is a valid variable declaration
	let l:decl = s:trim_front(a:line)
	let l:idx = stridx(l:decl, '=')
	if l:idx < 0
		return [s:trim_back(l:decl), 'true']
	endif

	let l:name = s:trim_back(strpart(l:decl, 0, l:idx))
	let l:val = s:trim_front(strpart(l:decl, l:idx+1))
	let l:val = s:trim_back(l:val)
	if l:val =~# '^"'
		let l:val = matchstr(l:val, '^"\([^"\\]\|\\["nb\\]\)*"')
		let l:val = strpart(l:val, 1, strlen(l:val)-2)
	else
		let l:val = substitute(l:val, '\s*#.*$', '', '')
	endif

	let l:val = s:unescape(l:val)
	return [l:name, l:val]
endf



fu s:escape(s)
	let l:esc = substitute(a:s, '\\', '\\\\', 'g')
	let l:esc = substitute(l:esc, '\n', '\\n', 'g')
	let l:esc = substitute(l:esc, '\b', '\\b', 'g')
	let l:esc = substitute(l:esc, '"', '\\"', 'g')
	return l:esc
endf

fu s:unescape(s)
	let l:unesc = a:s
	let l:unesc = substitute(l:unesc, '\([^\\]\|\(\\\\\)\+\)\@<=\\n', "\n", 'g')
	let l:unesc = substitute(l:unesc, '\([^\\}\|\(\\\\\)\+\)\@<=\\b', "\b", 'g')
	let l:unesc = substitute(l:unesc, '\\\([\\"]\)', '\1', 'g')
	return l:unesc
endf
