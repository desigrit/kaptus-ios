// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "KaptusCore", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "KaptusCore", targets: ["KaptusCore"])], targets: [.systemLibrary(name: "CZlib"), .target(name: "KaptusCore", dependencies: ["CZlib"]), .testTarget(name: "KaptusCoreTests", dependencies: ["KaptusCore"])])
