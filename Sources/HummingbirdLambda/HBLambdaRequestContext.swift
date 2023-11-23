import Logging
import NIOCore
import AWSLambdaRuntimeCore

/// A Request Context that contains the Event that triggered the Lambda
public protocol HBLambdaRequestContext<Event>: HBBaseRequestContext {
    /// The type of event that can trigger the Lambda
    associatedtype Event

    init(_ event: Event, applicationContext: HBApplicationContext, lambdaContext: LambdaContext)
}