import Hummingbird
import NIOCore
import Logging

/// The default Lambda request context
public struct HBBasicLambdaRequestContext<Event: Sendable>: HBLambdaRequestContext {
    /// The Event that triggered the Lambda
    public let event: Event
    
    public var coreContext: HBCoreRequestContext

    public init(
        _ event: Event,
        applicationContext: HBApplicationContext,
        eventLoop: EventLoop,
        allocator: ByteBufferAllocator,
        logger: Logger
    ) {
        self.event = event
        self.coreContext = .init(
            applicationContext: applicationContext,
            eventLoop: eventLoop,
            allocator: allocator,
            logger: logger
        )
    }
}