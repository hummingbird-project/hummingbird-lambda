import AWSLambdaEvents
import AWSLambdaRuntimeCore
import Hummingbird
import NIOHTTP1
import NIO

extension HBLambda where In == APIGateway.Request {
    
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    public func request(context: Lambda.Context, application: HBApplication, from: In) -> HBRequest {
        let request = HBRequest(context: context, application: application, from: from)
        // store api gateway request so it is available in routes
        request.extensions.set(\.apiGatewayRequest, value: from)
        return request
    }
}

extension HBLambda where Out == APIGateway.Response {
    /// Specialization of HBLambda.request where `Out` is `APIGateway.Response`
    public func output(from response: HBResponse) -> Out {
        return response.apiResponse()
    }
}

// conform `APIGateway.Request` to `APIRequest` so we can use HBRequest.init(context:application:from)
extension APIGateway.Request: APIRequest { }

// conform `APIGateway.Response` to `APIResponse` so we can use HBResponse.apiReponse()
extension APIGateway.Response: APIResponse {
    init(
        statusCode: AWSLambdaEvents.HTTPResponseStatus,
        headers: AWSLambdaEvents.HTTPHeaders?,
        multiValueHeaders: HTTPMultiValueHeaders?,
        body: String?
    ) {
        self.init(statusCode: statusCode, headers: headers, multiValueHeaders: multiValueHeaders, body: body, isBase64Encoded: nil)
    }
}

extension HBRequest {
    /// `APIGateway.Request` that generated this `HBRequest`
    var apiGatewayRequest: APIGateway.Request {
        self.extensions.get(\.apiGatewayRequest)
    }
}
