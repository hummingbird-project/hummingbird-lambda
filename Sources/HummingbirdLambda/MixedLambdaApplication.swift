import Hummingbird
import AWSLambdaRuntime
import Logging
import NIOCore
import NIOPosix

public enum HBBasicMixedLambdaContext<Event: Sendable>: HBLambdaRequestContext, HBRequestContext {
    case lambda(HBBasicLambdaRequestContext<Event>)
    case http(HBBasicRequestContext)

    public var coreContext: HBCoreRequestContext {
        get {
            switch self {
            case .lambda(let context):
                return context.coreContext
            case .http(let context):
                return context.coreContext
            }
        }
        set {
            switch self {
            case .lambda(var context):
                context.coreContext = newValue
                self = .lambda(context)
            case .http(var context):
                context.coreContext = newValue
                self = .http(context)
            }
        }
    }

    public init(_ event: Event, lambdaContext: LambdaContext) {
        self = .lambda(HBBasicLambdaRequestContext(event, lambdaContext: lambdaContext))
    }

    public init(allocator: ByteBufferAllocator, logger: Logger) {
        self = .http(HBBasicRequestContext(allocator: allocator, logger: logger))
    }

    public init(channel: any Channel, logger: Logger) {
        self = .http(HBBasicRequestContext(channel: channel, logger: logger))
    }
}

public protocol HBMixedLambdaApplication: HBLambda, HBApplicationProtocol where Context: HBLambdaRequestContext<Event> & HBRequestContext {
    static var hostingMode: HostingMode { get async throws }

    init()
}

public enum HostingMode {
    case lambda, server
}

extension HBMixedLambdaApplication {
    public static func main() async throws {
        switch try await Self.hostingMode {
        case .lambda:
            HBLambdaHandler<Self>.main()
        case .server:
            try await Self().runService()
        }
    }

    public var responder: Responder { buildResponder() }
}