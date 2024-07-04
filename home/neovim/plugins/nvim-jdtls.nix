{
  pkgs,
  lib,
  config,
  ...
}: {
  programs.nixvim.plugins = {
    nvim-jdtls = {
      enable = true;
      cmd = [
        (lib.getExe pkgs.jdt-language-server)

        "--java-executable"
        "${pkgs.jdk}/bin/java"
        "-Declipse.application=org.eclipse.jdt.ls.core.id1"
        "-Dosgi.bundles.defaultStartLevel=4"
        "-Declipse.product=org.eclipse.jdt.ls.core.product"
        "-Dlog.protocol=true"
        "-Dlog.level=ALL"
        "-Xms1g"
        "--add-modules=ALL-SYSTEM"
        "--add-opens"
        "java.base/java.util=ALL-UNNAMED"
        "--add-opens"
        "java.base/java.lang=ALL-UNNAMED"
        "--jvm-arg=-javaagent:${pkgs.lombok}/share/java/lombok.jar"

        "-jar"
        "${pkgs.jdt-language-server}/share/java/jdtls/plugins/org.eclipse.equinox.launcher_1.6.700.v20231214-2017.jar"
        "-data"
        "${config.home.homeDirectory}/.cache/jdtls/data"
      ];
    };
  };
}
