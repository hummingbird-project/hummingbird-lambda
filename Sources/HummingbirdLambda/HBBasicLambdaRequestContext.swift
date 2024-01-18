import Foundation
import Hummingbird
import NIOCore
import Logging
import AWSLambdaRuntimeCore

/// The default Lambda request context
public struct HBBasicLambdaRequestContext<Event: Sendable>: HBLambdaRequestContext {
    /// The Event that triggered the Lambda
    public let event: Event
    
    public var coreContext: HBCoreRequestContext

    public init(_ event: Event, lambdaContext: LambdaContext) {
        self.event = event
        self.coreContext = .init(
            requestDecoder: JSONDecoder(),
            responseEncoder: JSONEncoder(), 
            allocator: lambdaContext.allocator,
            logger: lambdaContext.logger
        )
    }
}