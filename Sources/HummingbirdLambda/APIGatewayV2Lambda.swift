import AWSLambdaEvents
import AWSLambdaRuntimeCore
import Hummingbird
import NIOHTTP1
import NIO

extension HBLambda where In == APIGateway.V2.Request {
    
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    public func request(context: Lambda.Context, application: HBApplication, from: APIGateway.Request) -> HBRequest {
        var uri = from.path
        if let queryStringParameters = from.queryStringParameters {
            let queryParams = queryStringParameters.map { "\($0.key)=\($0.value)"}
            if queryParams.count > 0 {
                uri += "?\(queryParams.joined(separator: "&"))"
            }
        }
        let headers = NIOHTTP1.HTTPHeaders(from.headers.map { ($0.key, $0.value) })
        let head = HTTPRequestHead(
            version: .init(major: 2, minor: 0),
            method: .init(rawValue: from.httpMethod.rawValue),
            uri: uri,
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
            application: application,
            eventLoop: context.eventLoop,
            allocator: context.allocator
        )
    }
}

extension HBLambda where Out == APIGateway.V2.Response {
    /// Specialization of HBLambda.request where `Out` is `APIGateway.Response`
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
