-- Coderun configuration: shortcuts for running code

-- Helper to easily set autocmds in Lua
local function buf_map(mode, lhs, rhs, opts)
	opts = vim.tbl_extend("force", { noremap = true, silent = true, buf = 0 }, opts or {})
	vim.keymap.set(mode, lhs, rhs, opts)
end

-- Create all autocmds
vim.api.nvim_create_autocmd("FileType", {
	pattern = "python",
	callback = function()
		buf_map("n", "<F10>", ":w<CR>:!python3 %<CR>")
		buf_map("i", "<F10>", "<Esc>:w<CR>:!python3 %<CR>")
		buf_map("n", "<F11>", ":w<CR>:FloatermNew --disposable --autoclose=never python3 %<CR>")
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "sh",
	callback = function()
		buf_map("n", "<F10>", ":w<CR>:!/bin/bash %<CR>")
		buf_map("i", "<F10>", "<Esc>:w<CR>:!/bin/bash %<CR>")
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "cpp" },
	callback = function()
		buf_map("n", "<F10>", ":w<CR>:!g++ -Wall -Wextra -g -o %:p:r % && %:p:r<CR>")
		buf_map(
			"n",
			"<F11>",
			":w<CR>:FloatermNew --disposable --autoclose=never g++ -Wall -Wextra -g -o %:p:r % && %:p:r<CR>"
		)
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "lua",
	callback = function()
		buf_map("n", "<F10>", ":w<CR>:!lua %<CR>")
		buf_map("n", "<F11>", ":w<CR>:FloatermNew --disposable --autoclose=never lua %<CR>")
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function()
		buf_map("n", "<F10>", ":w<CR>:!go run %<CR>")
		buf_map("i", "<F10>", "<Esc>:w<CR>:!go run %<CR>")
		buf_map("n", "<F11>", ":w<CR>:FloatermNew --disposable --autoclose=never go run %<CR>")
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "rust",
	callback = function()
		buf_map("n", "<F10>", ":w<CR>:!cargo run %<CR>")
		buf_map("i", "<F10>", "<Esc>:w<CR>:!cargo run %<CR>")
		buf_map("n", "<F11>", ":w<CR>:FloatermNew --disposable --autoclose=never cargo run %<CR>")
	end,
})
