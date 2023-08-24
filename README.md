# wrapfiller

## Align each line exactly between windows even if wrapped

This plugin fills with virtual lines to exactly align the position of each
line between windows, even when the `wrap` option is on, and makes it easier
to find the lines you want to compare.

Vim's diff mode is useful to see differences between windows. All the text
lines are aligned properly by `filler` in the `diffopt` option, vertical
splits, the `scrollbind` option, and so on. But when `wrap` is on, if
`followwrap` is present in `diffopt` or it is manually set, some line will
occupy more than one screen line and each line will get misaligned. In
particular, such as on resolving git merge conflict within vim, the more diff
mode windows, the more confused. It may not be so easy to find corresponding
lines between windows.

![demo01](demo01.png)

This plugin is called each time the `diff` option is set or reset on a window.
It counts the number of screen lines required to align the position of each
line between all the diff mode windows in a tab page, and then fill them with
virtual lines on each window. As a virtual line, the "virtual text" feature,
implemented in a vim post-9.0 patch and nvim 0.6.0, is used. Those virtual
lines are shown as diff filler lines, specified in `diff` item in `fillchars`
option (default: `-`) using `hl-DiffDelete` highlight, at "below" the actual
lines. Accordingly, each corresponding line will be aligned side-by-side on
the same screen position.

![demo02](demo02.png)

This plugin, when called, only checks the limited range of the current visible
and its upper/lower lines of a window, not all the text lines, to show the
virtual lines. Each time a cursor is moved on to other ranges upon scrolling
or searching, or each time a window is resized, the `WinScrolled` event is
triggered and then the new lines will be checked in that limited range and the
virtual lines will be updated. Which means, independently of the file size,
the number of lines to be checked and then the time consumed are always
constant.

You can also use the `list` option for a normal non-diff mode window. This
plugin is called to find all the list mode windows, show `<<<` in `hl-NonText`
highlight as virtual lines, and align each line between windows.

![demo03](demo03.png)

When screen contents has changed by some options such as `number`,
`linebreak`, and `listchars`, you can set the `diff` or `list` option again on
any window to redraw the virtual lines.

### Options

* `g:WrapFiller`, `t:WrapFiller`

  | Value | Description |
  | --- | --- |
  | 1 | enable (default) |
  | 0 | disable |

### Requirements

This plugin requires:
* the textprop (text property) feature and patch-9.0.1067 in Vim 9.0
* the extmark (extended mark) functions in Nvim 0.6
