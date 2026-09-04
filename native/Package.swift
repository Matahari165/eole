// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EoleNative",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "EoleCore", targets: ["EoleCore"]),
        .library(name: "EoleApp", targets: ["EoleApp"]),
    ],
    targets: [
        .target(name: "EoleCore"),
        .target(name: "EoleApp", dependencies: ["EoleCore"]),
        // Pas de testTarget : les CLT de cette machine ne fournissent ni XCTest
        // ni swift-testing. La parité est vérifiée par cet exécutable
        // (mêmes vecteurs que tests/*.test.ts). Sous Xcode : `swift test`
        // fonctionne en re-ajoutant un testTarget XCTest.
        .executableTarget(name: "EoleCoreVerify", dependencies: ["EoleCore"]),
    ]
)
