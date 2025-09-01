//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2025 the Hummingbird authors
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
    /// Array of processes run before we kick off the lambda. These tend to be processes that need
    /// other services running but need to be run before the server is setup
    var processesRunBeforeLambdaStart: [@Sendable () async throws -> Void] { get }
}

extension LambdaFunctionProtocol {
    /// Default to no extra services attached to the application.
    public var services: [any Service] { [] }
    /// Default logger.
    public var logger: Logger { .init(label: "Hummingbird") }
    /// Default to no processes being run before the server is setup
    public var processesRunBeforeLambdaStart: [@Sendable () async throws -> Void] { [] }
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
        let lambdaRuntimeService = LambdaRuntimeService(runtime: runtime, logger: self.logger).withPrelude {
            for process in self.processesRunBeforeLambdaStart {
                try await process()
            }
        }
        let services: [any Service] = self.services + [lambdaRuntimeService]
        let serviceGroup = ServiceGroup(
            configuration: .init(services: services, logger: self.logger)
        )
        try await serviceGroup.run()
    }

    /// Helper function that runs lambda inside a ServiceGroup which will gracefully
    /// shutdown on signals SIGTERM
    public func runService() async throws {
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [self],
                gracefulShutdownSignals: [.sigterm, .sigint],
                logger: self.logger
            )
        )
        try await serviceGroup.run()
    }
}

/// Represents a Lambda function with input/output and background processes
///
/// Setup lambda that is triggered by `Event` and has output `Output`. The `Event` type is
/// converted to a Hummingbird ``/HummingbirdCore/Request`` and passed into the `responder`. The
/// resulting ``/HummingbirdCore/Response`` is then converted to the `Output` type of the lambda.
///
/// For example an APIGateway Lamdba is setup as follows
/// ```swift
/// let router = Router(context: BasicLambdaRequestContext<APIGatewayRequest>.self)
/// router.get { request, context in
///     "Hello!"
/// }
/// let lambda = LambdaFunction(
///     event: APIGatewayRequest.self,
///     output: APIGatewayResponse.self,
///     router: router
/// )
/// try await lambda.runService()
/// ```
///
/// HummingbirdLambda includes typealiases for lambdas that accept Event and Output types
/// for APIGateway: ``APIGatewayLambdaFunction``, APIGateway2: ``APIGatewayV2LambdaFunction``
/// and FunctionURLs: ``FunctionURLLambdaFunction``.
public struct LambdaFunction<Responder: HTTPResponder, Event: LambdaEvent, Output: LambdaOutput>: LambdaFunctionProtocol
where Responder.Context: InitializableFromSource<LambdaRequestContextSource<Event>> {
    /// routes requests to responders based on URI
    public let responder: Responder
    /// services attached to the application.
    public var services: [any Service]
    /// Logger
    public var logger: Logger
    /// Processes to be run before lambda is started
    public private(set) var processesRunBeforeLambdaStart: [@Sendable () async throws -> Void]

    /// Initialize LambdaFunction
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
        self.processesRunBeforeLambdaStart = []
    }

    /// Initialize LambdaFunction
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

    /// Add service to be managed by lambda function's ServiceGroup
    /// - Parameter services: list of services to be added
    public mutating func addServices(_ services: any Service...) {
        self.services.append(contentsOf: services)
    }

    /// Add a process to run before we kick off the lambda runtime service
    ///
    /// This is for processes that might need another Service running but need
    /// to run before the lambda has started processing requests. For example a
    /// database migration process might need the database connection pool running
    /// but should be finished before any request to the server can be made. Also
    /// there may be situations where you want another Service to have fully initialized
    /// before starting the lambda service.
    ///
    /// You can call `beforeLambdaStarts` multiple times and each process will still
    /// be called.
    ///
    /// - Parameter process: Process to run before server is started
    public mutating func beforeLambdaStarts(perform process: @escaping @Sendable () async throws -> Void) {
        self.processesRunBeforeLambdaStart.append(process)
    }
}

private struct LambdaRuntimeService<Handler: StreamingLambdaHandler>: Service {
    let runtime: LambdaRuntime<Handler>
    let logger: Logger

    func run() async throws {
        try await cancelWhenGracefulShutdown {
            try await self.runtime.run()
        }
        self.logger.info("Shutting down Hummingbird")
    }
}
