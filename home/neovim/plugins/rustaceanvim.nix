{pkgs, ...}: {
  home.packages = with pkgs; [
    vscode-extensions.vadimcn.vscode-lldb.adapter
  ];

  programs.nixvim = {
    plugins = {
      rustaceanvim = {
        enable = true;
        settings.server.settings = {
          cargo = {
            buildScripts = {
              enable = true;
            };
          };
          procMacro = {
            enable = true;
          };
        };
      };
    };
  };
}
