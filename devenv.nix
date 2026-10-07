{pkgs, ...}: {
  packages = [pkgs.kubectl pkgs.fluxcd pkgs.sops pkgs.age pkgs.yamlfmt pkgs.nfs-utils pkgs.k9s pkgs.k3s pkgs.pv-migrate];

  scripts = {
    mksecret.exec = "sops --encrypt --encrypted-regex '^(data|stringData)$' --in-place $1";
  };

  enterShell = ''
    export KUBECONFIG=kubeconfig.yaml
  '';
}
