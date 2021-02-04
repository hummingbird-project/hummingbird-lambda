# Hummingbird Lambda

Run Hummingbird inside an AWS Lambda

## Usage

```swift
Lambda.run { context in
    return MyHandler(context: context)
}

struct MyHandler: HBLambdaHandler {
    // define input and output
    typealias In = APIGateway.Request
    typealias Out = APIGateway.Response
    // required for protocol
    var extensions: HBExtensions<MyHandler>
    
    init(_ app: HBApplication) {
        self.extensions = .init()
        app.router.get("hello") { _ in
            return "Hello"
        }
    }
}
```
