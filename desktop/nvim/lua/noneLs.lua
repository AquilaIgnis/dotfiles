--''''''''''''''''Non-ls/null-ls''''''''''''''''
local null_ls = require("null-ls")

-- ruff/rustfmt formatting live in none-ls-extras, not in none-ls core
local ruff_format = require("none-ls.formatting.ruff_format")
local rustfmt_format = require("none-ls.formatting.rustfmt")

null_ls.setup({
	sources = {
		null_ls.builtins.diagnostics.djlint,
		null_ls.builtins.diagnostics.cppcheck,
		null_ls.builtins.diagnostics.codespell,
		null_ls.builtins.diagnostics.hadolint,
		null_ls.builtins.formatting.prettierd.with({ extra_args = { "--single-quote" } }),
		null_ls.builtins.formatting.gofumpt,
		null_ls.builtins.formatting.stylua,
		ruff_format,
		rustfmt_format,
	},
	on_attach = function(client, bufnr)
		if client:supports_method("textDocument/formatting") then -- run formatters on save
			vim.api.nvim_create_autocmd("BufWritePre", {
				buf = bufnr,
				callback = function()
					vim.lsp.buf.format({ bufnr = bufnr })
				end,
			})
		end
	end,
})
