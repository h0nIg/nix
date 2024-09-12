#!/usr/bin/env bash

source ../common.sh

TODO_NixOS

clearStore
rm -rf $TEST_HOME/.cache $TEST_HOME/.config $TEST_HOME/.local

# Create flake under test.
cp ../shell-hello.nix "${config_nix}" $TEST_HOME/
cat <<EOF >$TEST_HOME/flake.nix
{
    inputs.nixpkgs.url = "$TEST_HOME/nixpkgs";
    outputs = {self, nixpkgs}: {
      packages.$system.hello = (import ./config.nix).mkDerivation {
        name = "hello";
        outputs = [ "out" "dev" ];
        meta.outputsToInstall = [ "out" ];
        buildCommand = "";
      };
    };
}
EOF

# Create fake nixpkgs flake.
mkdir -p $TEST_HOME/nixpkgs
cp "${config_nix}" ../shell.nix $TEST_HOME/nixpkgs

# `config.nix` cannot be gotten via build dir / env var (runs afoul pure eval). Instead get from flake.
removeBuildDirRef "$TEST_HOME/nixpkgs"/*.nix

cat <<EOF >$TEST_HOME/nixpkgs/flake.nix
{
    outputs = {self}: {
      legacyPackages.$system.bashInteractive = (import ./shell.nix {}).bashInteractive;
    };
}
EOF

cd $TEST_HOME

# Test whether `nix develop` passes through environment variables.
[[ "$(
    ENVVAR=a nix develop --no-write-lock-file .#hello <<EOF
echo "\$ENVVAR"
EOF
)" = "a" ]]

# Test whether `nix develop --ignore-env` does _not_ pass through environment variables.
[[ -z "$(
    ENVVAR=a nix develop --ignore-env --no-write-lock-file .#hello <<EOF
echo "\$ENVVAR"
EOF
)" ]]

# Determine the bashInteractive executable.
nix build --no-write-lock-file './nixpkgs#bashInteractive' --out-link ./bash-interactive
BASH_INTERACTIVE_EXECUTABLE="$PWD/bash-interactive/bin/bash"

# Test whether `nix develop` sets `SHELL` to nixpkgs#bashInteractive shell.
[[ "$(
    SHELL=custom nix develop --no-write-lock-file .#hello <<EOF
echo "\$SHELL"
EOF
)" -ef "$BASH_INTERACTIVE_EXECUTABLE" ]]

# Test whether `nix develop` with ignore environment sets `SHELL` to nixpkgs#bashInteractive shell.
[[ "$(
    SHELL=custom nix develop --ignore-env --no-write-lock-file .#hello <<EOF
echo "\$SHELL"
EOF
)" -ef "$BASH_INTERACTIVE_EXECUTABLE" ]]

clearStore
