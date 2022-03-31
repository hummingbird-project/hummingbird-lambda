# Hummingbird Lambda

Run Hummingbird inside an AWS Lambda

## Usage

Create struct conforming to `HBLambda`. Setup your application in the `init` function: add your middleware, add route handlers etc

```swift
struct MyHandler: HBLambda {
    // define input and output
    typealias Event = APIGateway.Request
    typealias Output = APIGateway.Response
    
    init(_ app: HBApplication) {
        app.middleware.add(HBLogRequestsMiddleware(.debug))
        app.router.get("hello") { _ in
            return "Hello"
        }
    }
}
HBLambdaHandler<MyHandler>().main()
```

The `Event` and `Output` types define your input and output objects. If you are using an `APIGateway` REST interface to invoke your Lambda then set these to `APIGateway.Request` and `APIGateway.Response` respectively. If you are using an `APIGateway` HTML interface then set these to `APIGateway.V2.Request` and `APIGateway.V2.Response`. If you are using any other `Event`/`Output` types you will need to implement the `request(context:application:from:)` and `output(from:)` methods yourself.
