import Logging

public protocol HBLambdaRequestContext<Event>: HBRequestContext {
    associatedtype Event

    init(_ event: Event, applicationContext: HBApplicationContext, source: some RequestContextSource, logger: Logger)
}