{

  description = "admin-scripts";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.default =

      with import nixpkgs { system = "x86_64-linux"; };
      stdenv.mkDerivation {
        name = "admin-scripts";
        version = "1.0";
        src = ./.;

        nativeBuildInputs = [ ];
        # only some functions require some scripts, but, as of right now,
        # all of these are fundemental enough that I can assume I can have them
        buildInputs = [ bitwarden-cli sshpass ];
        installPhase = ''
          mkdir -p $out
          cp -r ./bin $out
          cp lib.sh $out
        '';
      };
  };
}
