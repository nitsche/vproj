if exists('g:loaded_vproj')
	finish
endif
let g:loaded_vproj = 1



" Section: Commands {{{1
com -nargs=1 -complete=file Project call vproj#open(<f-args>)
com -nargs=0 CloseProject call vproj#close()
com -nargs=0 ReloadProject call vproj#reload()

" }}}1

" vim:fen:fdm=marker:fmr={{{,}}}
