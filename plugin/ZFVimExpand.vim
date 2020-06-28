
" ============================================================
" config
if !exists('g:ZFVimExpand_tagL')
    let g:ZFVimExpand_tagL='{'
endif
if !exists('g:ZFVimExpand_tagR')
    let g:ZFVimExpand_tagR='}'
endif
if !exists('g:ZFVimExpand_textSplitToken')
    let g:ZFVimExpand_textSplitToken=','
endif
if !exists('g:ZFVimExpand_rangeSplitToken')
    let g:ZFVimExpand_rangeSplitToken='..'
endif
if !exists('g:ZFVimExpand_repeatToken')
    let g:ZFVimExpand_repeatToken='@@'
endif
if !exists('g:ZFVimExpand_reindent')
    let g:ZFVimExpand_reindent=0
endif
if !exists('g:ZFVimExpand_customItemParser')
    let g:ZFVimExpand_customItemParser=''
endif

" ============================================================
command! -range -nargs=* ZFExpand :<line1>,<line2>call ZF_Expand(0, <f-args>)
command! -range -nargs=* ZFExpandReversely :<line1>,<line2>call ZF_Expand(1, <f-args>)

" ============================================================
" data:
" {
"   'templateList' : [
"     'aaa ZFVE_1_EVFZ bbb',
"     'ZFVE_2_EVFZ ZFVE_2_EVFZ',
"     'ZFVE_3r2_EVFZ', // index 4 ref to 2
"   ],
"   'patternOrigList' : [
"     '1..3',
"     'Fn:"FuncName":Fn',
"     'Fn:let ret = p[2][i]:Fn',
"     ...
"   ],
"   'patternList' : [
"     ['1', '2', '3'],
"     function(params), // for {Fn:"FuncName":Fn}
"     'let ret = p[2][i]', // for {Fn:let ret = p[2][i]:Fn}
"     ...
"   ],
"   'errorHint' : '',
" }
function! s:parse(content, tagL, tagR)
    let errorRet = {
                \   'templateList' : [],
                \   'patternOrigList' : [],
                \   'patternList' : [],
                \   'errorHint' : '',
                \ }
    let templateList = a:content
    let patternOrigList = []
    let patternList = []
    let patternIndexRefList = []
    let tagPattern = '\V' . a:tagL . '\.\{-1,}' . a:tagR
    for iTemplate in range(len(a:content))
        let template = templateList[iTemplate]
        while 1
            let match = matchstr(template, tagPattern)
            if empty(match)
                break
            endif
            let pattern = strpart(match, len(a:tagL), len(match) - len(a:tagL) - len(a:tagR))
            if matchstr(pattern, '\V\^\.\*' . g:ZFVimExpand_repeatToken . '\[0-9]\*\$') == pattern
                let patternIndexRef = matchstr(pattern, '[0-9]*$')
                if len(patternIndexRef) == 0
                    let patternIndexRef = len(patternList) - 1
                endif
                call add(patternIndexRefList, patternIndexRef)

                let patternTmp = substitute(pattern, '\V' . g:ZFVimExpand_repeatToken . '\[0-9]\*\$', '', '')
                if empty(patternTmp)
                    let matchPos = match(template, tagPattern)
                    let template = strpart(template, 0, matchPos) . 'ZFVE_' . patternIndexRef . '_EVFZ' . strpart(template, matchPos + len(match))
                    let templateList[iTemplate] = template
                else
                    try
                        let itemList = s:parseItem(patternTmp)
                    endtry
                    if empty(itemList)
                        break
                    endif
                    let matchPos = match(template, tagPattern)
                    let template = strpart(template, 0, matchPos) . 'ZFVE_' . len(patternList) . 'r' . patternIndexRef . '_EVFZ' . strpart(template, matchPos + len(match))
                    let templateList[iTemplate] = template
                    call add(patternOrigList, pattern)
                    call add(patternList, itemList)
                endif
                continue
            endif

            try
                let itemList = s:parseItem(pattern)
            endtry
            if empty(itemList)
                break
            endif
            let matchPos = match(template, tagPattern)
            let template = strpart(template, 0, matchPos) . 'ZFVE_' . len(patternList) . '_EVFZ' . strpart(template, matchPos + len(match))
            let templateList[iTemplate] = template
            call add(patternOrigList, pattern)
            call add(patternList, itemList)
        endwhile
    endfor
    if empty(patternList)
        let errorRet['errorHint'] = 'no valid pattern found'
        return errorRet
    else
        for patternIndexRef in patternIndexRefList
            if patternIndexRef < 0 || patternIndexRef >= len(patternList)
                let errorRet['errorHint'] = 'invalid ref index: ' . patternIndexRef
                return errorRet
            endif
        endfor
    endif
    return {
                \   'templateList' : templateList,
                \   'patternOrigList' : patternOrigList,
                \   'patternList' : patternList,
                \   'errorHint' : '',
                \ }
