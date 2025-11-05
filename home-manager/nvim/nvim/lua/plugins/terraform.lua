return {
	{
		"nvim-treesitter/nvim-treesitter",
		opts = { ensure_installed = { "terraform", "hcl" } },
	},
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				terraformls = {},
			},
		},
	},
	{
		"mason-org/mason.nvim",
		opts = { ensure_installed = { "tflint" } },
	},
	{
		"stevearc/conform.nvim",
		optional = true,
		opts = {
			formatters_by_ft = {
				hcl = { "packer_fmt" },
				terraform = { "terraform_fmt" },
				tf = { "terraform_fmt" },
				["terraform-vars"] = { "terraform_fmt" },
			},
		},
	},
}
