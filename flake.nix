{
  description = "DeepSeek image and text moderation";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: {
    packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
      default = nixpkgs.legacyPackages.${system}.callPackage ./nix/package.nix { };
    });
    nixosModules.default = import ./nix/module.nix self;
  };
}
