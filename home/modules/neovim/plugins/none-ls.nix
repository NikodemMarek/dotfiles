{
  programs.nixvim.plugins.none-ls = {
    enable = true;
    sources = {
      code_actions = {
        statix.enable = true;
      };
      diagnostics = {
        statix.enable = true;
        ktlint.enable = true;
      };
      formatting = {
        alejandra.enable = true;
        ktlint.enable = true;
        google_java_format.enable = true;
        prettier.enable = true;
      };
    };
  };
}
