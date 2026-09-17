// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EoleNative",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "EoleCore", targets: ["EoleCore"]),
    ],
    targets: [
        .target(name: "EoleCore"),
        // Cet exécutable garde la logique métier vérifiable sans dépendre d'un
        // simulateur iOS.
        .executableTarget(name: "EoleCoreVerify", dependencies: ["EoleCore"]),
        .testTarget(name: "EoleCoreTests", dependencies: ["EoleCore"]),
    ]
)
