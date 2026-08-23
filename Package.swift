// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "foo",
    targets: [
        .executableTarget(
            name: "foo"
        ),
    .testTarget(
        name: "fooTests",
        dependencies: ["foo"]
    ),
    ],
    swiftLanguageModes: [.v6]
)
