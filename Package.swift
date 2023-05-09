// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let releaseVersion = "15.0.0"
let relaseChecksum = "1377b44b7e64adbc0311eca1c118fe11bc56d6fa7248914049d559956befe3ba"
let url = "https://github.com/DataDog/llvm-xcframework/releases/download/\(releaseVersion)/LLVM.xcframework.zip"

let package = Package(
    name: "llvm-xcframework",
    platforms: [.macOS(.v10_13),
                .iOS(.v11),
                .tvOS(.v11)],
    products: [
        .library(
            name: "llvm-xcframework",
            targets: [
                "LLVM",
            ]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "LLVM",
            url: url,
            checksum: relaseChecksum
        )
    ]
)
