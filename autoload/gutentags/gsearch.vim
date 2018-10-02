" Gsearch module for Gutentags

" Global Options {{{

let g:gutentags_gsearch_executable = get(g:, 'gutentags_gsearch_executable', 'mkid')
let g:gutentags_gsearch_tagfile = get(g:, 'gutentags_gsearch_tagfile', 'ID')
let g:gutentags_gsearch_auto_set_tags = get(g:, 'gutentags_gsearch_auto_set_tags', 1)

let g:gutentags_gsearch_extra_args = get(g:, 'gutentags_gsearch_extra_args', [])

" }}}

" Gutentags Module Interface {{{

let s:did_check_exe = 0
let s:runner_exe = gutentags#get_plat_file('update_gsearch')
let s:unix_redir = (&shellredir =~# '%s') ? &shellredir : &shellredir . ' %s'

function! gutentags#gsearch#init(project_root) abort
    " Figure out the path to the ID file.
    let l:tagfile = getbufvar("", 'gutentags_gsearch_tagfile',
                \getbufvar("", 'gutentags_tagfile',
                \g:gutentags_gsearch_tagfile))
    let b:gutentags_files['gsearch'] = gutentags#get_cachefile(
                \a:project_root, l:tagfile)

    " Set the ID file for Vim to use.
    if g:gutentags_gsearch_auto_set_tags
        call exgsearch#set_id_file(fnameescape(b:gutentags_files['gsearch']))
    endif
    " Check if the gsearch executable exists.
    if s:did_check_exe == 0
        if g:gutentags_enabled && executable(expand(g:gutentags_gsearch_executable, 1)) == 0
            let g:gutentags_enabled = 0
            echoerr "Executable '".g:gutentags_gsearch_executable."' can't be found. "
                        \."Gutentags will be disabled. You can re-enable it by "
                        \."setting g:gutentags_enabled back to 1."
        endif
        let s:did_check_exe = 1
    endif
endfunction

function! gutentags#gsearch#generate(proj_dir, tags_file, gen_opts) abort
    let l:tags_file_exists = filereadable(a:tags_file)
    let l:tags_file_relative = fnamemodify(a:tags_file, ':.')
    let l:tags_file_is_local = len(l:tags_file_relative) < len(a:tags_file)

    " the tags file goes in a cache directory, so we need to specify
    " all the paths absolutely for `gsearch` to do its job correctly.
    let l:actual_proj_dir = a:proj_dir
    let l:actual_tags_file = a:tags_file

    " Build the command line.
    let l:cmd = [s:runner_exe]
    let l:cmd += ['-t', '"' . l:actual_tags_file . '"']
    let l:cmd += ['-p', '"' . l:actual_proj_dir . '"']
    let l:file_list_cmd = gutentags#get_project_file_list_cmd(l:actual_proj_dir,'gsearch')
    if !empty(l:file_list_cmd)
        if match(l:file_list_cmd, '///') > 0
            let l:suffopts = split(l:file_list_cmd, '///')
            let l:suffoptstr = l:suffopts[1]
            let l:file_list_cmd = l:suffopts[0]
            if l:suffoptstr == 'absolute'
                let l:cmd += ['-A']
            endif
        endif
        let l:cmd += ['-L', '"' . l:file_list_cmd. '"']
    endif
    let l:cmd += ['-m', '"' . gutentags#get_res_file('id-lang.map') . '"']
    if !empty(g:gutentags_gsearch_extra_args)
        let l:cmd += ['-O', shellescape(join(g:gutentags_gsearch_extra_args))]
    endif
    if g:gutentags_pause_after_update
        let l:cmd += ['-c']
    endif
    if g:gutentags_trace
        let l:cmd += ['-l', '"' . l:actual_tags_file . '.log"']
    endif
    let l:cmd = gutentags#make_args(l:cmd)

    call gutentags#trace("Running: " . string(l:cmd))
    call gutentags#trace("In:      " . getcwd())
    if !g:gutentags_fake
		let l:job_opts = gutentags#build_default_job_options('gsearch')
        let l:job = gutentags#start_job(l:cmd, l:job_opts)
        call gutentags#add_job('gsearch', a:tags_file, l:job)
    else
        call gutentags#trace("(fake... not actually running)")
    endif
endfunction

function! gutentags#gsearch#on_job_exit(job, exit_val) abort
    call gutentags#remove_job_by_data('gsearch', a:job)

    if a:exit_val != 0
        call gutentags#warning("gutentags: gsearch job failed, returned: ".
                    \string(a:exit_val))
    endif
endfunction

" }}}

" Utilities {{{
" }}}
