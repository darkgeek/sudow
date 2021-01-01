" sudow is a plugin to write files by using 'sudo' or 'doas', with the help of named pipe
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
        let baseDir = expand("$TMPDIR")
    elseif isdirectory('/tmp')
        let baseDir = '/tmp'
    elseif isdirectory(expand('$HOME/.cache'))
        let baseDir = expand('$HOME/.cache')
    elseif isdirectory(expand('$HOME'))
        let baseDir = expand('$HOME')
    else
        return ""
    endif

    let fileName = 'sudow-' . expand('$USER') . '-' . localtime()

    if baseDir =~ '^.*/$'
        return baseDir . fileName
    endif
    return baseDir . '/' . fileName
endfunction

function! sudow#createNamedPipe()
    if g:sudowNamedPipeFilePath == ""
        echoerr 'illegal named pipe file path'
        return
    endif

    call system('mkfifo -m 600 ' . g:sudowNamedPipeFilePath)

    if !filereadable(g:sudowNamedPipeFilePath)
        throw 'pipe-create-error'
    endif
endfunction

function! sudow#dispatch() 
    try
        call sudow#createNamedPipe()
    catch /pipe\-create\-error/
        echoerr 'Create named pipe failed, so aborted'
        return
    endtry

    try
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
        call execute(':terminal ' . g:sudoCommand . ' tee % > /dev/null < ' . g:sudowNamedPipeFilePath . ' ; ' . 'rm -f ' . g:sudowNamedPipeFilePath)
    catch
        echoerr 'sudow job failed for reason: ' .. v:exception
    endtry
endfunction

let g:sudowNamedPipeFilePath = sudow#generateNamedPipeFilePath()
command! Sudow call sudow#dispatch()
