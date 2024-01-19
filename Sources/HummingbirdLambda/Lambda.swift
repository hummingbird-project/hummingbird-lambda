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

import AWSLambdaEvents
import AWSLambdaRuntimeCore
import Hummingbird
import HummingbirdFoundation
import Logging
import NIOCore
import NIOPosix

/// Protocol for Hummingbird Lambdas. Define the `In` and `Out` types, how you convert from `In` to `HBRequest` and `HBResponse` to `Out`
public protocol HBLambda {
    associatedtype Event: Decodable
    associatedtype Context: HBLambdaRequestContext<Event> = HBBasicLambdaRequestContext<Event>
    associatedtype Output: Encodable
    associatedtype Responder: HBResponder<Context>

    func buildResponder() -> Responder

    /// Initialize application.
    ///
    /// This is where you add your routes, and setup middleware
    init() async throws

    /// Called when Lambda is terminating. This is where you can cleanup any resources
    func shutdown() async throws

    /// Convert from `In` type to `HBRequest`
    /// - Parameters:
    ///   - context: Lambda context
    ///   - from: input type
    func request(context: LambdaContext, from: Event) throws -> HBRequest

    /// Convert from `HBResponse` to `Out` type
    /// - Parameter from: response from Hummingbird
    func output(from: HBResponse) async throws -> Output
}

/// Protocol for Hummingbird Lambdas that use APIGateway
public protocol HBAPIGatewayLambda: HBLambda where Event == APIGatewayRequest, Output == APIGatewayResponse {
    associatedtype Context = HBBasicLambdaRequestContext<APIGatewayRequest>
}

/// Protocol for Hummingbird Lambdas that use APIGatewayV2
public protocol HBAPIGatewayV2Lambda: HBLambda where Event == APIGatewayV2Request, Output == APIGatewayV2Response {
    associatedtype Context = HBBasicLambdaRequestContext<APIGatewayV2Request>
}

extension HBLambda {
    /// Initializes and runs the Lambda function.
    ///
    /// If you precede your `EventLoopLambdaHandler` conformer's declaration with the
    /// [@main](https://docs.swift.org/swift-book/ReferenceManual/Attributes.html#ID626)
    /// attribute, the system calls the conformer's `main()` method to launch the lambda function.
    public static func main() throws {
        HBLambdaHandler<Self>.main()
    }

    public func shutdown() async throws {}

    /// default configuration
    public var configuration: HBApplicationConfiguration { .init() }
}
