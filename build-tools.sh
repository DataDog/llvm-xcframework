#!/bin/bash
set -e

##
# Install ninja, autoconf, automake and libtool for macOS
##

export build=`pwd`/temp # or wherever you'd like to build
export install=`pwd`/tools
mkdir -p $build
mkdir -p $install

export PATH="$install/bin:$PATH"

##
# CMake
# https://cmake.org/

echo "Downloading CMake..."
cd $build
curl -OL https://github.com/Kitware/CMake/releases/download/v3.31.0/cmake-3.31.0-macos-universal.tar.gz
tar xzf cmake-3.31.0-macos-universal.tar.gz
cd cmake-3.31.0-macos-universal
mv CMake.app/Contents/bin $install/
mv CMake.app/Contents/doc $install/
mv CMake.app/Contents/man $install/
mv CMake.app/Contents/share $install/
rm -rf CMake.app

##
# Ninja
# https://github.com/ninja-build/ninja

echo "Downloading Ninja..."
cd $build
curl -OL https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-mac.zip
unzip ninja-mac.zip
mv ninja $install/bin/

echo "Installation complete. Make sure to add $install/bin to your PATH"
