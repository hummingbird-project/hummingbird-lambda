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

import AWSLambdaRuntime
import Hummingbird
import NIOCore

/// Specialization of EventLoopLambdaHandler which runs an HBLambda
public struct HBLambdaHandler<L: HBLambda>: EventLoopLambdaHandler {
    public typealias In = L.In
    public typealias Out = L.Out

    /// Initialize `HBLambdaHandler`.
    ///
    /// Create application, set it up and create `HBLambda` from application and create responder
    /// - Parameter context: Lambda initialization context
    public init(context: Lambda.InitializationContext) throws {
        // create application
        let application = HBApplication(eventLoopGroupProvider: .shared(context.eventLoop))
        application.logger = context.logger
        // add error middleware to catch HBHTTPErrors
        application.middleware.add(LambdaErrorMiddleware())
        // initialize application
        self.lambda = try .init(application)
        // store application and responder
        self.application = application
        self.responder = application.constructResponder()
    }

    /// Shutdown Lambda handler and shutdown application
    public func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        do {
            try self.application.shutdownApplication()
            return context.eventLoop.makeSucceededFuture(())
        } catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }

    /// Handle invoke
    public func handle(context: Lambda.Context, event: L.In) -> EventLoopFuture<L.Out> {
        do {
            let request = try lambda.request(context: context, application: self.application, from: event)
            return self.responder.respond(to: request)
                .map { self.lambda.output(from: $0) }
        } catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }

    let application: HBApplication
    let responder: HBResponder
    let lambda: L
}
