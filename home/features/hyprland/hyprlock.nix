{
  config,
  lib,
  ...
}: {
  programs.hyprlock = {
    enable = true;
    settings = {
      background = lib.mkDefault [
        {
          monitor = "";
          path = "${config.stylix.image}";
        }
      ];
      input-field = lib.mkDefault [
        {
          monitor = "";
          size = "300, 50";
          outline_thickness = 3;
          dots_size = 0.33;
          dots_spacing = 0.15;
          dots_center = true;
          outer_color = "0xff${config.stylix.base16Scheme.base00}";
          inner_color = "0xff${config.stylix.base16Scheme.base03}";
          font_color = "0xff${config.stylix.base16Scheme.base05}";
          fade_on_empty = true;
          placeholder_text = "<i>password</i>";
          hide_input = false;

          position = "0, 0";
          halign = "center";
          valign = "center";
        }
      ];
      label = lib.mkDefault [
        {
          monitor = "";
          text = "$TIME";
          color = "0xff${config.stylix.base16Scheme.base05}";
          font_size = 25;

          position = "0, 0";
          halign = "center";
          valign = "bottom";
        }
      ];
    };
  };
}
