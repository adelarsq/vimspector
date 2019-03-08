" vimspector - A multi-language debugging system for Vim
" Copyright 2018 Ben Jackson
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"   http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.


" Boilerplate {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

function! s:_OnServerData( channel, data ) abort
  py3 << EOF
_vimspector_session.OnChannelData( vim.eval( 'a:data' ) )
EOF
endfunction

function! s:_OnClose( channel ) abort
  echom "Channel closed"
  unlet s:ch
  py3 _vimspector_session.OnServerExit()
endfunction

function! s:_Send( msg ) abort
  call ch_sendraw( s:ch, a:msg )
  return 1
endfunction

function! vimspector#internal#channel#Timeout( id ) abort
  py3 << EOF
_vimspector_session.OnRequestTimeout( vim.eval( 'a:id' ) )
EOF
endfunction

function! vimspector#internal#channel#StartDebugSession( config ) abort

  if exists( 's:ch' )
    echo "Channel is already running"
    return v:none
  endif

  let l:addr = 'localhost:' . a:config[ 'port' ]

  let s:ch = ch_open( l:addr,
        \             {
        \                 'mode': 'raw',
        \                 'callback': funcref( 's:_OnServerData' ),
        \                 'close_cb': funcref( 's:_OnClose' ),
        \             }
        \           )

  if ch_status( s:ch ) != 'open'
    echom 'Unable to connect to debug adapter'
    return v:none
  endif

  return funcref( 's:_Send' )
endfunction

function! vimspector#internal#channel#StopDebugSession() abort
  if !exists( 's:ch' )
    echom "No closing channel, it wasn't  started"
    py3 _vimspector_session.OnServerExit()
    return
  endif

  if ch_status( s:ch ) == 'open'
    echom "Closing channel"
    call ch_close( s:ch )
    " the channel callback is not called! :help ch_close
    call s:_OnClose( s:ch )
  else
    echom "Chennel isn't open. Server is ended. Waiting for callback"
  endif
endfunction

function! vimspector#internal#channel#Reset() abort
  if exists( 's:ch' )
    call vimspector#internal#channel#StopDebugSession()
  endif
endfunction

function! vimspector#internal#channel#ForceRead() abort
  if exists( 's:ch' )
    let data = ch_readraw( s:ch, { 'timeout': 1000 } )
    if data != ''
      call s:_OnServerData( s:ch, data )
    endif
  endif
endfunction

" Boilerplate {{{
let &cpo=s:save_cpo
unlet s:save_cpo
" }}}

