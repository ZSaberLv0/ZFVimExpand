# ZFVimExpand

expand utility

* before expand:

    ```
    void {add,remove}Item{0..2}(int item{..}) {
    }
    ```

* after expand: (by `:ZFExpandReversely`)

    ```
    void addItem0(int item0) {
    }
    void removeItem0(int item0) {
    }
    void addItem1(int item1) {
    }
    void removeItem1(int item1) {
    }
    void addItem2(int item2) {
    }
    void removeItem2(int item2) {
    }
    ```

inspired from [Olical/vim-expand](https://github.com/Olical/vim-expand), with these advantages:

* implemented in pure vim script, support Windows
* more configurable
* more pattern expand rule
* able to add your own rules

disadvantages:

* no shell env support (such as `$HOME`)


# How to use

1. use [Vundle](https://github.com/VundleVim/Vundle.vim) or any other plugin manager is recommended

    ```
    Plugin 'ZSaberLv0/ZFVimExpand'
    ```

1. use `:ZFExpand`, in normal mode (expand current line) or visual mode (selected lines)

pattern rules:

* `{2..5}` : expand to `2 3 4 5` number sequence
* `{aa,bb,cc}` : expand to `aa bb cc` string sequence
* `{..}` : repeat previous pattern
* `{..3}` : repeat 3rd pattern (index start from 0)

you may also supply your own pattern rules, see the Config below


# Config

```
" the default pattern tags
let g:ZFVimExpand_tagL='{'
let g:ZFVimExpand_tagR='}'

" token to split text
let g:ZFVimExpand_textSplitToken=','

" token to split number
let g:ZFVimExpand_numSplitToken='..'

" token to repeat previous pattern
let g:ZFVimExpand_repeatToken='..'

" whether auto reindent after expand
let g:ZFVimExpand_reindent=0

" add your custom item parse rules
" return passed list if success, or empty list or string if unable to parse
"
" for example
"     {add|remove}User
" your parser would receive this as pattern
"     add|remove
let g:ZFVimExpand_customItemParser='MyItemParser'
function! MyItemParser(pattern)
    return split(a:pattern, '|')
endfunction
```


# Functions

* `:ZFExpand [tagL, tagR]`

    `tagL` and `tagR` are optional, it's useful if your content contains the tag token, example:

    ```
    int n<0..2> = {0,1,2};
    ```

    `:ZFExpand < >` would result:

    ```
    int n0 = {0,1,2};
    int n1 = {0,1,2};
    int n2 = {0,1,2};
    ```

* `:ZFExpandReversely [tagL, tagR]`

    same as `:ZFExpand` but expand items in reverse order

