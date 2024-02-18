{
  description = "rust-overlay-auditable-repro";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    rust-overlay = {
      url = "github:oxalica/rust-overlay/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tailsrv = {
      type = "tarball";
      url = "https://crates.io/api/v1/crates/tailsrv/0.6.1/download";
      flake = false;
    };
  };

  outputs = inputs @ { self, nixpkgs, rust-overlay, tailsrv }:
    nixpkgs.lib.lists.foldr
      (system: acc: acc // nixpkgs.lib.attrsets.mapAttrs
        (name: value:
          (acc.${name} or { }) // {
            ${system} = value;
          }
        )
        (
          let
            rustToolchain = pkgs:
              let
                rustChannel = (pkgs.rust-bin.fromRustupToolchain { channel = "1.76.0"; });
              in
              {
                # Commenting out the below makes the auditable thing go away
                cargo = rustChannel;
                rustPlatform = pkgs.makeRustPlatform {
                  rustc = rustChannel;
                  cargo = rustChannel;
                };
              };

            rust = import nixpkgs {
              inherit system; overlays = [
              (import rust-overlay)
              (self: _: rustToolchain self)
            ];
            };

            # Random crate to demonstrate auditable issue.
            tailsrv = rust.rustPlatform.buildRustPackage
              {
                # auditable = false;
                pname = (nixpkgs.lib.importTOML "${inputs.tailsrv}/Cargo.toml").package.name;
                version = (nixpkgs.lib.importTOML "${inputs.tailsrv}/Cargo.toml").package.version;
                src = inputs.tailsrv;
                doCheck = false;
                cargoLock = {
                  lockFile = "${inputs.tailsrv}/Cargo.lock";
                };
              };

          in
          {
            legacyPackages = rust;
            packages = {
              inherit tailsrv;
            };
          }
        )
      )
      { } [ "x86_64-linux" "aarch64-linux" ];
}
