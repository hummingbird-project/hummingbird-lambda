import Hummingbird
import NIOCore

public struct HBLambdaRequestSource: RequestContextSource {
    public let eventLoop: EventLoop
    public let allocator: ByteBufferAllocator
    public var remoteAddress: SocketAddress? { nil }
}