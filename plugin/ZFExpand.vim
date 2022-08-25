
" ============================================================
" config
if !exists('g:ZFExpand_tagL')
    let g:ZFExpand_tagL='{'
endif
if !exists('g:ZFExpand_tagR')
    let g:ZFExpand_tagR='}'
endif
if !exists('g:ZFExpand_textSplitToken')
    let g:ZFExpand_textSplitToken=','
endif
if !exists('g:ZFExpand_rangeSplitToken')
    let g:ZFExpand_rangeSplitToken='..'
endif
if !exists('g:ZFExpand_repeatToken')
    let g:ZFExpand_repeatToken='@@'
endif
if !exists('g:ZFExpand_noPatternToken')
    let g:ZFExpand_noPatternToken=''
endif
if !exists('g:ZFExpand_reindent')
    let g:ZFExpand_reindent=0
endif
if !exists('g:ZFExpand_customItemParser')
    let g:ZFExpand_customItemParser=''
endif

" ============================================================
command! -range -nargs=* ZFExpand :<line1>,<line2>call ZFExpand(<f-args>)
command! -range -nargs=* ZFExpandReversely :<line1>,<line2>call ZFExpandReversely(<f-args>)

" ============================================================
" config:
" {
"   'templateList' : [
"     'aaa ZFVE_0_EVFZ bbb',
"     'ZFVE_1_EVFZ ZFVE_1_EVFZ',
"     'ZFVE_2r1_EVFZ', // index 2 ref to 1
"     ...
"   ],
"   'patternOrigList' : [
"     '1..3',
"     'Fn:"FuncName":Fn',
"     'Fn:let ret = p[1][i]:Fn',
"     ...
"   ],
"   'patternList' : [
"     ['1', '2', '3'],
"     function(params), // for {Fn:"FuncName":Fn}
"     'let ret = p[1][i]', // for {Fn:let ret = p[1][i]:Fn}
"     ...
"   ],
"   'refList' : [
"     -1, // no ref
"     -1,
"     1, // ref to index 1
"   ],
"
"   'errorHint' : '', // exist when error
" }
function! s:parse(content, tagL, tagR)
    let config = {
                \   'templateList' : a:content,
                \   'patternOrigList' : [],
                \   'patternList' : [],
                \   'refList' : [],
                \ }
    let patternIndexRefList = []
    let tagPattern = '\V' . a:tagL . '\.\{-1,}' . a:tagR
    for iTemplate in range(len(config['templateList']))
        let template = config['templateList'][iTemplate]
        while 1
            let match = matchstr(template, tagPattern)
            if empty(match)
                break
            endif
            let pattern = strpart(match, len(a:tagL), len(match) - len(a:tagL) - len(a:tagR))
            if matchstr(pattern, '\V\^\.\*' . g:ZFExpand_repeatToken . '\[0-9]\*\$') == pattern
                let patternIndexRef = matchstr(pattern, '[0-9]*$')
                if len(patternIndexRef) == 0
                    let patternIndexRef = len(config['patternList']) - 1
                else
                    let patternIndexRef = str2nr(patternIndexRef)
                endif
                call add(patternIndexRefList, patternIndexRef)

                let patternTmp = substitute(pattern, '\V' . g:ZFExpand_repeatToken . '\[0-9]\*\$', '', '')
                if empty(patternTmp)
                    let itemList = []
                else
                    try
                        let itemList = s:parseItem(patternTmp)
                    endtry
                    if empty(itemList)
                        break
                    endif
                endif
                let matchPos = match(template, tagPattern)
                let template = strpart(template, 0, matchPos) . 'ZFVE_' . len(config['patternList']) . 'r' . patternIndexRef . '_EVFZ' . strpart(template, matchPos + len(match))
                let config['templateList'][iTemplate] = template
                call add(config['patternOrigList'], pattern)
                call add(config['patternList'], itemList)
                call add(config['refList'], patternIndexRef)
            else
                try
                    let itemList = s:parseItem(pattern)
                endtry
                if empty(itemList)
                    break
                endif
                let matchPos = match(template, tagPattern)
                let template = strpart(template, 0, matchPos) . 'ZFVE_' . len(config['patternList']) . '_EVFZ' . strpart(template, matchPos + len(match))
                let config['templateList'][iTemplate] = template
                call add(config['patternOrigList'], pattern)
                call add(config['patternList'], itemList)
                call add(config['refList'], -1)
            endif
        endwhile
    endfor
    if empty(config['patternList'])
        let config['errorHint'] = 'no valid pattern found'
        return config
    else
        for patternIndexRef in patternIndexRefList
            if patternIndexRef < 0 || patternIndexRef >= len(config['patternList'])
                let config['errorHint'] = 'invalid ref index: ' . patternIndexRef
                return config
            endif
        endfor
    endif

    call s:parse_deRef(config)
    return config
