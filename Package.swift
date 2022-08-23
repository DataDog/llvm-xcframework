// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let releaseVersion = "14.0.0"
let relaseChecksum = "f21837ae93e2b5f31afa681ce40672b8641ff60c6ce77c45afb2410e43abd919"
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
