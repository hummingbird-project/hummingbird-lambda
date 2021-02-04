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
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "0.3.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", .branch("main"))
    ],
    targets: [
        .target(name: "HummingbirdLambda", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
            .product(name: "Hummingbird", package: "hummingbird")
        ]),
        .target(name: "HBLambdaTest", dependencies: [
            .byName(name: "HummingbirdLambda"),
            .product(name: "HummingbirdFoundation", package: "hummingbird")
        ]),
    ]
)
