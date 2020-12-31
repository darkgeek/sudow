" sudow is a plugin to write files by using 'sudo' or 'doas', with the help of 'tee'
" Maintainer:	Justin Yang <linuxjustin@gmail.com>
" Last Change:  2020-12-31
" Version: 0.0.1
" Repository: https://github.com/darkgeek/sudow

if !exists('g:sudoCommand')
    let g:sudoCommand = 'sudo'
end

function! sudow#getBufferContent()
    return join(getline(1, "$"), "\n")
endfunction

function! sudow#generateNamedPipeFilePath() 
    let baseDir = ""
    if exists("$TMPDIR")
        let baseDir = "$TMPDIR"
    elseif isdirectory('/tmp')
        let baseDir = '/tmp'
    elseif isdirectory('$HOME/.cache')
        let baseDir = '$HOME/.cache'
    elseif isdirectory('$HOME')
        let baseDir = '$HOME'
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

    if !filereadable(g:sudowNamedPipeFilePath)
        echoerr 'Create Named pipe failed: ' . createRes
    endif
endfunction

function! sudow#dispatch() 
    call sudow#createNamedPipe()

    " TODO: should have try-catch-finally style exception control
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
    call execute(':terminal ' . g:sudoCommand . ' tee % > /dev/null < ' . g:sudowNamedPipeFilePath . ' && ' . 'rm -f ' . g:sudowNamedPipeFilePath)
endfunction

let g:sudowNamedPipeFilePath = sudow#generateNamedPipeFilePath()
command Sudow call sudow#dispatch()
