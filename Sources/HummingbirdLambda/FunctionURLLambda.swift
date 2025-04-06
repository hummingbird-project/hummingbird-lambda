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

/// Protocol for Hummingbird Lambdas that use FunctionURL
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
public protocol FunctionURLLambdaFunction: LambdaFunction where Event == FunctionURLRequest, Output == FunctionURLResponse {
    associatedtype Context = BasicLambdaRequestContext<FunctionURLRequest>
}

extension LambdaFunction where Event == FunctionURLRequest {
    /// Specialization of Lambda.request where `Event` is `FunctionURLRequest`
    public func request(context: LambdaContext, from: Event) throws -> Request {
        try Request(context: context, from: from)
    }
}

extension LambdaFunction where Output == FunctionURLResponse {
    /// Specialization of Lambda.request where `Output` is `FunctionURLResponse`
    public func output(from response: Response) async throws -> Output {
        try await response.apiResponse()
    }
}

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
        self.init(statusCode: statusCode, headers: headers, body: body, cookies: nil, isBase64Encoded: isBase64Encoded)
    }
}
