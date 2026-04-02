{
  lib,
  pkgs,
  config,
  ...
}: {
  home = {
    sessionVariables = {
      JAVA_8_HOME = "${pkgs.jdk8}";
      JAVA_11_HOME = "${pkgs.jdk11}";
      JAVA_21_HOME = "${pkgs.jdk21}";
      JAVA_25_HOME = "${pkgs.jdk25}";
    };
    packages = [
      pkgs.wrapped.kanshi
      pkgs.neovim
      pkgs.vscode-extensions.vadimcn.vscode-lldb.adapter

      pkgs.devenv
      pkgs.pnpm
      pkgs.kooha
    ];
  };
}
