//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntimeCore
import Hummingbird
import NIOCore
import NIOHTTP1

extension HBLambda where Event == APIGatewayV2Request {
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    public func request(context: LambdaContext, application: HBApplication, from: Event) throws -> HBRequest {
        var request = try HBRequest(context: context, application: application, from: from)
        // store api gateway v2 request so it is available in routes
        request.extensions.set(\.apiGatewayV2Request, value: from)
        return request
    }
}

extension HBLambda where Output == APIGatewayV2Response {
    /// Specialization of HBLambda.request where `Out` is `APIGateway.Response`
    public func output(from response: HBResponse) -> Output {
        return response.apiResponse()
    }
}

// conform `APIGateway.V2.Request` to `APIRequest` so we can use HBRequest.init(context:application:from)
extension APIGatewayV2Request: APIRequest {
    var path: String {
        // use routeKey as path has stage in it
        return String(routeKey.split(separator: " ", maxSplits: 1).last!)
    }

    var httpMethod: AWSLambdaEvents.HTTPMethod { context.http.method }
    var multiValueQueryStringParameters: [String: [String]]? { nil }
    var multiValueHeaders: HTTPMultiValueHeaders { [:] }
}

// conform `APIGateway.V2.Response` to `APIResponse` so we can use HBResponse.apiReponse()
extension APIGatewayV2Response: APIResponse {
    init(
        statusCode: AWSLambdaEvents.HTTPResponseStatus,
        headers: AWSLambdaEvents.HTTPHeaders?,
        multiValueHeaders: HTTPMultiValueHeaders?,
        body: String?,
        isBase64Encoded: Bool?
    ) {
        precondition(multiValueHeaders == nil, "Multi value headers are unavailable in APIGatewayV2")
        self.init(statusCode: statusCode, headers: headers, body: body, isBase64Encoded: isBase64Encoded, cookies: nil)
    }
}

extension HBRequest {
    /// `APIGateway.V2.Request` that generated this `HBRequest`
    public var apiGatewayV2Request: APIGatewayV2Request {
        self.extensions.get(\.apiGatewayV2Request)
    }
}
