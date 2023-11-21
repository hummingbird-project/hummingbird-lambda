import Logging
import NIOCore

public protocol HBLambdaRequestContext<Event>: HBBaseRequestContext {
    associatedtype Event

    init(_ event: Event, applicationContext: HBApplicationContext, eventLoop: EventLoop, allocator: ByteBufferAllocator, logger: Logger)
}