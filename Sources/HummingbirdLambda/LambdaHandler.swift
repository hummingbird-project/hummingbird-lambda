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

import AWSLambdaRuntime
import Hummingbird
import Logging
import NIOCore

/// Specialization of EventLoopLambdaHandler which runs an HBLambda
public struct HBLambdaHandler<L: HBLambda>: LambdaHandler {
    public typealias Event = L.Event
    public typealias Output = L.Output

    let lambda: L
    let responder: L.Responder
    let applicationContext: HBApplicationContext

    /// Initialize `HBLambdaHandler`.
    ///
    /// Create application, set it up and create `HBLambda` from application and create responder
    /// - Parameter context: Lambda initialization context
    public init(context: LambdaInitializationContext) async throws {
        let lambda = try await L()

        context.terminator.register(name: "Application") { eventLoop in
            return eventLoop.makeFutureWithTask {
                try await lambda.shutdown()
            }
        }

        self.lambda = lambda
        self.responder = lambda.responder
        self.applicationContext = lambda.applicationContext
    }

    /// Handle invoke
    public func handle(_ event: Event, context: LambdaContext) async throws -> Output {
        let requestContext = try lambda.requestContext(
            coreContext: HBCoreRequestContext(
                applicationContext: applicationContext, 
                eventLoop: NIOSingletons.posixEventLoopGroup.any(), 
                logger: Logger(label: "hb-lambda")
            ),
            context: context, 
            from: event
        )
        let request = try lambda.request(context: context, from: event)
        let response: HBResponse
        do {
            response = try await responder.respond(to: request, context: requestContext)
        } catch {
            if let error = error as? HBHTTPError {
                response = error.response(allocator: context.allocator)
            } else {
                throw error
            }
        }
        
        return try await lambda.output(from: response)
    }
}
