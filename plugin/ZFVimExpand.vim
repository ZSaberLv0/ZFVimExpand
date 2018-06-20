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
if !exists('g:ZFVimExpand_numSplitToken')
    let g:ZFVimExpand_numSplitToken='\.\.'
endif
if !exists('g:ZFVimExpand_repeatToken')
    let g:ZFVimExpand_repeatToken='\.\.'
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
let s:new_line = "ZFVE__EVFZ"

" data:
" {
"   'template' : 'aaa ZFVE_1_EVFZ bbb ZFVE_2_EVFZ ccc',
"   'patternList' : [
"     ['t1', 't2', ...],
"     ['d1', 'd2', ...],
"     ...
"   ],
" }
function! s:parse(content, tagL, tagR)
    let patternList = []
    let template = a:content
    let tagPattern = a:tagL . '[^]\{-1,}' . a:tagR
    while 1
        let match = matchstr(template, tagPattern)
        if empty(match)
            break
        endif
        let pattern=strpart(match, len(a:tagL), len(match) - len(a:tagL) - len(a:tagR))
        if matchstr(pattern, g:ZFVimExpand_repeatToken . '[0-9]*') == pattern
            let patternIndex = matchstr(pattern, '[0-9]*$')
            if len(patternIndex) == 0
                let patternIndex = len(patternList) - 1
            endif
            if empty(patternList) || patternIndex >= len(patternList)
                return {'template' : template, 'patternList' : patternList}
            endif

            let matchPos = match(template, tagPattern)
            let template = strpart(template, 0, matchPos) . 'ZFVE_' . patternIndex . '_EVFZ' . strpart(template, matchPos + len(match))
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
        call add(patternList, itemList)
    endwhile
    return {'template' : template, 'patternList' : patternList}
endfunction

function! s:parseItem(pattern)
    " custom rule
    if exists('g:ZFVimExpand_customItemParser') && !empty(g:ZFVimExpand_customItemParser)
        execute 'let split = ' . g:ZFVimExpand_customItemParser . "('" . a:pattern . "')"
        if !empty(split)
            return split
        endif
    endif

    " 1..3
    let split = split(a:pattern, g:ZFVimExpand_numSplitToken)
    if len(split) == 2
        return range(split[0], split[1])
    endif

    " a,b,c
    return split(a:pattern, g:ZFVimExpand_textSplitToken)
endfunction

function! s:process(reverse, template, patternList, patternIndex)
    let ret = ''
    let itemList = a:patternList[a:patternIndex]
    if (a:reverse && a:patternIndex > 0) || (!a:reverse && a:patternIndex + 1 < len(a:patternList))
        for item in itemList
            let templateNew = substitute(a:template, 'ZFVE_' . a:patternIndex . '_EVFZ', item, 'g')
            let ret .= s:process(a:reverse, templateNew, a:patternList, a:reverse ? (a:patternIndex - 1) : (a:patternIndex + 1))
        endfor
    else
        for item in itemList
            let ret .= substitute(a:template, 'ZFVE_' . a:patternIndex . '_EVFZ', item, 'g')
            let ret .= "\n"
        endfor
    endif
    return ret
endfunction

function! ZF_Expand(reverse, ...) range
    let tagL = get(a:, 1, g:ZFVimExpand_tagL)
    let tagR = get(a:, 2, g:ZFVimExpand_tagR)

    let content = join(getline(a:firstline, a:lastline), s:new_line)
    let data = s:parse(content, tagL, tagR)
    if empty(data['patternList'])
        echo 'unable to parse'
        return
    endif

    let expanded = s:process(a:reverse, data['template'], data['patternList'], a:reverse ? (len(data['patternList']) - 1) : 0)
    let expanded = substitute(expanded, "\n", s:new_line, 'g')
    let lines = split(expanded, s:new_line)

    execute 'silent! ' . a:firstline . ',' . a:lastline . 'd'
    call append(a:firstline - 1, lines)
    if g:ZFVimExpand_reindent
        execute 'silent! normal =' . len(lines) . 'k'
    endif
endfunction

