{
  programs.nixvim = {
    plugins = {
      lualine = {
        enable = true;
        globalstatus = true;
        sections = {
          lualine_x = ["encoding" "filetype"];
          lualine_z = ["searchcount" "selectioncount" "location"];
        };
        componentSeparators.left = "";
        componentSeparators.right = "";
      };
    };
  };
}
