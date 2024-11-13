#!/bin/bash
# Build LLVM XCFramework
#
# The script arguments are the platforms to build, eg: macosx iphoneos iphonesimulator maccatalyst appletvos appletvsimulator
#
# We assume that all required build tools (CMake, ninja, etc.) are either installed and accessible in $PATH
# or are available locally within this repo root at $REPO_ROOT/tools/bin (building on VSTS).
set -e

VERSION=$1
shift
PLATFORMS=( "$@" )

# Constants
export REPO_ROOT=`pwd`
export PATH="$REPO_ROOT/tools/bin:$PATH"
export BUILD_TEMP="$REPO_ROOT/temp"
export BUILD_DIR="$REPO_ROOT/build"
export PATCH_DIR="$REPO_ROOT/patch"
export LLVM_DIR="$BUILD_TEMP/llvm-project"

export MACOSX_DEPLOYMENT_TARGET=10.13
export IPHONEOS_DEPLOYMENT_TARGET=11.0
export TVOS_DEPLOYMENT_TARGET=11.0

function get_llvm_src() {
	local VPATCH_DIR="$PATCH_DIR/$VERSION"
	if [ ! -d "$VPATCH_DIR" ]; then
		echo "Unsupported LLVM version: $VERSION"
		exit 1
	fi

	local DIR="$(pwd)"
	cd "$(dirname "$LLVM_DIR")"

	echo "Downloading LLVM $VERSION"

	# Download sources
	curl -OL https://github.com/llvm/llvm-project/releases/download/llvmorg-$VERSION/llvm-project-$VERSION.src.tar.xz
	tar xzf llvm-project-$VERSION.src.tar.xz
	mv llvm-project-$VERSION.src $(basename "$LLVM_DIR")

	# Apply patches for this version
	for patch in "$VPATCH_DIR"/*; do
		if [[ $patch == *.diff ]]; then
			echo "Applying patch: $patch"
			git apply --ignore-space-change --ignore-whitespace "$patch"
		fi
	done

	cd "$LLVM_DIR"
	
	#Create tvOS cmake based on iOS one
	cp llvm/cmake/platforms/iOS.cmake llvm/cmake/platforms/tvOS.cmake
	sed -i.bak 's/iphoneos/appletvos/' llvm/cmake/platforms/tvOS.cmake

	#Create macOS cmake based on iOS one
	cp llvm/cmake/platforms/iOS.cmake llvm/cmake/platforms/macOS.cmake
	sed -i.bak 's/iphoneos/macosx/' llvm/cmake/platforms/macOS.cmake

	cd "$DIR"
}

# Build LLVM for a given iOS platform
# Assumptions:
#  * ninja was extracted at this repo root
#  * LLVM is checked out inside this repo
function build_llvm() {
	local PLATFORM=$1
	local LLVM_INSTALL_DIR="$2"

	echo "Build llvm for $PLATFORM"
	cd "$LLVM_DIR"
	rm -rf build
	mkdir build
	cd build

	# https://opensource.com/article/18/5/you-dont-know-bash-intro-bash-arrays
	# ;lld;libcxx;libcxxabi
	local CMAKE_ARGS=(-G "Ninja" \
		-DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
		-DLLVM_BUILD_TOOLS=OFF \
		-DCLANG_BUILD_TOOLS=OFF \
		-DBUILD_SHARED_LIBS=OFF \
		-DLLVM_ENABLE_ZLIB=ON \
		-DLLVM_ENABLE_THREADS=ON \
		-DLLVM_ENABLE_UNWIND_TABLES=OFF \
		-DLLVM_ENABLE_EH=OFF \
		-DLLVM_ENABLE_RTTI=OFF \
		-DLLVM_ENABLE_ZSTD=OFF \
		-DLLVM_ENABLE_FFI=OFF \
		-DLLVM_ENABLE_TERMINFO=OFF \
		-DLLVM_DISABLE_ASSEMBLY_FILES=ON \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=$LLVM_INSTALL_DIR)

	case $PLATFORM in
		"macosx")
			ARCH="arm64;x86_64"
   			CMAKE_ARGS+=(-DLLVM_TARGET_ARCH=$ARCH \
				-DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/macOS.cmake);;

		"iphoneos")
			ARCH="arm64"
			CMAKE_ARGS+=(-DLLVM_TARGET_ARCH=$ARCH \
				-DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake);;

		"iphonesimulator")
			ARCH="arm64;x86_64"
			SYSROOT=$(xcodebuild -version -sdk iphonesimulator Path)
			CMAKE_ARGS+=(-DCMAKE_OSX_SYSROOT=$SYSROOT \
				-DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake);;

		"appletvos")
			ARCH="arm64"
			CMAKE_ARGS+=(-DLLVM_TARGET_ARCH=$ARCH \
				-DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/tvOS.cmake);;

		"appletvsimulator")
			ARCH="arm64;x86_64"
			SYSROOT=$(xcodebuild -version -sdk appletvsimulator Path)
			CMAKE_ARGS+=(-DCMAKE_OSX_SYSROOT=$SYSROOT \
				-DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/tvOS.cmake);;

		"maccatalyst")
			ARCH="arm64;x86_64"
			SYSROOT=$(xcodebuild -version -sdk macosx Path)
			CMAKE_ARGS+=(-DCMAKE_OSX_SYSROOT=$SYSROOT \
				-DCMAKE_C_FLAGS="-target x86_64-apple-ios14.1-macabi" \
				-DCMAKE_CXX_FLAGS="-target x86_64-apple-ios14.1-macabi" \
				-DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake);;

		*)
			echo "Unknown or missing platform!"
			ARCH=x86_64
			exit 1;;
	esac

	CMAKE_ARGS+=(-DCMAKE_OSX_ARCHITECTURES=$ARCH)

	# https://www.shell-tips.com/bash/arrays/
	# https://www.lukeshu.com/blog/bash-arrays.html
	printf 'CMake Argument: %s\n' "${CMAKE_ARGS[@]}"

	# Generate configuration for building for iOS Target (on MacOS Host)
	# Note: AArch64 = arm64
	cmake "${CMAKE_ARGS[@]}" ../llvm
	# Build
	cmake --build .

	# Install libs
	cmake --install .

	# return to repo root
	cd "$REPO_ROOT"
}

# Prepare the LLVM built for usage in Xcode
function prepare_llvm() {
	cd "$1"

	# Remove unnecessary executables and support files
	rm -rf bin libexec share

	# Move unused stuffs in lib to a temporary lib2 (restored when necessary)
	mkdir lib2
	mv lib/cmake lib2/ || true
	mv lib/*.dylib lib2/ || true
	mv lib/libc++* lib2/ || true
	rm -rf lib2 # Comment this if you want to keep

	# Combine all *.a into a single llvm.a for ease of use
	libtool -static -o llvm.a lib/*.a

	# Remove unnecessary lib files if packaging
	rm -rf lib/*.a
	# Move combined lib back
	mv llvm.a lib/

	cd "$REPO_ROOT"
}

mkdir -p "$BUILD_TEMP"
mkdir -p "$BUILD_DIR"

# Download LLVM sources if needed
test -d "$LLVM_DIR" || get_llvm_src

FRAMEWORKS_ARGS=()
for p in ${PLATFORMS[@]}; do
	echo "Build LLVM library for $p"

	PLATFORM_DIR="$BUILD_DIR/$p"

	build_llvm $p "$PLATFORM_DIR" && prepare_llvm "$PLATFORM_DIR"

	FRAMEWORKS_ARGS+=(-library "$PLATFORM_DIR/lib/llvm.a" -headers "$PLATFORM_DIR/include")
done

echo "Create XC framework with arguments" ${FRAMEWORKS_ARGS[@]}
xcodebuild -create-xcframework ${FRAMEWORKS_ARGS[@]} -output LLVM.xcframework
zip -ry ./LLVM.xcframework.zip ./LLVM.xcframework
shasum -a 256 LLVM.xcframework.zip | sed 's/ .*//' > LLVM.xcframework.zip.sha256