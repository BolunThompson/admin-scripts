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

        nativeBuildInputs = [ makeWrapper ];
        buildInputs = [ coreutils ];

        postInstall =
          let
            wrapperPath = lib.makeBinPath [
              coreutils
              git
              bitwarden-cli
              sshpass
              openssh
            ];
          in
          ''
            for program in $out/bin/*; do
              wrapProgram "$program" --prefix PATH : "${wrapperPath}"
            done
          '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          cp -r ./bin "$out"
          cp lib.sh "$out"
          runHook postInstall
        '';
      };
  };
}
