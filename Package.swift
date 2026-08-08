// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SSHDock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SSHDock",
            targets: ["SSHDock"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.7")
    ],
    targets: [
        .executableTarget(
            name: "SSHDock",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/SSHDock"
        )
    ]
)
