// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SubStore",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "SubStore",
            targets: ["SubStore"]
        ),
    ],
    dependencies: [
        // Core Dependencies
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
        
        // YAML Support
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        
        // Syntax Highlighting
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.1.0"),
        
        // Keychain Access
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "20.0.0")
    ],
    targets: [
        .executableTarget(
            name: "SubStore",
            dependencies: [
                "Alamofire",
                "Yams",
                "Highlightr",
                .product(name: "KeychainSwift", package: "keychain-swift")
            ],
            path: "SubStore",
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources/Fonts"),
                .process("Resources/Images"),
                .process("Resources/Localizations"),
                .process("Resources/SubStore.xcdatamodeld")
            ]
        ),
        .testTarget(
            name: "SubStoreTests",
            dependencies: ["SubStore"]
        ),
    ]
)
