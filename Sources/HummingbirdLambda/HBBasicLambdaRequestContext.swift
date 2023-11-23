import Hummingbird
import NIOCore
import Logging
import AWSLambdaRuntimeCore

/// The default Lambda request context
public struct HBBasicLambdaRequestContext<Event: Sendable>: HBLambdaRequestContext {
    /// The Event that triggered the Lambda
    public let event: Event
    
    public var coreContext: HBCoreRequestContext

    public init(
        _ event: Event,
        applicationContext: HBApplicationContext,
        lambdaContext: LambdaContext
    ) {
        self.event = event
        self.coreContext = .init(
            applicationContext: applicationContext,
            eventLoop: lambdaContext.eventLoop,
            allocator: lambdaContext.allocator,
            logger: lambdaContext.logger
        )
    }
}