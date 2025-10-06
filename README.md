# Hummingbird Lambda

Run Hummingbird inside an AWS Lambda

## Usage

```swift
typealias AppRequestContext = BasicLambdaRequestContext<APIGatewayV2Request>

// Create router and add a single route returning "Hello" in its body
let router = Router(context: AppRequestContext.self)
router.get("hello") { _, _ in
    return "Hello"
}
// create lambda using router and run
let lambda = APIGatewayV2LambdaFunction(router: router)
try await lambda.runService()
```

## Documentation

Reference documentation for Hummingbird Lambda can be found, alongside documentation for Hummingbird on the [Hummingbird documentation website](https://docs.hummingbird.codes/2.0/documentation/hummingbirdlambda).
