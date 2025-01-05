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

public protocol LambdaEvent: Decodable {
    func request(context: LambdaContext) throws -> Request
}

public protocol LambdaOutput: Encodable {
    init(from: Response) async throws
}

/// Protocol for an Application. Brings together all the components of Hummingbird together
public protocol LambdaFunctionProtocol: Service where Responder.Context: InitializableFromSource<LambdaRequestContextSource<Event>> {
    /// Event that triggers the lambda
    associatedtype Event: LambdaEvent
    /// Output of lambda
    associatedtype Output: LambdaOutput
    /// Responder that generates a response from a requests and context
    associatedtype Responder: HTTPResponder
    /// Context passed with Request to responder
    typealias Context = Responder.Context

    /// Build the responder
    var responder: Responder { get async throws }
    /// Logger
    var logger: Logger { get }
    /// services attached to the application.
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
    /// Construct application and run it
    public func run() async throws {
        let responder = try await self.responder
        let runtime = LambdaRuntime { (event: Event, context: LambdaContext) -> Output in
            let request = try event.request(context: context)
            let context = Responder.Context(source: .init(event: event, lambdaContext: context))
            let response = try await responder.respond(to: request, context: context)
            return try await .init(from: response)
        }
        let services: [any Service] = self.services + [runtime]
        let serviceGroup = ServiceGroup(
            configuration: .init(services: services, logger: self.logger)
        )
        try await serviceGroup.run()
    }

    /// Helper function that runs application inside a ServiceGroup which will gracefully
    /// shutdown on signals SIGINT, SIGTERM
    public func runService(gracefulShutdownSignals: [UnixSignal] = [.sigterm, .sigint]) async throws {
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [self],
                gracefulShutdownSignals: gracefulShutdownSignals,
                logger: self.logger
            )
        )
        try await serviceGroup.run()
    }
}

public struct LambdaFunction<Responder: HTTPResponder, Event: LambdaEvent, Output: LambdaOutput>: LambdaFunctionProtocol
where Responder.Context: InitializableFromSource<LambdaRequestContextSource<Event>> {
    /// routes requests to responders based on URI
    public let responder: Responder
    /// services attached to the application.
    public var services: [any Service]
    /// Logger
    public var logger: Logger

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

    ///  Add service to be managed by application ServiceGroup
    /// - Parameter services: list of services to be added
    public mutating func addServices(_ services: any Service...) {
        self.services.append(contentsOf: services)
    }
}

/*
/// Protocol for Hummingbird Lambdas.
///
/// Defines the `Event` and `Output` types, how you convert from `Event` to ``HummingbirdCore/Request``
/// and ``HummingbirdCore/Response`` to `Output`. Create a type conforming to this protocol and tag it
/// with `@main`.
/// ```swift
/// struct MyLambda: LambdaFunction {
///     typealias Event = APIGatewayRequest
///     typealias Output = APIGatewayResponse
///     typealias Context = MyLambdaRequestContext // must conform to `LambdaRequestContext`
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
/// - SeeAlso: ``APIGatewayLambdaFunction`` and ``APIGatewayV2LambdaFunction`` for specializations of this protocol.
public protocol LambdaFunction: Sendable {
    /// Event that triggers the lambda
    associatedtype Event: Decodable
    /// Request context
    associatedtype Context: InitializableFromSource<LambdaRequestContextSource<Event>> = BasicLambdaRequestContext<Event>
    /// Output of lambda
    associatedtype Output: Encodable
    /// HTTP Responder
    associatedtype Responder: HTTPResponder<Context>

    func buildResponder() -> Responder

    /// Initialize application.
    init(context: LambdaInitializationContext) async throws

    /// Called when Lambda is terminating. This is where you can cleanup any resources
    func shutdown() async throws

    /// Convert from `In` type to `Request`
    /// - Parameters:
    ///   - context: Lambda context
    ///   - from: input type
    func request(context: LambdaContext, from: Event) throws -> Request

    /// Convert from `Response` to `Out` type
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
        LambdaFunctionHandler<Self>.main()
    }

    public func shutdown() async throws {}
}
*/
