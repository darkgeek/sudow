" sudow is a plugin to write files by using 'sudo' or 'doas', with the help of 'tee'
" Maintainer:	Justin Yang <linuxjustin@gmail.com>
" Last Change:  2020-12-31
" Version: 0.0.1
" Repository: https://github.com/darkgeek/sudow

if !exists('g:sudoCommand')
    let g:sudoCommand = 'sudo'
end

let g:sudowNamedPipeFilePath = sudow#generateNamedPipeFilePath()
command Sudow w :call sudow#dispatch()

function! sudow#dispatch() 
    sudow#createNamedPipe()

    let jobId = jobstart("tee " . g:sudowNamedPipeFilePath)
    if jobId == 0
        echoerr 'invalid arguments (or job table is full)'
    elseif jobId == -1
        echoerr 'invalid shell command'
    endif

    let content = sudow#getBufferContent()
    call chansend(jobId, content)
    call chanclose(jobId, 'stdin')

    " tty is required for sudo or doas, so :terminal is needed
    call execute(':terminal ' . g:sudoCommand . ' tee % > /dev/null < ' . g:sudowNamedPipeFilePath)
endfunction

function! sudow#getBufferContent()
    return join(getline(1, "$"), "\n")
endfunction

function! sudow#generateNamedPipeFilePath() 
    let baseDir = ""
    if exists("$TMPDIR")
        baseDir = expand('$TMPDIR')
    elseif isdirectory('/tmp')
        baseDir = expand('/tmp')
    elseif isdirectory(expand('$HOME/.cache'))
        baseDir = expand('$HOME/.cache')
    elseif isdirectory(expand('$HOME'))
        baseDir = expand('$HOME')
    else
        return ""
    endif

    let fileName = 'sudow' . localtime()
    return baseDir . '/' . fileName
endfunction

function! sudow#createNamedPipe()
    if g:sudowNamedPipeFilePath == ""
        echoerr 'illegal named pipe file path'
        return
    endif

    let createRes = system('mkfifo ' . g:sudowNamedPipeFilePath)

    if !isfname(g:sudowNamedPipeFilePath)
        echoerr 'Create Named pipe failed: ' . createRes
    endif
endfunction
