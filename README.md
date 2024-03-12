# Hummingbird Lambda

Run Hummingbird inside an AWS Lambda

## Usage

Create struct conforming to `Lambda`. Setup your application in the `init` function: add your middleware, add route handlers etc

```swift
@main
struct MyHandler: Lambda {
    // define input and output
    typealias Event = APIGatewayRequest
    typealias Output = APIGatewayResponse
    
    init(_ app: Application) {
        app.middleware.add(HBLogRequestsMiddleware(.debug))
        app.router.get("hello") { _, _ in
            return "Hello"
        }
    }
}
```

The `Event` and `Output` types define your input and output objects. If you are using an `APIGateway` REST interface to invoke your Lambda then set these to `APIGatewayRequest` and `APIGatewayResponse` respectively. If you are using an `APIGateway` HTML interface then set these to `APIGatewayV2Request` and `APIGatewayV2Response`. If you are using any other `Event`/`Output` types you will need to implement the `request(context:application:from:)` and `output(from:)` methods yourself.
