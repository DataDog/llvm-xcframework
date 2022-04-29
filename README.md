# llvm-xcframework

Distributable version of LLVM libraries as a XCFramework and SPM support.


This repository is heavily inspired by the build code in the repository: https://github.com/light-tech/LLVM-On-iOS , but our goals are  a bit different. We want to distribute LLVM as a multiplatform XCFramework using SPM, so it can be linked easily. 
 
 The LLVM distribution also includes a small patch to generate only a subset of coverage information (only files actually run), which makes it a non standard LLVM distribution, but is optimized for the use case of CI Visibility in Datadog
