{

  description = "admin-scripts";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

  outputs = { self, nixpkgs }:
    let
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });

    in
    {
      packages = forAllSystems
        ({ pkgs }: {

          default = with pkgs; stdenv.mkDerivation {
            name = "admin-scripts";
            version = "1.0";
            src = ./.;

            nativeBuildInputs = [ coreutils makeWrapper ];

            # TODO: Create dev shell

            postInstall =
              let
                wrapperPath = lib.makeBinPath [
                  coreutils
                  bash
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
        }
        );

      devShells = forAllSystems
        (
          { pkgs }: {
            default = with pkgs; mkShell {
              packages = [
                shfmt
                shellcheck
                nodePackages_latest.bash-language-server
              ];
            };
          }
        );
    };
}
