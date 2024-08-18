{

  description = "bolun-scripts";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;

  outputs = { self, nixpkgs }: {

  stdenv.mkDerivation rec {
    name = "bolun-scripts-${version}";
    version = "1.0";
    src = ./.;

    nativeBuildInputs = [ ];
    buildInputs = [ bitwarden-cli sshpass ];
    buildPhase = "./build";
    installPhase = ''
      mkdir -p $out/bin
      cp -r ./bin $out/bin
    '';
  };


}