endfunction

function! s:parse_deRef(config)
    for i in range(len(a:config['refList']))
        call s:parse_deRef_loop(a:config, i)
    endfor
endfunction
function! s:parse_deRef_loop(config, i)
    if a:config['refList'][a:i] < 0 || !empty(a:config['patternList'][a:i])
        return
    endif
    call s:parse_deRef_loop(a:config, a:config['refList'][a:i])
    let a:config['patternList'][a:i] = a:config['patternList'][a:config['refList'][a:i]]
endfunction

function! s:parseItem(pattern)
    " custom rule
    if exists('g:ZFExpand_customItemParser') && !empty(g:ZFExpand_customItemParser)
        execute 'let split = ' . g:ZFExpand_customItemParser . "('" . a:pattern . "')"
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
    let split = split(a:pattern, '\V' . g:ZFExpand_rangeSplitToken)
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
    return split(a:pattern, '\V' . g:ZFExpand_textSplitToken)
endfunction

" :h E706
let s:nextItem_END = '_ZFVE_E_'
function! s:process(result, reverse, templateList, config, patternIndex)
    if a:config['refList'][a:patternIndex] >= 0
        if (a:reverse && a:patternIndex > 0) || (!a:reverse && a:patternIndex + 1 < len(a:config['patternList']))
            return s:process(a:result, a:reverse, a:templateList, a:config, a:reverse ? (a:patternIndex - 1) : (a:patternIndex + 1))
        else
            call extend(a:result, a:templateList)
            return
        endif
    endif

    let Fn_nextItem = s:process_nextItemFn(a:config['patternList'][a:patternIndex])
    if empty(Fn_nextItem)
        return []
    endif
    if (a:reverse && a:patternIndex > 0) || (!a:reverse && a:patternIndex + 1 < len(a:config['patternList']))
        let i = -1
        while 1
            let i += 1
            let item = s:process_nextItem(Fn_nextItem, a:reverse, a:config, a:patternIndex, i)
            if item == s:nextItem_END
                break
            endif
            let templateListNew = []
            for template in a:templateList
                call add(templateListNew, s:processItem(a:reverse, template, a:config, a:patternIndex, i, item))
            endfor
            call s:process(a:result, a:reverse, templateListNew, a:config, a:reverse ? (a:patternIndex - 1) : (a:patternIndex + 1))
        endwhile
    else
        let i = -1
        while 1
            let i += 1
            let item = s:process_nextItem(Fn_nextItem, a:reverse, a:config, a:patternIndex, i)
            if item == s:nextItem_END
                break
            endif
            for template in a:templateList
                call add(a:result, s:processItem(a:reverse, template, a:config, a:patternIndex, i, item))
            endfor
        endwhile
    endif
    return
endfunction

function! s:processItem(reverse, template, config, patternIndex, i, item)
    " ZFVE_patternIndex(r[0-9]+)?_EVFZ
    let template = substitute(a:template, 'ZFVE_' . a:patternIndex . '\(r[0-9]\+\)\=_EVFZ', '\=a:item', 'g')

    let processed = {}
    let processed[a:patternIndex] = 1
    let iPattern = -1
    let iPatternEnd = len(a:config['patternList']) - 1
    while iPattern < iPatternEnd
        let iPattern += 1
        if get(processed, iPattern, 0)
            continue
        endif
        let hasRef = 0
        let patternIndexRef = iPattern
        while a:config['refList'][patternIndexRef] >= 0
            let patternIndexRef = a:config['refList'][patternIndexRef]
            if patternIndexRef == a:patternIndex
                let hasRef = 1
            endif
        endwhile
        if !hasRef || patternIndexRef == iPattern
            continue
        endif
        let processed[patternIndexRef] = 1

        " expand all pattern that referenced a:patternIndex
        let Fn_nextItem = s:process_nextItemFn(a:config['patternList'][iPattern])
        if empty(Fn_nextItem)
            continue
        endif
        let item = s:process_nextItem(Fn_nextItem, a:reverse, a:config, iPattern, a:i)
        if item == s:nextItem_END
            continue
        endif
        " ZFVE_iPattern(r[0-9]+)?_EVFZ
        let template = substitute(template, 'ZFVE_' . iPattern . '\(r[0-9]\+\)\=_EVFZ', '\=item', 'g')
    endwhile

    return template
