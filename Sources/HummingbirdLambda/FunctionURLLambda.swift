//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import AWSLambdaEvents
import Hummingbird
import NIOCore
import NIOHTTP1

/// Typealias for Lambda function triggered by function URL
///
/// ```swift
/// let router = Router(context: BasicLambdaRequestContext<FunctionURLRequest>.self)
/// router.get { request, context in
///     "Hello!"
/// }
/// let lambda = FunctionURLLambdaFunction(router: router)
/// try await lambda.runService()
/// ```
public typealias FunctionURLLambdaFunction<Responder: HTTPResponder> = LambdaFunction<Responder, FunctionURLRequest, FunctionURLResponse>
where Responder.Context: InitializableFromSource<LambdaRequestContextSource<FunctionURLRequest>>

// conform `FunctionURLRequest` to `APIRequest` so we can use Request.init(context:application:from)
extension FunctionURLRequest: APIRequest {
    var path: String {
        requestContext.http.path
    }

    var httpMethod: HTTPRequest.Method { requestContext.http.method }
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

// conform `FunctionURLResponse` to `APIResponse` so we can use Response.apiReponse()
extension FunctionURLResponse: APIResponse {
    package init(
        statusCode: HTTPResponse.Status,
        headers: AWSLambdaEvents.HTTPHeaders?,
        multiValueHeaders: HTTPMultiValueHeaders?,
        body: String?,
        isBase64Encoded: Bool?
    ) {
        precondition(multiValueHeaders == nil || multiValueHeaders?.isEmpty == true, "Multi value headers are unavailable in FunctionURL")
        self.init(statusCode: statusCode, headers: headers, body: body, isBase64Encoded: isBase64Encoded, cookies: nil)
    }
}
