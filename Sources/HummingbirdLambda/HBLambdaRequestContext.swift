public protocol HBLambdaRequestContext<Event>: HBRequestContext {
    associatedtype Event

    init(_ event: Event, coreContext: HBCoreRequestContext)
}