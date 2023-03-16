{
    description = "FEFA modules";
    outputs = {...}: {
        nixosModules = {
            "20.03" = import ./20.03.nix;
            "21.05" = import ./21.05.nix;
            "22.11" = import ./22.11.nix;
        };
    };
}