{ config, pkgs, lib, settings, ... }: {
    programs.nixvim = {
        keymaps = [
            # Lsp symbols
            { mode = "n"; key = "<leader>ls"; action = "<cmd>Telescope lsp_references<cr>"; options.desc = "Document symbols"; }
        ];
        plugins = {
            lsp = {
                enable = true;
                keymaps.lspBuf = {
                    K = "hover";
                    gD = "references";
                    gd = "definition";
                    gi = "implementation";
                    gt = "type_definition";

                    "<leader>lr" = "rename";
                    "<leader>la" = "code_action";
                    "<leader>ld" = "type_definition";
                };
                servers = {
                    nixd.enable = true;

                    rust-analyzer = {
                        enable = true;
                        installCargo = false;
                        installRustc = false;
                    };

                    denols.enable = true;
                    tailwindcss.enable = true;

                    kotlin-language-server.enable = true;
                    java-language-server.enable = true;
                };
            };
            nvim-jdtls = {
                enable = true;
                cmd = [
                    "$/{pkgs.jdt-language-server}/bin/jdt-language-server"
                    "-data" ".cache/jdtls/data"
                    "-configuration" ".cache/jdtls/configuration"
                ];
            };
            lsp-format.enable = true;
        };
    };
}
