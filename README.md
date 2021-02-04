# Hummingbird Lambda

Run Hummingbird inside an AWS Lambda

## Usage

```swift
Lambda.run { context in
    return HBLambdaHandler<MyHandler>(context: context)
}

struct MyHandler: HBLambda {
    // define input and output
    typealias In = APIGateway.Request
    typealias Out = APIGateway.Response
    
    init(_ app: HBApplication) {
        app.router.get("hello") { _ in
            return "Hello"
        }
    }
}
```
