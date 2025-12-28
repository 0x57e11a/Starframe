{
	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
		systems.url = "github:nix-systems/default";
	};

	outputs = { nixpkgs, systems, ... }: let
		forAllSystems = fn: nixpkgs.lib.genAttrs (import systems) (system: fn nixpkgs.legacyPackages.${system});
	in {
		devShells = forAllSystems (pkgs: {
			default = pkgs.mkShell {
				buildInputs = with pkgs; [
					lua52Packages.lua
					# lua52Packages.argparse
					# lua52Packages.luasocket
					# lua52Packages.dkjson
					# lua52Packages.luafilesystem
					lua52Packages.luarocks
				];
			};
		});
	};
}
