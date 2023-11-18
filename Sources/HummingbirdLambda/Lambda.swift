//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
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
import HummingbirdFoundation
import NIOPosix
import NIOCore
import Logging

/// Protocol for Hummingbird Lambdas. Define the `In` and `Out` types, how you convert from `In` to `HBRequest` and `HBResponse` to `Out`
public protocol HBLambda {
    associatedtype Context: HBRequestContext
    associatedtype Event: Decodable
    associatedtype Output: Encodable
    associatedtype Responder: HBResponder<Context>

    var responder: Responder { get }
    var applicationContext: HBApplicationContext { get }

    /// Initialize application.
    ///
    /// This is where you add your routes, and setup middleware
    init() async throws

    func shutdown() async throws

    /// Convert from `In` type to the user's `Context`
    /// - Parameters:
    ///   - context: Lambda context
    ///   - from: input type
    func requestContext(
        coreContext: HBCoreRequestContext,
        context: LambdaContext,
        from: Event
    ) throws -> Context

    /// Convert from `In` type to `HBRequest`
    /// - Parameters:
    ///   - context: Lambda context
    ///   - from: input type
    func request(context: LambdaContext, from: Event) throws -> HBRequest

    /// Convert from `HBResponse` to `Out` type
    /// - Parameter from: response from Hummingbird
    func output(from: HBResponse) async throws -> Output
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

    public var applicationContext: HBApplicationContext {
        HBApplicationContext(
            threadPool: NIOSingletons.posixBlockingThreadPool,
            configuration: HBApplicationConfiguration(),
            logger: Logger(label: "hb-lambda"),
            encoder: JSONEncoder(),
            decoder: JSONDecoder()
        )
    }

    public func shutdown() async throws {}
}