endfunction

function! s:parseItem(pattern)
    " custom rule
    if exists('g:ZFVimExpand_customItemParser') && !empty(g:ZFVimExpand_customItemParser)
        execute 'let split = ' . g:ZFVimExpand_customItemParser . "('" . a:pattern . "')"
        if !empty(split)
            return split
        endif
    endif

    " Fn:xxx:Fn
    if match(a:pattern, '^Fn:.*:Fn$') >= 0
        let pattern = strpart(a:pattern, len('Fn:'), len(a:pattern) - len('Fn:') - len(':Fn'))
        if match(pattern, '^[ \t]*"[ \t]*\([^ \t]\+\)[ \t]*"[ \t]*$') >= 0 " ^[ \t]*"[ \t]*([^ \t]+)[ \t]*"[ \t]*$
            let pattern = substitute(pattern, '^[ \t]*"[ \t]*\([^ \t]\+\)[ \t]*"[ \t]*$', '\1', '')
            if exists('*' . pattern)
                return function(pattern)
            else
                return [a:pattern]
            endif
        else
            return pattern
        endif
    endif

    " 1..3 or \xAB12..\xAB21 or a..d
    let split = split(a:pattern, '\V' . g:ZFVimExpand_rangeSplitToken)
    if len(split) == 2
        if match(split[0], '^[0-9]\+$') >= 0 && match(split[1], '^[0-9]\+$') >= 0
            " 1..3
            let l = str2nr(split[0])
            let r = str2nr(split[1])
            let ret = []
            if l <= r
                while l <= r
                    call add(ret, l)
                    let l += 1
                endwhile
            else
                while l >= r
                    call add(ret, l)
                    let l -= 1
                endwhile
            endif
            return ret
        elseif match(split[0], '^\\[xu][0-9a-f]\+$') >= 0 && match(split[1], '^\\[xu][0-9a-f]\+$') >= 0
            " \xAB12..\xAB21
            let l = str2nr(strpart(split[0], 2), 16)
            let r = str2nr(strpart(split[1], 2), 16)
        elseif match(split[0], '\C^.$') >= 0 && match(split[1], '\C^.$') >= 0
            " a..d
            let l = char2nr(split[0])
            let r = char2nr(split[1])
        endif
        if exists('l')
            let ret = []
            if l <= r
                while l <= r
                    call add(ret, nr2char(l))
                    let l += 1
                endwhile
            else
                while l >= r
                    call add(ret, nr2char(l))
                    let l -= 1
                endwhile
            endif
            return ret
        endif
    endif

    " a,b,c
    return split(a:pattern, '\V' . g:ZFVimExpand_textSplitToken)
endfunction

let s:nextItem_END = []
function! s:process(insertTo, reverse, templateList, patternOrigList, patternList, patternIndex)
    let ret = 0

    if match(a:patternOrigList[a:patternIndex], '\V' . g:ZFVimExpand_repeatToken . '\[0-9]\*\$') >= 0
        if (a:reverse && a:patternIndex > 0) || (!a:reverse && a:patternIndex + 1 < len(a:patternList))
            return s:process(a:insertTo, a:reverse, a:templateList, a:patternOrigList, a:patternList, a:reverse ? (a:patternIndex - 1) : (a:patternIndex + 1))
        else
            for template in a:templateList
                call append(a:insertTo + ret, template)
                let ret += 1
            endfor
            return ret
        endif
    endif

    let itemList = a:patternList[a:patternIndex]
    if type(itemList) == type([])
        let Fn_nextItem = function('s:process_nextItem_list')
    elseif type(itemList) == type(function('function'))
        let Fn_nextItem = function('s:process_nextItem_function')
    elseif type(itemList) == type('function')
        let Fn_nextItem = function('s:process_nextItem_command')
    else
        return []
    endif
    if (a:reverse && a:patternIndex > 0) || (!a:reverse && a:patternIndex + 1 < len(a:patternList))
        let i = -1
        while 1
            let i += 1
            let item = Fn_nextItem(a:reverse, a:patternOrigList, a:patternList, a:patternIndex, i)
            if type(item) == type(s:nextItem_END)
                break
            endif
            let templateNew = []
            for templateTmp in a:templateList
                call add(templateNew, s:processItem(a:reverse, a:patternOrigList, a:patternList, a:patternIndex, i, templateTmp, item))
            endfor
            let ret += s:process(a:insertTo + ret, a:reverse, templateNew, a:patternOrigList, a:patternList, a:reverse ? (a:patternIndex - 1) : (a:patternIndex + 1))
        endwhile
    else
        let i = -1
        while 1
            let i += 1
            let item = Fn_nextItem(a:reverse, a:patternOrigList, a:patternList, a:patternIndex, i)
            if type(item) == type(s:nextItem_END)
                break
            endif
            for template in a:templateList
                call append(a:insertTo + ret, s:processItem(a:reverse, a:patternOrigList, a:patternList, a:patternIndex, i, template, item))
                let ret += 1
            endfor
        endwhile
    endif
    return ret
