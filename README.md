# ZFVimExpand

expand utility

if you like my work, [check here](https://github.com/ZSaberLv0?utf8=%E2%9C%93&tab=repositories&q=ZFVim) for a list of my vim plugins,
or [buy me a coffee](https://github.com/ZSaberLv0/ZSaberLv0)

* before expand:

    ```
    void <add,remove>Item<0..2>(int item<@@>) {
    }
    ```

* after expand: (by `:ZFExpandReversely < >`)

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
* `{d..a}` : expand to `d c b a` letter sequence
* `{\xAB12..\xAB21}` : expand to string sequence accorrding to the HEX value,
    which would be converted by `nr2char()`,
    these token are equivalent: `\x` `\X` `\u` `\U`
* `{aa,bb,cc}` : expand to `aa bb cc` string sequence
* `{@@}` : repeat previous pattern
    * `{@@3}` : repeat 3rd pattern (index start from 0,
        note: `{@@}` does not obtain one index, but `{x,y,z@@}` would obtain one index)
    * `{x,y,z@@}` : repeat previous pattern, but use the specified `x,y,z` as item pattern
* `{Fn: let ret = i<len(p[3]) ? p[3][i] : END :Fn}` : custom function to supply item

    you must `let ret = xxx` to specify result item (as string or number type, for each `i`),
    or `let ret = END` to indicate no more item

    predefined vars:

    * `reverse` : `0/1`, whether `ZFExpandReversely`
    * `po` : all original pattern including self, e.g. `["2..5", "Fn: let ret = p[3][i] :Fn"]`
    * `p` : all parsed pattern including self, e.g. `[[2,3,4,5], function(xxx)]`
    * `pi` : self parttern index in `p`
    * `i` : current item loop index
    * `END` : dummy item that indicates no more item

    you may use `|` for multiple commands (`:h :bar`)

    you may append `@@N` to ref another pattern
    (`{Fn: let ret = i<len(p[3]) ? p[3][i] : END :Fn@@3}`)

* `{Fn:"YourFunc":Fn}` : similar as above, but use function name,
    YourFunc must take one param,
    which is a Dict contains params described above,
    and must return proper values to indicate item loop,
    for example:

    ```
    function! YourFunc(params)
        let i = a:params['i']
        if i >= 10
            return a:params['END']
        else
            return i
        endif
    endfunction
    ```

    you may append `@@N` to ref another pattern
    (`{Fn:"YourFunc":Fn@@3}`)


you may also supply your own pattern rules, see the Config below


# Config

```
" the default pattern tags
let g:ZFVimExpand_tagL='{'
let g:ZFVimExpand_tagR='}'

" token to split text
let g:ZFVimExpand_textSplitToken=','

" token to split range
let g:ZFVimExpand_rangeSplitToken='..'

" token to repeat previous pattern
let g:ZFVimExpand_repeatToken='@@'

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

