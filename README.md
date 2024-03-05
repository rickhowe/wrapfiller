# wrapfiller

## Align each wrapped line virtually between windows

This plugin fills with virtual lines to visually align the position of each
line between two or more windows, even when the `wrap` option is on, and makes
it easier to find the lines you want to compare.

Vim's diff mode is useful to see differences between windows. All the text
lines are aligned properly by `filler` in the `diffopt` option, the
`scrollbind` option, and so on. But when `wrap` is on, some line will occupy
more than one screen line and each line will get misaligned. In particular,
such as on resolving git merge conflict within vim, the more diff mode
windows, the more confused. It may not be so easy to find corresponding lines
between windows.

![demo01](demo01.png)

This plugin is called each time the `diff` option is set or reset on a window.
It counts the number of screen lines required to align the position of each
line between all the diff mode windows in a tab page, and then fill them with
virtual lines on each window. As a default, those virtual lines are shown as
diff filler lines, specified in `diff` item in `fillchars` option
(default: `-`) using `hl-DiffDelete` highlight, at "below" the actual lines.
Accordingly, each corresponding line will be aligned side-by-side on the same
screen position.

![demo02](demo02.png)

This plugin, when called, locally checks the limited range of the current
visible and its upper/lower lines of a window and then shows those virtual
lines. Each time a cursor is moved on to other range upon scrolling or
searching, the new lines will be checked in that limited range. Which means,
independently of the file size, the number of lines to be checked and then the
time consumed are always constant.

Those virtual lines are, while shown, automatically adjusted to a change of
several options (such as `number`, `linebreak`, `foldcolumn`, `tabstop`),
text, and window width.

You can also use the `list` option for a normal non-diff mode window. This
plugin is called to find all the list mode windows, show `<<<` in `hl-NonText`
highlight as virtual lines, and align each line between those windows.

![demo03](demo03.png)

### Options

* `g:WrapFiller`, `t:WrapFiller` : Enable or disable the *wrapfiller* (default: 1)

  | Value | Description |
  | --- | --- |
  | 0 | disable |
  | 1 | enable |

* `g:WrapFillerType` : A type of the virtual line (default: 1)

  | Value | Description |
  | --- | --- |
  | 0 | `~` in `hl-EndOfBuffer`, end of buffer (eob) filler line |
  | 1 | `diff` mode: `-------` in `hl-DiffDelete`, diff filler line<br>`list` mode: `<<<` in `hl-NonText` |

* `g:WrapFillerMinLines`, `t:WrapFillerMinLines` : The minimum number of virtual lines (default: 0)

### Requirements

This plugin requires:
* the textprop (text property) feature and patch-9.0.1067 in Vim 9.0
* the extmark (extended mark) functions in Nvim 0.6
