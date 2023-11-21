import Logging
import NIOCore

/// A Request Context that contains the Event that triggered the Lambda
public protocol HBLambdaRequestContext<Event>: HBBaseRequestContext {
    /// The type of event that can trigger the Lambda
    associatedtype Event

    init(_ event: Event, applicationContext: HBApplicationContext, eventLoop: EventLoop, allocator: ByteBufferAllocator, logger: Logger)
}