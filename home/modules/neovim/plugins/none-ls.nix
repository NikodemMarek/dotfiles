{
  programs.nixvim.plugins.none-ls = {
    enable = true;
    enableLspFormat = true;
    sources = {
      code_actions = {
        statix.enable = true;
      };
      diagnostics = {
        statix.enable = true;
        ktlint.enable = true;
        pylint.enable = true;
      };
      formatting = {
        alejandra.enable = true;
        ktlint.enable = true;
        google_java_format.enable = true;
        black.enable = true;
      };
    };
  };
}
