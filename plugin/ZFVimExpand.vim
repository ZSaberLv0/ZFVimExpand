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
command! -range -nargs=* ZFExpand :<line1>,<line2>call ZF_Expand(<f-args>)

" ============================================================
let s:new_line = "ZFVimExpandnewLine"

" data:
" {
"   'template' : 'text',
"   'pattern' : [
"     {
"       'pos' : ['pos in template'],
"       'list' : ['1', '2', ...],
"     },
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
        if matchstr(pattern, g:ZFVimExpand_repeatToken) == pattern
            if empty(patternList)
                return {'template' : template, 'pattern' : patternList}
            endif

            let matchPos = match(template, tagPattern)
            let template = strpart(template, 0, matchPos) . strpart(template, matchPos + len(match))
            let patternList[-1]['pos'] += [matchPos]
            continue
        endif

        try
            let itemList = s:parseItem(pattern)
        endtry
        if empty(itemList)
            continue
        endif
        let matchPos = match(template, tagPattern)
        let template = strpart(template, 0, matchPos) . strpart(template, matchPos + len(match))
        let patternList += [{'pos' : [matchPos], 'list' : itemList}]
    endwhile
    return {'template' : template, 'pattern' : patternList}
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

function! s:processReplace(template, posList, posOffset, replace)
    if len(a:posList) == 1
        let pos = a:posList[0] + a:posOffset
        return strpart(a:template, 0, pos) . a:replace . strpart(a:template, pos)
    else
        let ret = strpart(a:template, 0, a:posList[0] + a:posOffset) . a:replace
        for i in range(1, len(a:posList)-1)
            let ret .= strpart(a:template, a:posList[i-1] + a:posOffset, a:posList[i] - a:posList[i-1])
            let ret .= a:replace
        endfor
        let ret .= strpart(a:template, a:posList[-1] + a:posOffset)
        return ret
    endif
endfunction

function! s:process(template, patternList, patternIndex, posOffset)
    let ret = ''
    let pattern = a:patternList[a:patternIndex]
    if a:patternIndex + 1 < len(a:patternList)
        for list in pattern['list']
            let templateNew = s:processReplace(a:template, pattern['pos'], a:posOffset, list)
            let ret .= s:process(templateNew, a:patternList, a:patternIndex + 1, a:posOffset + len(list) * len(pattern['pos']))
        endfor
    else
        for list in pattern['list']
            let templateNew = s:processReplace(a:template, pattern['pos'], a:posOffset, list)
            let ret .= templateNew
            let ret .= "\n"
        endfor
    endif
    return ret
endfunction

function! ZF_Expand(...) range
    let tagL = get(a:, 1, g:ZFVimExpand_tagL)
    let tagR = get(a:, 2, g:ZFVimExpand_tagR)

    let content = join(getline(a:firstline, a:lastline), s:new_line)
    let data = s:parse(content, tagL, tagR)
    if empty(data['pattern'])
        echo 'unable to parse'
        return
    endif

    let expanded = s:process(data['template'], data['pattern'], 0, 0)
    let expanded = substitute(expanded, "\n", s:new_line, 'g')
    let lines = split(expanded, s:new_line)

    execute 'silent! ' . a:firstline . ',' . a:lastline . 'd'
    call append(a:firstline - 1, lines)
    if g:ZFVimExpand_reindent
        execute 'silent! normal =' . len(lines) . 'k'
    endif
endfunction

