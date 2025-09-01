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
import HTTPTypes
import Logging
import NIOCore
import ServiceLifecycle

@testable import AWSLambdaRuntime
@testable import HummingbirdLambda

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

class LambdaTestFramework<Lambda: LambdaFunctionProtocol> where Lambda.Event: LambdaTestableEvent {
    let context: LambdaContext
    let lambda: Lambda

    init(lambda: Lambda) {
        self.lambda = lambda
        self.context = .init(
            requestID: UUID().uuidString,
            traceID: "abc123",
            invokedFunctionARN: "aws:arn:",
            deadline: LambdaClock().now.advanced(by: .seconds(15)),
            cognitoIdentity: nil,
            clientContext: nil,
            logger: lambda.logger
        )
    }

    func run<Value>(_ test: @escaping @Sendable (LambdaTestClient<Lambda>) async throws -> Value) async throws -> Value {
        let client = LambdaTestClient(lambda: lambda, context: context)
        // if we have no services then just run test
        if self.lambda.services.count == 0 {
            // run the runBeforeServer processes before we run test closure.
            for process in self.lambda.processesRunBeforeLambdaStart {
                try await process()
            }
            return try await test(client)
        }
        // if we have services then setup task group with service group running in separate task from test
        return try await withThrowingTaskGroup(of: Void.self) { group in
            let serviceGroup = ServiceGroup(
                configuration: .init(
                    services: self.lambda.services,
                    gracefulShutdownSignals: [.sigterm, .sigint],
                    logger: self.lambda.logger
                )
            )
            group.addTask {
                try await serviceGroup.run()
            }
            do {
                for process in self.lambda.processesRunBeforeLambdaStart {
                    try await process()
                }
                let value = try await test(client)
                await serviceGroup.triggerGracefulShutdown()
                return value
            } catch {
                await serviceGroup.triggerGracefulShutdown()
                throw error
            }
        }
    }
}

/// Client used to send requests to lambda test framework
public struct LambdaTestClient<Lambda: LambdaFunctionProtocol> where Lambda.Event: LambdaTestableEvent {
    let lambda: Lambda
    let context: LambdaContext

    func execute(uri: String, method: HTTPRequest.Method, headers: HTTPFields, body: ByteBuffer?) async throws -> Lambda.Output {
        let event = try Lambda.Event(uri: uri, method: method, headers: headers, body: body)
        let request = try event.request(context: context)
        let context = Lambda.Responder.Context(source: .init(event: event, lambdaContext: context))
        let response = try await lambda.responder.respond(to: request, context: context)
        let output = try await Lambda.Output(from: response)
        return output
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
