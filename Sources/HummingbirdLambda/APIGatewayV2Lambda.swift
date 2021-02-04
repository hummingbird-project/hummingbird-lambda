import AWSLambdaEvents
import AWSLambdaRuntimeCore
import Hummingbird
import NIOHTTP1
import NIO

extension HBLambda where In == APIGateway.V2.Request {
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    public func request(context: Lambda.Context, application: HBApplication, from: In) -> HBRequest {
        let request = HBRequest(context: context, application: application, from: from)
        // store api gateway v2 request so it is available in routes
        request.extensions.set(\.apiGatewayV2Request, value: from)
        return request
    }
}

extension HBLambda where Out == APIGateway.V2.Response {
    /// Specialization of HBLambda.request where `Out` is `APIGateway.Response`
    public func output(from response: HBResponse) -> Out {
        return response.apiResponse()
    }
}

// conform `APIGateway.V2.Request` to `APIRequest` so we can use HBRequest.init(context:application:from)
extension APIGateway.V2.Request: APIRequest {
    var path: String { context.http.path }
    var httpMethod: AWSLambdaEvents.HTTPMethod { context.http.method }
    var multiValueQueryStringParameters: [String : [String]]? { nil }
    var multiValueHeaders: HTTPMultiValueHeaders { [:] }
}

// conform `APIGateway.V2.Response` to `APIResponse` so we can use HBResponse.apiReponse()
extension APIGateway.V2.Response: APIResponse {
    init(
        statusCode: AWSLambdaEvents.HTTPResponseStatus,
        headers: AWSLambdaEvents.HTTPHeaders?,
        multiValueHeaders: HTTPMultiValueHeaders?,
        body: String?
    ) {
        self.init(statusCode: statusCode, headers: headers, multiValueHeaders: multiValueHeaders, body: body, isBase64Encoded: nil, cookies: nil)
    }
}

extension HBRequest {
    /// `APIGateway.V2.Request` that generated this `HBRequest`
    var apiGatewayV2Request: APIGateway.V2.Request {
        self.extensions.get(\.apiGatewayV2Request)
    }
}
