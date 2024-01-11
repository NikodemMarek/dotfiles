{
  programs.nixvim = {
    options = {
      shiftwidth = 4;
      tabstop = 4;
      expandtab = true;

      termguicolors = true;

      number = true;
      relativenumber = true;

      wrap = true;
      foldcolumn = "1";
      # fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]];
      foldlevel = 99;
      foldlevelstart = 99;
      foldenable = true;

      signcolumn = "number";
    };
  };
}
