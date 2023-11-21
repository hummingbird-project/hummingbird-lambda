import Hummingbird
import NIOCore
import Logging

public struct HBBasicLambdaRequestContext<Event: Sendable>: HBLambdaRequestContext {
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