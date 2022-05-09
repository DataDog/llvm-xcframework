# Build LLVM XCFramework
#
# The script arguments are the platforms to build
#
# We assume that all required build tools (CMake, ninja, etc.) are either installed and accessible in $PATH
# or are available locally within this repo root at $REPO_ROOT/tools/bin (building on VSTS).

PLATFORMS=( "$@" )

# Constants
export REPO_ROOT=`pwd`
export MACOSX_DEPLOYMENT_TARGET=10.13
export IPHONEOS_DEPLOYMENT_TARGET=11.0
export TVOS_DEPLOYMENT_TARGET=11.0

function get_llvm_src() {
	#git clone --single-branch --branch release/14.x https://github.com/llvm/llvm-project.git

	wget https://github.com/llvm/llvm-project/releases/download/llvmorg-14.0.0/llvm-project-14.0.0.src.tar.xz
	tar xzf llvm-project-14.0.0.src.tar.xz
	mv llvm-project-14.0.0.src llvm-project

    #Apply Datadog - CI Visibility patch to LLVM
    git apply  --ignore-space-change --ignore-whitespace coverage-patch.diff

    #Apply tvOS support patches to LLVM
    git apply  --ignore-space-change --ignore-whitespace process-patch.diff
    git apply  --ignore-space-change --ignore-whitespace program-patch.diff
    git apply  --ignore-space-change --ignore-whitespace signals-patch.diff

}

# Build LLVM for a given iOS platform
# Assumptions:
#  * ninja was extracted at this repo root
#  * LLVM is checked out inside this repo
function build_llvm() {
	local PLATFORM=$1
	local LLVM_DIR=$REPO_ROOT/llvm-project
	local LLVM_INSTALL_DIR=$REPO_ROOT/LLVM-$PLATFORM

	echo "Build llvm for $PLATFORM"

	cd $REPO_ROOT
	test -d llvm-project || get_llvm_src
	cd llvm-project
	rm -rf build
	mkdir build
	cd build

    #Create tvOS cmake based on iOS one
    cp ../llvm/cmake/platforms/iOS.cmake ../llvm/cmake/platforms/tvOS.cmake
    sed -i.bak 's/iphoneos/appletvos/' ../llvm/cmake/platforms/tvOS.cmake

    #Create macOS cmake based on iOS one
    cp ../llvm/cmake/platforms/iOS.cmake ../llvm/cmake/platforms/macOS.cmake
    sed -i.bak 's/iphoneos/macosx/' ../llvm/cmake/platforms/macOS.cmake


	# https://opensource.com/article/18/5/you-dont-know-bash-intro-bash-arrays
	# ;lld;libcxx;libcxxabi
	local CMAKE_ARGS=(-G "Ninja" \
		-DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
		-DLLVM_BUILD_TOOLS=OFF \
		-DBUILD_SHARED_LIBS=OFF \
		-DLLVM_ENABLE_ZLIB=ON \
		-DLLVM_ENABLE_THREADS=ON \
		-DLLVM_ENABLE_UNWIND_TABLES=OFF \
		-DLLVM_ENABLE_EH=OFF \
		-DLLVM_ENABLE_RTTI=OFF \
		-DLLVM_ENABLE_TERMINFO=OFF \
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
			SYSROOT=`xcodebuild -version -sdk iphonesimulator Path`
			CMAKE_ARGS+=(-DCMAKE_OSX_SYSROOT=$SYSROOT \
                -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/iOS.cmake);;

		"appletvos")
			ARCH="arm64"
			CMAKE_ARGS+=(-DLLVM_TARGET_ARCH=$ARCH \
                -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/tvOS.cmake);;

		"appletvsimulator")
			ARCH="arm64;x86_64"
			SYSROOT=`xcodebuild -version -sdk appletvsimulator Path`
			CMAKE_ARGS+=(-DCMAKE_OSX_SYSROOT=$SYSROOT \
                -DCMAKE_TOOLCHAIN_FILE=../llvm/cmake/platforms/tvOS.cmake);;

		"maccatalyst")
			ARCH="arm64;x86_64"
			SYSROOT=`xcodebuild -version -sdk macosx Path`
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
}

# Prepare the LLVM built for usage in Xcode
function prepare_llvm() {
	local PLATFORM=$1

	cd $REPO_ROOT/LLVM-$PLATFORM

	# Remove unnecessary executables and support files
	rm -rf bin libexec share

	# Move unused stuffs in lib to a temporary lib2 (restored when necessary)
	mkdir lib2
	mv lib/cmake lib2/
	mv lib/*.dylib lib2/
	mv lib/libc++* lib2/
	rm -rf lib2 # Comment this if you want to keep

	# Combine all *.a into a single llvm.a for ease of use
	libtool -static -o llvm.a lib/*.a

	# Remove unnecessary lib files if packaging
	rm -rf lib/*.a
}

FRAMEWORKS_ARGS=()
for p in ${PLATFORMS[@]}; do
	echo "Build LLVM library for $p"

	build_llvm $p && prepare_llvm $p

	cd $REPO_ROOT
	FRAMEWORKS_ARGS+=(-library LLVM-$p/llvm.a -headers LLVM-$p/include)
	tar -cJf LLVM-$p.tar.xz LLVM-$p/
done

echo "Create XC framework with arguments" ${FRAMEWORKS_ARGS[@]}
xcodebuild -create-xcframework ${FRAMEWORKS_ARGS[@]} -output LLVM.xcframework
tar -cJf LLVM.xcframework.tar.xz LLVM.xcframework
