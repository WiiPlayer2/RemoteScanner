{ system, inputs, ... }:
let
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  lib = pkgs.lib;

  android-sdk = inputs.android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
    build-tools-35-0-0
    build-tools-34-0-0
    cmdline-tools-latest
    emulator
    platform-tools
    platforms-android-35
    platforms-android-34
  ]);

  dotnet-combined =
    let
      # This is needed to install workload in $HOME
      # https://discourse.nixos.org/t/dotnet-maui-workload/20370/2
      userlocal =  ''
          for i in $out/sdk/*; do
            i=$(basename $i)
            length=$(printf "%s" "$i" | wc -c)
            substring=$(printf "%s" "$i" | cut -c 1-$(expr $length - 2))
            i="$substring""00"
            mkdir -p $out/metadata/workloads/''${i/-*}
            touch $out/metadata/workloads/''${i/-*}/userlocal
          done
        '';
      # append userlocal sctipt to postInstall phase
      postInstallUserlocal = (finalAttrs: previousAttrs: {
          postInstall = (previousAttrs.postInstall or '''') + userlocal;
      });
      # append userlocal sctipt to postBuild phase
      postBuildUserlocal = (finalAttrs: previousAttrs: {
          postBuild = (previousAttrs.postBuild or '''') + userlocal;
      });
    in
      (with pkgs.dotnetCorePackages; combinePackages [
        (sdk_9_0.overrideAttrs postInstallUserlocal)
        (sdk_8_0.overrideAttrs postInstallUserlocal)
      ]).overrideAttrs postBuildUserlocal;

  shell = pkgs.mkShell {
    packages = with pkgs; [
        dotnet-combined
        tree
        android-sdk
        gradle
        jdk17
        aapt
        llvm_18
        jetbrains.rider
    ];

    DOTNET_ROOT = "${dotnet-combined}";
    ANDROID_HOME = "${android-sdk}/share/android-sdk";
    ANDROID_SDK_ROOT = "${android-sdk}/share/android-sdk";
    JAVA_HOME = pkgs.jdk17.home;
    NIX_LD_LIBRARY_PATH= pkgs.lib.makeLibraryPath [ 
        (lib.getLib pkgs.llvm_18)
        (lib.getLib pkgs.glibc)
        (lib.getLib pkgs.zlib)
      ];
    # make sure you have `programs.nix-ld.enable = true;` in your nixos config
    NIX_LD = pkgs.runCommand "ld.so" {} ''
      ln -s "$(cat '${pkgs.stdenv.cc}/nix-support/dynamic-linker')" $out
    '';

    shellHook = "exec zsh";
  };
in
  shell
