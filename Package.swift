// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "hummingbird-lambda",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "HummingbirdLambda", targets: ["HummingbirdLambda"]),
        .executable(name: "HBLambdaTest", targets: ["HBLambdaTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0-alpha.1"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events.git", from: "0.1.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-base64.git", from: "0.5.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0-alpha.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.32.0"),
    ],
    targets: [
        .target(name: "HummingbirdLambda", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
            .product(name: "ExtrasBase64", package: "swift-extras-base64"),
            .product(name: "Hummingbird", package: "hummingbird"),
        ]),
        .target(name: "HummingbirdLambdaXCT", dependencies: [
            .byName(name: "HummingbirdLambda"),
        ]),
        .executableTarget(name: "HBLambdaTest", dependencies: [
            .byName(name: "HummingbirdLambda"),
        ]),
        .testTarget(name: "HummingbirdLambdaTests", dependencies: [
            .byName(name: "HummingbirdLambda"),
            .byName(name: "HummingbirdLambdaXCT"),
            .product(name: "NIOPosix", package: "swift-nio"),
        ]),
    ]
)
