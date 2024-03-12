//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntimeCore
import Hummingbird
import Logging
import NIOCore
import NIOPosix

/// Protocol for Hummingbird Lambdas.
///
/// Defines the `Event` and `Output` types, how you convert from `Event` to ``HummingbirdCore/HBRequest``
/// and ``HummingbirdCore/HBResponse`` to `Output`. Create a type conforming to this protocol and tag it
/// with `@main`.
/// ```swift
/// struct MyLambda: LambdaFunction {
///     typealias Event = APIGatewayRequest
///     typealias Output = APIGatewayResponse
///     typealias Context = MyLambdaRequestContext // must conform to `HBLambdaRequestContext`
///
///     init(context: LambdaInitializationContext) {}
///
///     /// build responder that will create a response from a request
///     func buildResponder() -> some Responder<Context> {
///         let router = Router(context: Context.self)
///         router.get("hello") { _,_ in
///             "Hello"
///         }
///         return router.buildResponder()
///     }
/// }
/// ```
/// - SeeAlso: ``HBAPIGatewayLambda`` and ``HBAPIGatewayV2Lambda`` for specializations of this protocol.
public protocol LambdaFunction: Sendable {
    /// Event that triggers the lambda
    associatedtype Event: Decodable
    /// Request context
    associatedtype Context: LambdaRequestContext<Event> = BasicLambdaRequestContext<Event>
    /// Output of lambda
    associatedtype Output: Encodable
    /// HTTP Responder
    associatedtype Responder: HTTPResponder<Context>

    func buildResponder() -> Responder

    /// Initialize application.
    init(context: LambdaInitializationContext) async throws

    /// Called when Lambda is terminating. This is where you can cleanup any resources
    func shutdown() async throws

    /// Convert from `In` type to `HBRequest`
    /// - Parameters:
    ///   - context: Lambda context
    ///   - from: input type
    func request(context: LambdaContext, from: Event) throws -> Request

    /// Convert from `HBResponse` to `Out` type
    /// - Parameter from: response from Hummingbird
    func output(from: Response) async throws -> Output
}

extension LambdaFunction {
    /// Initializes and runs the Lambda function.
    ///
    /// If you precede your `EventLoopLambdaHandler` conformer's declaration with the
    /// [@main](https://docs.swift.org/swift-book/ReferenceManual/Attributes.html#ID626)
    /// attribute, the system calls the conformer's `main()` method to launch the lambda function.
    public static func main() throws {
        HBLambdaHandler<Self>.main()
    }

    public func shutdown() async throws {}
}
