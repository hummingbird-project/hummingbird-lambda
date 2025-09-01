//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import Hummingbird
import NIOCore
import NIOHTTP1

/// Typealias for Lambda function triggered by APIGatewayV2
///
/// ```swift
/// let router = Router(context: BasicLambdaRequestContext<APIGatewayV2Request>.self)
/// router.get { request, context in
///     "Hello!"
/// }
/// let lambda = APIGatewayV2LambdaFunction(router: router)
/// try await lambda.runService()
/// ```
public typealias APIGatewayV2LambdaFunction<Responder: HTTPResponder> = LambdaFunction<Responder, APIGatewayV2Request, APIGatewayV2Response>
where Responder.Context: InitializableFromSource<LambdaRequestContextSource<APIGatewayV2Request>>

// conform `APIGatewayV2Request` to `APIRequest` so we can use Request.init(context:application:from)
extension APIGatewayV2Request: APIRequest {
    var path: String {
        context.http.path
    }

    var httpMethod: HTTPRequest.Method { context.http.method }
    var queryString: String { self.rawQueryString }
    var httpHeaders: [(name: String, value: String)] {
        self.headers.flatMap { header in
            let headers = header.value
                .split(separator: ",")
                .map { (name: header.key, value: String($0.drop(while: \.isWhitespace))) }
            return headers
        }
    }
}

// conform `APIGatewayV2Response` to `APIResponse` so we can use Response.apiReponse()
extension APIGatewayV2Response: APIResponse {
    package init(
        statusCode: HTTPResponse.Status,
        headers: AWSLambdaEvents.HTTPHeaders?,
        multiValueHeaders: HTTPMultiValueHeaders?,
        body: String?,
        isBase64Encoded: Bool?
    ) {
        precondition(multiValueHeaders == nil || multiValueHeaders?.isEmpty == true, "Multi value headers are unavailable in APIGatewayV2")
        self.init(statusCode: statusCode, headers: headers, body: body, isBase64Encoded: isBase64Encoded, cookies: nil)
    }
}
