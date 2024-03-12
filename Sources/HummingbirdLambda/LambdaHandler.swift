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

import AWSLambdaRuntime
import Hummingbird
import Logging
import NIOCore
import NIOPosix

/// Specialization of LambdaHandler which runs an Lambda
struct LambdaFunctionHandler<L: LambdaFunction>: LambdaHandler {
    public typealias Event = L.Event
    public typealias Output = L.Output

    let lambda: L
    let responder: L.Responder

    /// Initialize `LambdaHandler`.
    ///
    /// Create `LambdaFunction` from context and create responder
    /// - Parameter context: Lambda initialization context
    public init(context: LambdaInitializationContext) async throws {
        let lambda = try await L(context: context)

        context.terminator.register(name: "Application") { eventLoop in
            return eventLoop.makeFutureWithTask {
                try await lambda.shutdown()
            }
        }

        self.lambda = lambda
        self.responder = lambda.buildResponder()
    }

    /// Handle an invocation of this Lambda
    /// - Parameter event: The event that triggered the Lambda
    /// - Parameter context: The context for this invocation.
    public func handle(_ event: Event, context: LambdaContext) async throws -> Output {
        let requestContext = L.Context(
            event,
            lambdaContext: context
        )
        let request = try lambda.request(context: context, from: event)
        let response: Response
        do {
            response = try await self.responder.respond(to: request, context: requestContext)
        } catch {
            if let error = error as? HTTPResponseError {
                response = error.response(allocator: context.allocator)
            } else {
                throw error
            }
        }

        return try await self.lambda.output(from: response)
    }
}
