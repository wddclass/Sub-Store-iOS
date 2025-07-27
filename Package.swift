// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SubStore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "SubStore",
            targets: ["SubStore"]
        ),
    ],
    dependencies: [
        // Core Dependencies
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        
        // YAML Support
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        
        // QR Code Generation
        .package(url: "https://github.com/dmrschmidt/QRCode.git", from: "17.0.0"),
        
        // Syntax Highlighting
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.1.0"),
        
        // Keychain Access
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "20.0.0")
    ],
    targets: [
        .target(
            name: "SubStore",
            dependencies: [
                "Alamofire",
                "Yams",
                "QRCode",
                "Highlightr",
                .product(name: "KeychainSwift", package: "keychain-swift")
            ]
        ),
        .testTarget(
            name: "SubStoreTests",
            dependencies: ["SubStore"]
        ),
    ]
)