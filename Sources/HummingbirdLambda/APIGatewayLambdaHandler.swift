import AWSLambdaEvents
import AWSLambdaRuntime
import Hummingbird
import NIOHTTP1
import NIO

extension HBLambdaHandler where In == APIGateway.Request, Out == APIGateway.Response {
    public func request(context: Lambda.Context, from: APIGateway.Request) -> HBRequest {
        let headers = NIOHTTP1.HTTPHeaders(from.headers.map { ($0.key, $0.value) })
        let head = HTTPRequestHead(
            version: .init(major: 2, minor: 0),
            method: .init(rawValue: from.httpMethod.rawValue),
            uri: from.path,
            headers: headers
        )
        let body: ByteBuffer?
        if let apiGatewayBody = from.body {
            body = context.allocator.buffer(string: apiGatewayBody)
        } else {
            body = nil
        }
        return HBRequest(
            head: head,
            body: .byteBuffer(body),
            application: self.application,
            eventLoop: context.eventLoop,
            allocator: context.allocator
        )
    }
    
    public func output(from response: HBResponse) -> APIGateway.Response {
        let headers = HTTPHeaders(response.headers.map { ($0.name, $0.value) }) { first, _ in first}
        var body: String? = nil
        if case .byteBuffer(let buffer) = response.body {
            body = String(buffer: buffer)
        }
        return .init(
            statusCode: .init(code: response.status.code),
            headers: headers,
            multiValueHeaders: nil,
            body: body
        )
    }
}
