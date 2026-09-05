{
  description = "admin-scripts";

  inputs = {
    # FlakeHub's weekly nixpkgs snapshot rather than a rolling unstable branch:
    # it is a fully-built, fully-cached cut, and it is what the bare `nixpkgs#`
    # registry alias resolves to on these machines, so ad-hoc `nix build
    # nixpkgs#foo` checks agree with what this flake actually builds.
    nixpkgs.url      = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/*.tar.gz";
    flake-utils.url  = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        # Only the stdlib is needed now; code_to_pdf no longer uses weasyprint
        # or ansi2html, which is what previously forced a python311 package-set
        # override to skip a test suite that segfaults on darwin.
        python = pkgs.python3;

        # Runtime dependencies that will be added to every wrapped script's PATH
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
          bat
          typst
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
            bash-language-server
          ] ++ runtimePkgs;
        };
      });
}
