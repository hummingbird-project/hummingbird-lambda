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
            + self.cookies.map { cookieValue in
                (name: "cookie", value: cookieValue)
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
        let setCookieHeaderName = "set-cookie"
        
        func isSetCookieHeader(_ name: String) -> Bool {
            name.lowercased() == setCookieHeaderName
        }
        
        var outputHeaders = headers ?? [:]
        var cookies: [String] = []
        
        // Move any single Set-Cookie header into the APIGatewayV2 cookies array.
        var cookieKeys: [String] = []
        for (name, value) in outputHeaders {
            if isSetCookieHeader(name) {
                cookies.append(value)
                cookieKeys.append(name)
            }
        }
        // Remove set-cookie from outputHeaders
        for key in cookieKeys {
            outputHeaders.removeValue(forKey: key)
        }
    
        // Move any multi-value Set-Cookie headers into the APIGatewayV2 cookies array.
        // For other repeated headers, fold them into a single comma-separated value.
        if let multiValueHeaders {
            for (name, values) in multiValueHeaders {
                if isSetCookieHeader(name) {
                    cookies.append(contentsOf: values)
                } else {
                    outputHeaders[name] = values.joined(separator: ",")
                }
            }
        }
                
        self.init(
            statusCode: statusCode,
            headers: outputHeaders.isEmpty ? nil : outputHeaders,
            body: body,
            isBase64Encoded: isBase64Encoded,
            cookies: cookies.isEmpty ? nil : cookies
        )
    }
}
