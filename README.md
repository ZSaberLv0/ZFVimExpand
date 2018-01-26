# ZFVimExpand

expand utility

* before expand:

    ```
    aa {1..3} bb {xx,yy,zz} cc
    ```

* after expand:

    ```
    aa 1 bb xx cc
    aa 1 bb yy cc
    aa 1 bb zz cc
    aa 2 bb xx cc
    aa 2 bb yy cc
    aa 2 bb zz cc
    aa 3 bb xx cc
    aa 3 bb yy cc
    aa 3 bb zz cc
    ```


# How to use

1. use [Vundle](https://github.com/VundleVim/Vundle.vim) or any other plugin manager is recommended

    ```
    Plugin 'ZSaberLv0/ZFVimExpand'
    ```

1. use `:ZFExpand`, in normal mode (expand current line) or visual mode (selected lines)


# Config

```
" the default pattern tags
let g:ZFVimExpand_tagL='{'
let g:ZFVimExpand_tagR='}'

" token to split text
let g:ZFVimExpand_textSplitToken=','

" token to split number
let g:ZFVimExpand_numSplitToken='\.\.'

" whether auto reindent after expand
let g:ZFVimExpand_reindent=0
```


# Functions

* `:ZFExpand`

    ```
    :ZFExpand [tagL, tagR]
    ```

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

