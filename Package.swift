// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "hummingbird-lambda",
    platforms: [
        .macOS(.v10_13),
    ],
    products: [
        .library(name: "HummingbirdLambda", targets: ["HummingbirdLambda"]),
        .executable(name: "HBLambdaTest", targets: ["HBLambdaTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "0.4.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-base64.git", from: "0.5.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "0.8.0"),
    ],
    targets: [
        .target(name: "HummingbirdLambda", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
            .product(name: "ExtrasBase64", package: "swift-extras-base64"),
            .product(name: "Hummingbird", package: "hummingbird"),
        ]),
        .target(name: "HBLambdaTest", dependencies: [
            .byName(name: "HummingbirdLambda"),
            .product(name: "HummingbirdFoundation", package: "hummingbird"),
        ]),
        .testTarget(name: "HummingbirdLambdaTests", dependencies: [
            .byName(name: "HummingbirdLambda"),
            .product(name: "HummingbirdXCT", package: "hummingbird"),
        ]),
    ]
)
