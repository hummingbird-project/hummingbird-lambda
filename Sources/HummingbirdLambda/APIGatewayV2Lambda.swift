//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
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
    public func request(context: LambdaContext, from: Event) throws -> HBRequest {
        return try HBRequest(context: context, from: from)
    }
}

extension HBLambda where Output == APIGatewayV2Response {
    /// Specialization of HBLambda.request where `Out` is `APIGateway.Response`
    public func output(from response: HBResponse) async throws -> Output {
        return try await response.apiResponse()
    }
}

extension HBLambda where Event == APIGatewayV2Request, Output == APIGatewayV2Response, Context == APIGatewayV2RequestContext {
    public func requestContext(
        coreContext: HBCoreRequestContext,
        context: LambdaContext,
        from: Event
    ) throws -> APIGatewayV2RequestContext {
        var context = APIGatewayV2RequestContext(coreContext: coreContext)
        context.apiGatewayV2Request = from
        return context
    }
}

// conform `APIGatewayV2Request` to `APIRequest` so we can use HBRequest.init(context:application:from)
extension APIGatewayV2Request: APIRequest {
    var path: String {
        return context.http.path
    }

    var httpMethod: AWSLambdaEvents.HTTPMethod { context.http.method }
    var multiValueQueryStringParameters: [String: [String]]? { nil }
    var multiValueHeaders: HTTPMultiValueHeaders { [:] }
}

// conform `APIGatewayV2Response` to `APIResponse` so we can use HBResponse.apiReponse()
extension APIGatewayV2Response: APIResponse {
    init(
        statusCode: AWSLambdaEvents.HTTPResponseStatus,
        headers: AWSLambdaEvents.HTTPHeaders?,
        multiValueHeaders: HTTPMultiValueHeaders?,
        body: String?,
        isBase64Encoded: Bool?
    ) {
        precondition(multiValueHeaders == nil || multiValueHeaders?.count == 0, "Multi value headers are unavailable in APIGatewayV2")
        self.init(statusCode: statusCode, headers: headers, body: body, isBase64Encoded: isBase64Encoded, cookies: nil)
    }
}

public struct APIGatewayV2RequestContext: HBRequestContext {
    public var coreContext: HBCoreRequestContext
    public var apiGatewayV2Request: APIGatewayV2Request?

    public init(coreContext: HBCoreRequestContext) {
        self.coreContext = coreContext
        self.apiGatewayV2Request = nil
    }
}
