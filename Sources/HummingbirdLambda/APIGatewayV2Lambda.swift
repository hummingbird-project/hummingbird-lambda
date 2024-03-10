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

/// Protocol for Hummingbird Lambdas that use APIGatewayV2
///
/// With this protocol you no longer need to set the `Event` and `Output`
/// associated values.
/// ```swift
/// struct MyLambda: APIGatewayLambda {
///     typealias Context = MyLambdaRequestContext
///
///     init(context: LambdaInitializationContext) {}
///
///     /// build responder that will create a response from a request
///     func buildResponder() -> some Responder<Context> {
///         let router = Router(context: Context.self)
///         router.get("hello") { _,_ in
///             "Hello"
///         }
///         return router.buildResponder()
///     }
/// }
/// ```
public protocol APIGatewayV2Lambda: Lambda where Event == APIGatewayV2Request, Output == APIGatewayV2Response {
    associatedtype Context = BasicLambdaRequestContext<APIGatewayV2Request>
}

extension Lambda where Event == APIGatewayV2Request {
    /// Specialization of Lambda.request where `Event` is `APIGatewayV2Request`
    public func request(context: LambdaContext, from: Event) throws -> Request {
        return try Request(context: context, from: from)
    }
}

extension Lambda where Output == APIGatewayV2Response {
    /// Specialization of Lambda.request where `Output` is `APIGatewayV2Response`
    public func output(from response: Response) async throws -> Output {
        return try await response.apiResponse()
    }
}

// conform `APIGatewayV2Request` to `APIRequest` so we can use Request.init(context:application:from)
extension APIGatewayV2Request: APIRequest {
    var path: String {
        return context.http.path
    }

    var httpMethod: AWSLambdaEvents.HTTPMethod { context.http.method }
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
