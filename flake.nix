{

  description = "admin-scripts";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.default =

      with import nixpkgs { system = "x86_64-linux"; };
      stdenv.mkDerivation rec {
        name = "admin-scripts-${version}";
        version = "1.0";
        src = ./.;

        nativeBuildInputs = [ ];
        buildInputs = [ bitwarden-cli sshpass ];
        buildPhase = "bash ./build build";
        installPhase = ''
          mkdir -p $out
          cp -r ./bin $out
          cp lib.sh $out
        '';
      };


  };
}