endfunction
function! s:processItem(reverse, patternOrigList, patternList, patternIndex, i, template, item)
    let template = substitute(a:template, 'ZFVE_' . a:patternIndex . '_EVFZ', '\=a:item', 'g')
    while 1
        let pattern = matchstr(template, 'ZFVE_[0-9]\+r' . a:patternIndex . '_EVFZ')
        if empty(pattern)
            break
        endif
        " ZFVE_([0-9]+)r
        let index = substitute(pattern, 'ZFVE_\([0-9]\+\)r' . a:patternIndex . '_EVFZ', '\1', '')
        if index < 0 || index >= len(a:patternList)
            break
        endif

        let itemList = a:patternList[index]
        if type(itemList) == type([])
            let Fn_nextItem = function('s:process_nextItem_list')
        elseif type(itemList) == type(function('function'))
            let Fn_nextItem = function('s:process_nextItem_function')
        elseif type(itemList) == type('function')
            let Fn_nextItem = function('s:process_nextItem_command')
        else
            break
        endif

        let item = Fn_nextItem(a:reverse, a:patternOrigList, a:patternList, index, a:i)
        if type(item) == type(s:nextItem_END)
            unlet item
            let item = ''
        endif
        let template = substitute(template, 'ZFVE_[0-9]\+r' . a:patternIndex . '_EVFZ', item, '')
    endwhile
    return template
endfunction
function! s:process_nextItem_list(reverse, patternOrigList, patternList, patternIndex, i)
    if a:i >= len(a:patternList[a:patternIndex])
        return s:nextItem_END
    else
        return a:patternList[a:patternIndex][a:i]
    endif
endfunction
function! s:process_nextItem_function(reverse, patternOrigList, patternList, patternIndex, i)
    try
        return a:patternList[a:patternIndex][a:i]({
                    \   'reverse' : a:reverse,
                    \   'po' : a:patternOrigList,
                    \   'p' : a:patternList,
                    \   'pi' : a:patternIndex,
                    \   'i' : a:i,
                    \   'END' : s:nextItem_END,
                    \ })
    catch
        echo '[ZFExpand] failed to execute function'
        echo v:exception
    endtry
    return {}
endfunction
function! s:process_nextItem_command(reverse, patternOrigList, patternList, patternIndex, i)
    let _cmd = a:patternList[a:patternIndex]
    let reverse = a:reverse
    let po = a:patternOrigList
    let p = a:patternList
    let pi = a:patternIndex
    let i = a:i
    let END = s:nextItem_END
    try
        execute _cmd
    catch
        echo '[ZFExpand] failed to execute: ' . _cmd
        echo v:exception
    endtry
    if exists('ret')
        return ret
    else
        return {}
    endif
endfunction

function! ZF_Expand(reverse, ...) range
    let tagL = get(a:, 1, g:ZFVimExpand_tagL)
    let tagR = get(a:, 2, g:ZFVimExpand_tagR)

    let content = getline(a:firstline, a:lastline)
    let data = s:parse(content, tagL, tagR)
    if empty(data['patternList'])
        if empty(data['errorHint'])
            echo '[ZFExpand] unable to parse pattern'
        else
            echo '[ZFExpand] unable to parse pattern: ' . data['errorHint']
        endif
        return
    endif

    execute 'silent! ' . a:firstline . ',' . a:lastline . 'd'
    let n = s:process(a:firstline - 1, a:reverse, data['templateList'], data['patternOrigList'], data['patternList'], a:reverse ? (len(data['patternList']) - 1) : 0)
    if g:ZFVimExpand_reindent
        execute 'silent! normal =' . n . 'k'
    endif
endfunction

