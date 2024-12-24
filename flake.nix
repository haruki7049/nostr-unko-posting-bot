{
  description = "A CLI code-formatter for any lisp dialects, written by Rust-lang";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    crane.url = "github:ipetkov/crane";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        {
          pkgs,
          lib,
          system,
          ...
        }:
        let
          overlays = [ inputs.rust-overlay.overlays.default ];
          rust = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          craneLib = (inputs.crane.mkLib pkgs).overrideToolchain rust;
          src = lib.cleanSource ./.;
          cargoArtifacts = craneLib.buildDepsOnly {
            inherit src;
          };
          unkobot = craneLib.buildPackage {
            inherit src cargoArtifacts;
            strictDeps = true;
            doCheck = true;
          };
          cargo-clippy = craneLib.cargoClippy {
            inherit src cargoArtifacts;
            cargoClippyExtraArgs = "--verbose -- --deny warning";
          };
          cargo-doc = craneLib.cargoDoc {
            inherit src cargoArtifacts;
          };
        in
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system overlays;
          };

          checks = {
            inherit
              unkobot
              cargo-clippy
              cargo-doc
              ;
          };

          packages = {
            inherit
              unkobot
              cargo-clippy
              cargo-doc
              ;
            default = unkobot;
            doc = cargo-doc;
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs.nixfmt.enable = true;
            programs.rustfmt.enable = true;
            #programs.taplo.enable = true; # BUG: taplo failed when I use it on aarch64-darwin
            programs.actionlint.enable = true;
            programs.mdformat.enable = true;
          };

          devShells.default = pkgs.mkShell {
            packages = [
              rust
              pkgs.nil
            ];

            shellHook = ''
              export PS1="\n[nix-shell:\w]\$ "
            '';
          };
        };
    };
}