endfunction

function! s:process_nextItem_list(reverse, config, patternIndex, i)
    if a:i >= len(a:config['patternList'][a:patternIndex])
        return s:nextItem_END
    else
        return a:config['patternList'][a:patternIndex][a:i]
    endif
endfunction
function! s:process_nextItem_function(reverse, config, patternIndex, i)
    try
        return a:config['patternList'][a:patternIndex][a:i]({
                    \   'reverse' : a:reverse,
                    \   'po' : a:config['patternOrigList'],
                    \   'p' : a:config['patternList'],
                    \   'r' : a:config['refList'],
                    \   'pi' : a:patternIndex,
                    \   'i' : a:i,
                    \   'END' : s:nextItem_END,
                    \ })
    catch
        echo '[ZFExpand] failed to execute function'
        echo v:exception
    endtry
    return s:nextItem_END
endfunction
function! s:process_nextItem_command(reverse, config, patternIndex, i)
    let _cmd = a:config['patternList'][a:patternIndex]
    let reverse = a:reverse
    let po = a:config['patternOrigList']
    let p = a:config['patternList']
    let r = a:config['refList']
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
        return s:nextItem_END
    endif
endfunction

function! s:process_nextItemFn(itemList)
    if type(a:itemList) == type([])
        return function('s:process_nextItem_list')
    elseif type(a:itemList) == type(function('function'))
        return function('s:process_nextItem_function')
    elseif type(a:itemList) == type('')
        return function('s:process_nextItem_command')
    else
        return ''
    endif
endfunction

function! s:process_nextItem(Fn_nextItem, reverse, config, patternIndex, i)
    let ret = a:Fn_nextItem(a:reverse, a:config, a:patternIndex, a:i)
    if type(ret) == type('')
        return ret
    else
        return string(ret)
    endif
endfunction

function! s:ZFExpand(first, last, reverse, tagL, tagR)
    let content = getline(a:first, a:last)
    let config = s:parse(content, a:tagL, a:tagR)
    if empty(config['patternList'])
        if empty(get(config, 'errorHint', ''))
            echo '[ZFExpand] unable to parse pattern'
        else
            echo '[ZFExpand] unable to parse pattern: ' . config['errorHint']
        endif
        return config
    endif

    let templateList = copy(config['templateList'])
    let result = []
    call s:process(result, a:reverse, templateList, config, a:reverse ? (len(config['patternList']) - 1) : 0)

    let iResult = -1
    let iResultEnd = len(result) - 1
    while iResult < iResultEnd
        let iResult += 1
        " ZFVE_[0-9]+(r[0-9]+)?_EVFZ
        let result[iResult] = substitute(result[iResult], 'ZFVE_[0-9]\+\(r[0-9]\+\)\=_EVFZ', g:ZFExpand_noPatternToken, 'g')
    endwhile

    execute 'silent! ' . a:first . ',' . a:last . 'd'
    call append(a:first - 1, result)
    if g:ZFExpand_reindent
        execute 'silent! normal =' . len(result) . 'k'
    endif

    return config
endfunction

function! ZFExpand(...) range
    return s:ZFExpand(a:firstline, a:lastline, 0, get(a:, 1, g:ZFExpand_tagL), get(a:, 2, g:ZFExpand_tagR))
endfunction
function! ZFExpandReversely(...) range
    return s:ZFExpand(a:firstline, a:lastline, 1, get(a:, 1, g:ZFExpand_tagL), get(a:, 2, g:ZFExpand_tagR))
endfunction

