-- remove "How-to disable mouse" and its separator from the right-click PopUp menu.
-- silent! so a future Neovim that drops these entries can't abort init.lua with E329.
vim.cmd('silent! aunmenu PopUp.How-to\\ disable\\ mouse')
vim.cmd('silent! aunmenu PopUp.-2-')
