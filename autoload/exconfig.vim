let s:old_titlestring=&titlestring
let s:old_tagrelative=&tagrelative
let s:old_tags=&tags

" exconfig#apply_project_type {{{
function exconfig#apply_project_type()
endfunction

" exconfig#reset {{{
function exconfig#reset()
    let &titlestring=s:old_titlestring
    let &tagrelative=s:old_tagrelative
    let &tags=s:old_tags
endfunction

" exconfig#edit {{{
function exconfig#edit_cur_vimentry()
    let project_name = vimentry#get('project_name')
    let project_cwd = g:exvim_project_root
    if project_name == ''
        call ex#error("Can't find vimentry setting 'project_name'.")
        return
    endif
    if  findfile( project_name.'.exvim', escape(project_cwd,' \') ) != ""
        let vimentry_file = project_name . '.exvim'
        call ex#hint( 'edit vimentry file: ' . vimentry_file )
        call ex#window#goto_edit_window()
        silent exec 'e ' . project_cwd . '/' . vimentry_file
    else
        call ex#warning("can't find current vimentry file")
    endif
endfunction

function! exconfig#Generate_ignore(ignore,tool, ...) abort
    let ignore = []
    if a:tool ==# 'ag'
        for ig in split(a:ignore,',')
            call add(ignore, '--ignore')
            call add(ignore, "'" . ig . "'")
        endfor
    elseif a:tool ==# 'rg'
        if ex#os#is('windows')
            for ig in split(a:ignore,',')
                call add(ignore, '-g')
                if a:0 > 0
                    call add(ignore, "\"" . ig . "\"")
                else
                    call add(ignore, "\"!" . ig . "\"")
                    " call add(ignore, '!' . ig)
                endif
            endfor
        else
            for ig in split(a:ignore,',')
                call add(ignore, '-g')
                if a:0 > 0
                    call add(ignore, "'" . ig . "'")
                else
                    call add(ignore, "'!" . ig . "'")
                    " call add(ignore, '!' . ig)
                endif
            endfor

        endif
    elseif a:tool ==# 'ctrlsf'
        for ig in split(a:ignore,',')
            call add(ignore, '-g')
            if a:0 > 0
                call add(ignore, "\"" . ig . "\"")
            else
                call add(ignore, "\"!" . ig . "\"")
                " call add(ignore, '!' . ig)
            endif
        endfor
    endif
    return ignore
endf

" exconfig#apply {{{
function exconfig#apply()

    set noacd " no autochchdir
    " ===================================
    " pre-check
    " ===================================

    let project_name = vimentry#get('project_name')
    if project_name == ''
        call ex#error("Can't find vimentry setting 'project_name'.")
        return
    endif

    " NOTE: we use the dir path of .vimentry instead of getcwd().
    " getcwd
    let filename = expand('%')
    let cwd = ex#path#translate( fnamemodify( filename, ':p:h' ), 'unix' )

    let g:exvim_project_name = project_name
    let g:exvim_project_root = cwd
    let g:exvim_folder = './.exvim.'.project_name

    " set parent working directory
    silent exec 'cd ' . fnameescape(cwd)
    let g:exvim_project_name = project_name

    let s:old_titlestring=&titlestring
    set titlestring=%{g:exvim_project_name}:\ %t\ (%{expand(\"%:p:.:h\")}/)

    " create folder .exvim.xxx/ if not exists
    let path = g:exvim_folder
    if finddir(path) == ''
        silent call mkdir(path)
    endif

    " ===================================
    " general settings
    " ===================================

    " apply project_type settings
    if !vimentry#check('project_type', '')
        " TODO:
        " let project_types = split( vimentry#get('project_type'), ',' )
    endif

    " Editing
    let indent_stop=str2nr(vimentry#get('indent'))
    let &tabstop=indent_stop
    let &shiftwidth=indent_stop

    let expand_tab = vimentry#get('expand_tab')
    let &expandtab = (expand_tab == "true" ? 1 : 0)

    " set gsearch
    if vimentry#check('enable_gutentags', 'true')
        let g:gutentags_cache_dir = ''
        let g:gutentags_gtags_dbpath = g:exvim_folder
        let g:gutentags_ctags_tagfile = g:exvim_folder . '/tags'
        set cscopetag
    endif

    if vimentry#check('enable_gutentags_auto', 'true')
        augroup gutentags_detect
            autocmd!
            autocmd BufNewFile,BufReadPost *  call gutentags#setup_gutentags()
            autocmd VimEnter               *  if expand('<amatch>')==''|call gutentags#setup_gutentags()|endif
        augroup end
    else
        augroup gutentags_detect
            au!
        augroup END
    endif

    " ctrlp rg
    if vimentry#check('enable_ctrlp_rg', 'true')
        let file_pattern = ''
        let file_suffixs = vimentry#get('file_filter',[])
        if len(file_suffixs) > 0
            for suffix in file_suffixs
                let file_pattern .= '*.' . suffix . ','
            endfor
        endif

        if vimentry#check( 'folder_filter_mode',  'exclude' )
            let folders = vimentry#get('folder_filter',[])
            if len(folders) > 0
                for folder in folders
                    let file_pattern .= '*/' .folder . '/*,'
                endfor
            endif
            let g:ctrlp_user_command = 'rg %s --no-ignore --hidden --files -g "" '
                        \ . join(exconfig#Generate_ignore(file_pattern,'rg'))
            let ctrlsf_user_command = ' '
                        \ . join(exconfig#Generate_ignore(file_pattern,'ctrlsf'))
            if has_key(g:ctrlsf_extra_backend_args, 'rg')
                let g:ctrlsf_extra_backend_args['rg'] = ctrlsf_user_command
            endif
        else
            let g:ctrlp_user_command = 'rg %s --no-ignore --hidden --files -g "" '
                        \ . join(exconfig#Generate_ignore(file_pattern,'rg', 1))
            let ctrlsf_user_command = ' '
                        \ . join(exconfig#Generate_ignore(file_pattern,'ctrlsf', 1))
            if has_key(g:ctrlsf_extra_backend_args, 'rg')
                let g:ctrlsf_extra_backend_args['rg'] = ctrlsf_user_command
            endif
        endif
        let g:ctrlsf_default_root = 'cwd'
    else
        " custom ctrlp ignores
        " let file_pattern = '\.exe$\|\.so$\|\.dll$\|\.pyc$\|\.csb$\|\.png$\|\.pkm$\|\.plist$\|\.jar\|\.ccz\|\.ogg\|\.tmx'
        " let file_pattern = '\v(\.cpp|\.h|\.hh|\.cxx|\.lua|\.c)@<!$'
        " let file_pattern = '\v(\.lua)@<!$'
        let file_pattern = ''
        let file_suffixs = vimentry#get('file_filter',[])
        if len(file_suffixs) > 0
            for suffix in file_suffixs
                let file_pattern .= '.' . suffix . '|\'
            endfor
            let file_pattern = strpart(file_pattern,0,len(file_pattern)-2)
            let file_pattern = '\v(\' . file_pattern . ')@<!$'
        endif

        let dir_pattern = '\.git$\|\.hg$\|\.svn$'
        if vimentry#check( 'folder_filter_mode',  'exclude' )
            let folders = vimentry#get('folder_filter',[])
            if len(folders) > 0
                for folder in folders
                    let dir_pattern .= folder . '|'
                endfor
                let dir_pattern = strpart( dir_pattern, 0, len(dir_pattern) - 1)

                let dir_pattern = '\v[\/](' . dir_pattern . ')$'
            endif
        else
            " let dir_pattern = ''
            " let folders = vimentry#get('folder_filter',[])
            " if len(folders) > 0
                " for folder in folders
                    " let dir_pattern .= folder . '|'
                " endfor
                " let dir_pattern = strpart( dir_pattern, 0, len(dir_pattern) - 1)

                " let dir_pattern = '\v(' . dir_pattern . ')@<!$'
            " endif

        endif

        let g:ctrlp_custom_ignore = {
                    \ 'dir': dir_pattern,
                    \ 'file': file_pattern,
                    \ }
        if exists("g:ack_default_options")
            let g:ack_default_options .= " --files-from=" . g:exvim_folder . "/files "
        endif
        if exists("g:ackprg")
            let g:ackprg .= " --files-from=" . g:exvim_folder . "/files "
        endif
    endif

    " ===================================
    " layout windows
    " ===================================

    " open project window
    if vimentry#check('enable_project_browser', 'true')
        let project_browser = vimentry#get( 'project_browser' )
        let g:ex_project_file = g:exvim_folder . "/files.exproject"

        if project_browser == 'nerdtree'
            if exists ( ':EXProjectClose' )
                exec 'EXProjectClose'
            endif

            " Example: let g:NERDTreeIgnore=['.git$[[dir]]', '.o$[[file]]']
            let g:NERDTreeIgnore = [] " clear ignore list
            let file_ignore_pattern = vimentry#get('file_ignore_pattern')
            if type(file_ignore_pattern) == type([])
                for pattern in file_ignore_pattern
                    silent call add ( g:NERDTreeIgnore, pattern.'[[file]]' )
                endfor
            endif

            if vimentry#check( 'folder_filter_mode',  'exclude' )
                let folder_filter = vimentry#get('folder_filter')
                if type(folder_filter) == type([])
                    for pattern in folder_filter
                        silent call add ( g:NERDTreeIgnore, pattern.'[[dir]]' )
                    endfor
                endif
            endif

            " bind key mapping
            if maparg('<leader>fc','n') != ""
                nunmap <leader>fc
            endif
            nnoremap <unique> <leader>fc :NERDTreeFind<CR>

            if has('gui_running') "  the <alt> key is only available in gui mode.
                if has ('mac')
                    if maparg('Ø','n') != ""
                        nunmap Ø
                    endif
                    nnoremap <unique> Ø :NERDTreeFind<CR>:redraw<CR>/
                else
                    if maparg('<M-O>','n') != ""
                        nunmap <M-O>
                    endif
                    nnoremap <unique> <M-O> :NERDTreeFind<CR>:redraw<CR>/
                endif
            endif

            " open nerdtree window
            doautocmd BufLeave
            doautocmd WinLeave
            silent exec 'NERDTree'

            " back to edit window
            doautocmd BufLeave
            doautocmd WinLeave
            call ex#window#goto_edit_window()
        endif
    endif

    " open init file
    if vimentry#check('enable_init_file', 'true')
        " open file window
        func MyHandler(timer)
            let init_open_file = vimentry#get( 'init_open_file' )
            exec 'silent edit ' . fnameescape(init_open_file)
        endfunc
        let timer = timer_start(100, 'MyHandler',
                    \ {'repeat': 1})

        " let init_open_file = vimentry#get( 'init_open_file' )
        " " open file window
        " doautocmd BufLeave
        " doautocmd WinLeave
        " exec 'silent edit ' . fnameescape(init_open_file)
        " " exec 'silent split ' . fnameescape(init_open_file)
        " " trigger filetypedetect (syntax highlight)
        " exec 'doau filetypedetect BufRead ' . fnameescape(init_open_file)
    endif

    " run customized scripts
    if exists('*g:exvim_post_init')
        call g:exvim_post_init()
    endif
endfunction
