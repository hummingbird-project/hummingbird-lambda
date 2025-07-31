import AWSLambdaRuntime
import Hummingbird
import Logging
import NIOCore

public struct LambdaRequestContextSource<Event>: RequestContextSource {
    public init(event: Event, lambdaContext: LambdaContext) {
        self.event = event
        self.lambdaContext = lambdaContext
    }

    public let event: Event
    public let lambdaContext: LambdaContext

    public var logger: Logger { self.lambdaContext.logger }
}

/// A Request Context that is initialized with the Event that triggered the Lambda
///
/// All Hummingbird Lambdas require that your request context conforms to
/// LambdaRequestContext`. By default ``LambdaFunction`` will use ``BasicLambdaRequestContext``
/// for a request context. To get ``LambdaFunction`` to use a custom context you need to set the
/// `Context` associatedtype.
public protocol LambdaRequestContext<Event>: RequestContext where Source == LambdaRequestContextSource<Event> {
    associatedtype Event
}
