//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntimeCore
import Hummingbird

/// Protocol for Hummingbird Lambdas. Define the `In` and `Out` types, how you convert from `In` to `HBRequest` and `HBResponse` to `Out`
public protocol HBLambda {
    associatedtype Event: Decodable
    associatedtype Output: Encodable

    /// Initialize application.
    ///
    /// This is where you add your routes, and setup middleware
    init(_ app: HBApplication) throws

    /// Convert from `In` type to `HBRequest`
    /// - Parameters:
    ///   - context: Lambda context
    ///   - application: Application instance
    ///   - from: input type
    func request(context: LambdaContext, application: HBApplication, from: Event) throws -> HBRequest

    /// Convert from `HBResponse` to `Out` type
    /// - Parameter from: response from Hummingbird
    func output(from: HBResponse) -> Output
}

extension HBLambda {
    /// Initializes and runs the Lambda function.
    ///
    /// If you precede your ``EventLoopLambdaHandler`` conformer's declaration with the
    /// [@main](https://docs.swift.org/swift-book/ReferenceManual/Attributes.html#ID626)
    /// attribute, the system calls the conformer's `main()` method to launch the lambda function.
    public static func main() throws {
        HBLambdaHandler<Self>.main()
    }
}
