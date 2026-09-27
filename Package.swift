// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacTranslate",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "MacTranslate", targets: ["MacTranslate"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "MacTranslate",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/MacTranslate",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ]
)
