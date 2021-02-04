import AWSLambdaEvents
import AWSLambdaRuntime
import Hummingbird
import NIO

public protocol HBLambdaHandler: EventLoopLambdaHandler {
    init(_ app: HBApplication)
    func request(context: Lambda.Context, from: In) -> HBRequest
    func output(from: HBResponse) -> Out
    var extensions: HBExtensions<Self> { get set }
}

extension HBLambdaHandler {
    public init(context: Lambda.InitializationContext) {
        let application = HBApplication(eventLoopGroupProvider: .shared(context.eventLoop))
        self.init(application)
        self.application = application
        self.responder = application.constructResponder()
    }
    
    func shutdown(context: Lambda.ShutdownContext) -> EventLoopFuture<Void> {
        do {
            try self.application.shutdownApplication()
            return context.eventLoop.makeSucceededFuture(())
        } catch {
            return context.eventLoop.makeFailedFuture(error)
        }
    }
    
    public func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out> {
        self.responder.respond(to: request(context: context, from: event)).map { output(from: $0) }
    }
    
    public var application: HBApplication {
        get { self.extensions.get(\.application) }
        set { self.extensions.set(\.application, value: newValue) }
    }
    
    var responder: HBResponder {
        get { self.extensions.get(\.responder) }
        set { self.extensions.set(\.responder, value: newValue) }
    }
}
