{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = [
      (pkgs.vimUtils.buildVimPlugin {
        name = "markview";
        src = pkgs.fetchFromGitHub {
          owner = "OXY2DEV";
          repo = "markview.nvim";
          rev = "0be70c7566288dfb2c561c17e5aa6d255c278310";
          hash = "sha256-oz5niGTpjzWI+evKrUS9NISvI166NDJGNgiRFzX96Ec=";
        };
      })
    ];
  };
}
