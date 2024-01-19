import AWSLambdaRuntimeCore
import Foundation
import Hummingbird
import HummingbirdFoundation
import Logging
import NIOCore

/// The default Lambda request context
public struct HBBasicLambdaRequestContext<Event: Sendable>: HBLambdaRequestContext {
    /// The Event that triggered the Lambda
    public let event: Event

    public var coreContext: HBCoreRequestContext
    public var requestDecoder: JSONDecoder { .init() }
    public var responseEncoder: JSONEncoder { .init() }

    public init(_ event: Event, lambdaContext: LambdaContext) {
        self.event = event
        self.coreContext = .init(
            allocator: lambdaContext.allocator,
            logger: lambdaContext.logger
        )
    }
}
