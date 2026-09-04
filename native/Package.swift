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
        // Cet exécutable garde la logique métier vérifiable sans dépendre d'un
        // simulateur iOS.
        .executableTarget(name: "EoleCoreVerify", dependencies: ["EoleCore"]),
    ]
)
