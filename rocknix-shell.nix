# Nix shell environment for building ROCKNIX
# Uses FHS user environment to provide standard paths expected by ROCKNIX build system
{ pkgs ? import <nixpkgs> {} }:

let
  perlWithModules = pkgs.perl.withPackages (p: with p; [
    JSON
    ParseYapp
    XMLParser
  ]);
in
(pkgs.buildFHSEnv {
  name = "rocknix-build-env";

  targetPkgs = pkgs: (with pkgs; [
    # Core build tools
    bash
    bc
    file
    gawk
    gcc
    git
    gnumake
    binutils

    # Language runtimes
    jre
    go
    python3

    # Perl with required modules
    perlWithModules

    # Build utilities
    gperf
    lzop
    patchutils
    automake
    autoconf
    libtool

    # Archive tools
    unzip
    zip
    zstd

    # Network tools
    wget
    curl
    rsync

    # XML/font tools
    libxslt      # provides xsltproc
    xmlstarlet
    xorg.mkfontdir
    xorg.mkfontscale
    xorg.bdftopcf

    # System utilities
    parted
    vim          # provides xxd
    ncurses
    ncurses.dev  # provides ncurses headers
    rdfind

    # Development headers
    glibc
    glibc.dev

    # Additional tools that might be needed
    pkg-config
    which
    coreutils
    findutils
    diffutils
    patch
    gnused
  ]);

  profile = ''
    export MAKEFLAGS="-j$NIX_BUILD_CORES"

    # Set up Perl environment with modules
    # The perl.withPackages creates a wrapper, but we need the actual module paths
    PERL_ENV=$(find /nix/store -maxdepth 1 -name "*perl-5.40.0-env" -type d | head -1)
    if [ -d "$PERL_ENV/lib/perl5/site_perl" ]; then
      export PERL5LIB="$PERL_ENV/lib/perl5/site_perl/5.40.0:$PERL_ENV/lib/perl5/site_perl:$PERL5LIB"
      export PATH="$PERL_ENV/bin:$PATH"
    fi
  '';

  runScript = "bash";

})
