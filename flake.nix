{
  description = "admin-scripts";

  inputs = {
    nixpkgs.url     = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              # Fix bitwarden-cli build on macOS - use prebuilt binaries instead of rebuilding
              bitwarden-cli = prev.bitwarden-cli.overrideAttrs (old: {
                # Override postConfigure to skip removing prebuilts and npm rebuild
                # This avoids argon2 compilation issues with libcxx-19.1.7 on macOS
                postConfigure = final.lib.optionalString (!final.stdenv.hostPlatform.isDarwin) (old.postConfigure or "");
              });

              # Skip tests for Python packages that fail on macOS.
              # Load-bearing: weasyprint 65.1 (this nixos-unstable pin)
              # segfaults in its test suite on aarch64-darwin.
              python311 = prev.python311.override {
                packageOverrides = pyfinal: pyprev: {
                  weasyprint = pyprev.weasyprint.overridePythonAttrs (old: {
                    doCheck = false;
                  });
                };
              };
            })
          ];
        };
        python = pkgs.python311.withPackages (ppkgs: with ppkgs; [
          ansi2html
          weasyprint
        ]);

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
