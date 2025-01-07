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
import AWSLambdaRuntime
import Hummingbird
import Logging
import NIOCore
import ServiceLifecycle
import UnixSignals

/// swift-aws-lambda-runtime v2 proposal indicates this will eventually be added
extension LambdaRuntime: @retroactive Service {}

/// Lambda event type that can generate HTTP Request
public protocol LambdaEvent: Decodable {
    func request(context: LambdaContext) throws -> Request
}

/// Lambda output type that can be generated from HTTP Response
public protocol LambdaOutput: Encodable {
    init(from: Response) async throws
}

/// Protocol for a AWS Lambda function.
public protocol LambdaFunctionProtocol: Service where Responder.Context: InitializableFromSource<LambdaRequestContextSource<Event>> {
    /// Event that triggers the lambda
    associatedtype Event: LambdaEvent
    /// Output of lambda
    associatedtype Output: LambdaOutput
    /// Responder that generates a response from a request and context
    associatedtype Responder: HTTPResponder
    /// Context passed with Request to responder
    typealias Context = Responder.Context

    /// Build the responder
    var responder: Responder { get async throws }
    /// Logger
    var logger: Logger { get }
    /// services attached to the lambda.
    var services: [any Service] { get }
}

extension LambdaFunctionProtocol {
    /// Default to no extra services attached to the application.
    public var services: [any Service] { [] }
    /// Default logger.
    public var logger: Logger { .init(label: "Hummingbird") }
}

/// Conform to `Service` from `ServiceLifecycle`.
extension LambdaFunctionProtocol {
    /// Construct lambda runtime and run it
    public func run() async throws {
        let responder = try await self.responder
        let runtime = LambdaRuntime { (event: Event, context: LambdaContext) -> Output in
            let request = try event.request(context: context)
            let context = Responder.Context(source: .init(event: event, lambdaContext: context))
            let response = try await responder.respond(to: request, context: context)
            return try await .init(from: response)
        }
        let services: [any Service] = self.services + [LambdaRuntimeService(runtime: runtime, logger: self.logger)]
        let serviceGroup = ServiceGroup(
            configuration: .init(services: services, logger: self.logger)
        )
        try await serviceGroup.run()
    }

    /// Helper function that runs lambda inside a ServiceGroup which will gracefully
    /// shutdown on signals SIGINT, SIGTERM
    public func runService() async throws {
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [self],
                gracefulShutdownSignals: [.sigterm],
                logger: self.logger
            )
        )
        try await serviceGroup.run()
    }
}

/// Concrete Lambda function
public struct LambdaFunction<Responder: HTTPResponder, Event: LambdaEvent, Output: LambdaOutput>: LambdaFunctionProtocol
where Responder.Context: InitializableFromSource<LambdaRequestContextSource<Event>> {
    /// routes requests to responders based on URI
    public let responder: Responder
    /// services attached to the application.
    public var services: [any Service]
    /// Logger
    public var logger: Logger

    ///  Initialize LambdaFunction
    /// - Parameters:
    ///   - responder: HTTP responder
    ///   - event: Lambda event type that will trigger lambda
    ///   - output: Lambda output type
    ///   - services: Services attached to LambdaFunction
    ///   - logger: Logger used by lambda during setup
    public init(
        responder: Responder,
        event: Event.Type = Event.self,
        output: Output.Type = Output.self,
        services: [Service] = [],
        logger: Logger? = nil
    ) {
        if let logger {
            self.logger = logger
        } else {
            var logger = Logger(label: "Hummingbird")
            logger.logLevel = Environment().get("LOG_LEVEL").map { Logger.Level(rawValue: $0) ?? .info } ?? .info
            self.logger = logger
        }
        self.responder = responder
        self.services = services
    }

    ///  Initialize LambdaFunction
    /// - Parameters:
    ///   - router: HTTP responder builder
    ///   - event: Lambda event type that will trigger lambda
    ///   - output: Lambda output type
    ///   - services: Services attached to LambdaFunction
    ///   - logger: Logger used by lambda during setup
    public init<ResponderBuilder: HTTPResponderBuilder>(
        router: ResponderBuilder,
        event: Event.Type = Event.self,
        output: Output.Type = Output.self,
        services: [Service] = [],
        logger: Logger? = nil
    ) where Responder == ResponderBuilder.Responder {
        self.init(
            responder: router.buildResponder(),
            services: services,
            logger: logger
        )
    }

    ///  Add service to be managed by lambda function's ServiceGroup
    /// - Parameter services: list of services to be added
    public mutating func addServices(_ services: any Service...) {
        self.services.append(contentsOf: services)
    }
}

private struct LambdaRuntimeService<Handler: StreamingLambdaHandler>: Service {
    let runtime: LambdaRuntime<Handler>
    let logger: Logger

    func run() async throws {
        try await withGracefulShutdownHandler {
            try await cancelWhenGracefulShutdown {
                try await self.runtime.run()
            }
        } onGracefulShutdown: {
            self.logger.info("SHUTDOWN!")
        }
    }
}
