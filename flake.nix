{
  description = "admin-scripts";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python312.withPackages (ppkgs: with ppkgs; [
          ansi2html
          weasyprint
        ]);

        # Runtime dependencies that will be added to every wrapped script’s PATH
        runtimePkgs = with pkgs; [
          coreutils
          bash
          git
          bitwarden-cli
          sshpass
          openssh
          findutils
          gnugrep
          gnused
          wkhtmltopdf
          bat
          python
        ];
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname   = "admin-scripts";
          version = "1.0";
          src     = ./.;

          nativeBuildInputs = with pkgs; [ coreutils makeWrapper gnused ];

          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            cp -r ./bin "$out"
            cp lib.sh "$out"
            runHook postInstall
          '';

          postInstall = let wrapperPath = pkgs.lib.makeBinPath runtimePkgs; in ''
            for program in "$out"/bin/*; do
              wrapProgram "$program" --prefix PATH : "${wrapperPath}"
            done
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            shfmt
            shellcheck
            nodePackages_latest.bash-language-server
          ] ++ runtimePkgs;
        };
      });
}
