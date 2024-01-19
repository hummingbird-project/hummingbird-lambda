//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
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
    /// Specialization of HBLambda.request where `In` is `APIGatewayV2Request`
    public func request(context: LambdaContext, from: Event) throws -> HBRequest {
        return try HBRequest(context: context, from: from)
    }
}

extension HBLambda where Output == APIGatewayV2Response {
    /// Specialization of HBLambda.request where `Out` is `APIGatewayV2Response`
    public func output(from response: HBResponse) async throws -> Output {
        return try await response.apiResponse()
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
