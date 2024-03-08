//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
@testable import AWSLambdaRuntimeCore
import Foundation
import HTTPTypes
@testable import HummingbirdLambda
import Logging
import NIOCore
import NIOPosix

class HBLambdaTestFramework<Lambda: HBLambda> where Lambda.Event: LambdaTestableEvent {
    let context: LambdaContext
    var terminator: LambdaTerminator

    init(logLevel: Logger.Level) {
        var logger = Logger(label: "HBTestLambda")
        logger.logLevel = logLevel
        self.context = .init(
            requestID: UUID().uuidString,
            traceID: "abc123",
            invokedFunctionARN: "aws:arn:",
            deadline: .now() + .seconds(15),
            cognitoIdentity: nil,
            clientContext: nil,
            logger: logger,
            eventLoop: MultiThreadedEventLoopGroup.singleton.any(),
            allocator: ByteBufferAllocator()
        )
        self.terminator = .init()
    }

    var initializationContext: LambdaInitializationContext {
        .init(
            logger: self.context.logger,
            eventLoop: self.context.eventLoop,
            allocator: self.context.allocator,
            terminator: .init()
        )
    }

    func run<Value>(_ test: @escaping @Sendable (HBLambdaTestClient<Lambda>) async throws -> Value) async throws -> Value {
        let handler = try await HBLambdaHandler<Lambda>(context: self.initializationContext)
        let value = try await test(HBLambdaTestClient(handler: handler, context: context))
        try await self.terminator.terminate(eventLoop: self.context.eventLoop).get()
        self.terminator = .init()
        return value
    }
}

/// Client used to send requests to lambda test framework
public struct HBLambdaTestClient<Lambda: HBLambda> where Lambda.Event: LambdaTestableEvent {
    let handler: HBLambdaHandler<Lambda>
    let context: LambdaContext

    func execute(uri: String, method: HTTPRequest.Method, headers: HTTPFields, body: ByteBuffer?) async throws -> Lambda.Output {
        let event = try Lambda.Event(uri: uri, method: method, headers: headers, body: body)
        return try await self.handler.handle(event, context: self.context)
    }

    /// Send request to lambda test framework and call `testCallback`` on the response returned
    ///
    /// - Parameters:
    ///   - uri: Path of request
    ///   - method: Request method
    ///   - headers: Request headers
    ///   - body: Request body
    ///   - testCallback: closure to call on response returned by test framework
    /// - Returns: Return value of test closure
    @discardableResult public func execute<Return>(
        uri: String,
        method: HTTPRequest.Method,
        headers: HTTPFields = [:],
        body: ByteBuffer? = nil,
        testCallback: @escaping (Lambda.Output) async throws -> Return
    ) async throws -> Return {
        let response = try await execute(uri: uri, method: method, headers: headers, body: body)
        return try await testCallback(response)
    }
}
