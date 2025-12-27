{
  description = "Baiteroids dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          zig
          zls
          raylib
          libxrandr
          libxrender
          libxinerama
          libxfixes
          libxi
          libxcursor
        ];

        shellHook = ''
          export PS1="\n\033[38;5;81m[baiteroids: \W]\033[0m\n$ "
        '';
      };
    };
}
