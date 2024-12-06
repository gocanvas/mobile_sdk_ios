// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GCSdk",
    platforms: [
            .iOS(.v16)
        ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "GCSdk",
            targets: ["GCSdk"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AFNetworking/AFNetworking", from: "4.0.1"),
        .package(url: "https://github.com/openid/AppAuth-IOS", from: "1.4.0"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.6.1"),
        .package(url: "https://github.com/Scandit/datacapture-spm", from: "6.24.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.28.1"),
        .package(url: "https://github.com/PSPDFKit/PSPDFKit-SP", from: "11.3.2"),
        .package(url: "https://github.com/jonkykong/SideMenu", from: "6.4.8"),
        .package(url: "https://github.com/scalessec/Toast-Swift", from: "5.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .binaryTarget(
            name: "GCSdk",
            path: "./GCSdk.xcframework"
        )
    ]
)
