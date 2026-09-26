// swift-tools-version:6.2
import PackageDescription

var swiftSettings: [SwiftSetting] = [
    // https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md
    .enableUpcomingFeature("ExistentialAny"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0444-member-import-visibility.md
    .enableUpcomingFeature("MemberImportVisibility"),

    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0409-access-level-on-imports.md
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "hummingbird-lambda",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "HummingbirdLambda", targets: ["HummingbirdLambda"]),
        .library(name: "HummingbirdLambdaTesting", targets: ["HummingbirdLambdaTesting"]),
        .executable(name: "HBLambdaTest", targets: ["HBLambdaTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/awslabs/swift-aws-lambda-runtime.git", from: "3.0.2"),
        .package(url: "https://github.com/awslabs/swift-aws-lambda-events.git", from: "1.4.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-base64.git", from: "1.2.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.27.0", traits: []),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.100.0"),
    ],
    targets: [
        .target(
            name: "HummingbirdLambda",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "ExtrasBase64", package: "swift-extras-base64"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "HummingbirdLambdaTesting",
            dependencies: [
                .byName(name: "HummingbirdLambda")
            ],
            swiftSettings: swiftSettings
        ),

        .executableTarget(
            name: "HBLambdaTest",
            dependencies: [
                .byName(name: "HummingbirdLambda")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "HummingbirdLambdaTests",
            dependencies: [
                .byName(name: "HummingbirdLambda"),
                .byName(name: "HummingbirdLambdaTesting"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
