" ZFVimExpand.vim - expand utility
" Author:  ZSaberLv0 <http://zsaber.com/>

let g:ZFVimExpand_loaded=1

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
    let g:ZFVimExpand_repeatToken='..'
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
"     'ZFVE_3_EVFZ ZFVE_2_EVFZ',
"   ],
"   'patternList' : [
"     ['t1', 't2', ...],
"     ['d1', 'd2', ...],
"     ...
"   ],
" }
function! s:parse(content, tagL, tagR)
    let patternList = []
    let templateList = a:content
    let tagPattern = '\V' . a:tagL . '\.\{-1,}' . a:tagR
    for iTemplate in range(len(a:content))
        let template = templateList[iTemplate]
        while 1
            let match = matchstr(template, tagPattern)
            if empty(match)
                break
            endif
            let pattern = strpart(match, len(a:tagL), len(match) - len(a:tagL) - len(a:tagR))
            if matchstr(pattern, '\V' . g:ZFVimExpand_repeatToken . '\[0-9]\*') == pattern
                let patternIndex = matchstr(pattern, '[0-9]*$')
                if len(patternIndex) == 0
                    let patternIndex = len(patternList) - 1
                endif
                if empty(patternList) || patternIndex >= len(patternList)
                    break
                endif

                let matchPos = match(template, tagPattern)
                let template = strpart(template, 0, matchPos) . 'ZFVE_' . patternIndex . '_EVFZ' . strpart(template, matchPos + len(match))
                let templateList[iTemplate] = template
                continue
            endif

            try
                let itemList = s:parseItem(pattern)
            endtry
            if empty(itemList)
                continue
            endif
            let matchPos = match(template, tagPattern)
            let template = strpart(template, 0, matchPos) . 'ZFVE_' . len(patternList) . '_EVFZ' . strpart(template, matchPos + len(match))
            let templateList[iTemplate] = template
            call add(patternList, itemList)
        endwhile
    endfor
    return {'templateList' : templateList, 'patternList' : patternList}
endfunction

function! s:parseItem(pattern)
    " custom rule
    if exists('g:ZFVimExpand_customItemParser') && !empty(g:ZFVimExpand_customItemParser)
        execute 'let split = ' . g:ZFVimExpand_customItemParser . "('" . a:pattern . "')"
        if !empty(split)
            return split
        endif
    endif

    " 1..3 or a..d or \xAB12..\xAB21
    let split = split(a:pattern, '\V' . g:ZFVimExpand_rangeSplitToken)
    if len(split) == 2
        if match(split[0], '^[0-9]\+$') >= 0 && match(split[1], '^[0-9]\+$') >= 0
            return range(split[0], split[1])
        elseif (match(split[0], '\C^[a-z]$') >= 0 && match(split[1], '\C^[a-z]$') >= 0)
                    \ || (match(split[0], '\C^[A-Z]$') >= 0 && match(split[1], '\C^[A-Z]$') >= 0)
            let ret = []
            for c in range(char2nr(split[0]), char2nr(split[1]))
                call add(ret, nr2char(c))
            endfor
            return ret
        elseif match(split[0], '^\\[xu][0-9a-f]\+$') >= 0 && match(split[1], '^\\[xu][0-9a-f]\+$') >= 0
            let ret = []
            for c in range(str2nr(strpart(split[0], 2), 16), str2nr(strpart(split[1], 2), 16))
                call add(ret, nr2char(c))
            endfor
            return ret
        endif
    endif

    " a,b,c
    return split(a:pattern, '\V' . g:ZFVimExpand_textSplitToken)
endfunction

function! s:process(reverse, templateList, patternList, patternIndex)
    let ret = []
    let itemList = a:patternList[a:patternIndex]
    for template in a:templateList
        if (a:reverse && a:patternIndex > 0) || (!a:reverse && a:patternIndex + 1 < len(a:patternList))
            for item in itemList
                let templateNew = []
                for templateTmp in a:templateList
                    call add(templateNew, substitute(templateTmp, 'ZFVE_' . a:patternIndex . '_EVFZ', '\=item', 'g'))
                endfor
                call extend(ret, s:process(a:reverse, templateNew, a:patternList, a:reverse ? (a:patternIndex - 1) : (a:patternIndex + 1)))
            endfor
        else
            for item in itemList
                call add(ret, substitute(template, 'ZFVE_' . a:patternIndex . '_EVFZ', '\=item', 'g'))
            endfor
        endif
    endfor
    return ret
endfunction

function! ZF_Expand(reverse, ...) range
    let tagL = get(a:, 1, g:ZFVimExpand_tagL)
    let tagR = get(a:, 2, g:ZFVimExpand_tagR)

    let content = getline(a:firstline, a:lastline)
    let data = s:parse(content, tagL, tagR)
    if empty(data['patternList'])
        echo 'unable to parse'
        return
    endif

    let expanded = s:process(a:reverse, data['templateList'], data['patternList'], a:reverse ? (len(data['patternList']) - 1) : 0)

    execute 'silent! ' . a:firstline . ',' . a:lastline . 'd'
    call append(a:firstline - 1, expanded)
    if g:ZFVimExpand_reindent
        execute 'silent! normal =' . len(expanded) . 'k'
    endif
endfunction

