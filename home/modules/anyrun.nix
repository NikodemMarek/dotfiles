{ inputs, config, pkgs, lib, ... }: {
    programs.anyrun = {
        enable = true;
        config = {
            plugins = with inputs.anyrun.packages.${pkgs.system}; [
                applications
                randr
                shell
                symbols
                translate
            ];
            showResultsImmediately = true;
        };
    }; 
}
