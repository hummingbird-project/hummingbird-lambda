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

/// Protocol for Hummingbird Lambdas that use APIGateway
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
public protocol APIGatewayLambdaFunction: LambdaFunction where Event == APIGatewayRequest, Output == APIGatewayResponse {
    associatedtype Context = BasicLambdaRequestContext<APIGatewayRequest>
}

extension LambdaFunction where Event == APIGatewayRequest {
    /// Specialization of Lambda.request where `Event` is `APIGatewayRequest`
    public func request(context: LambdaContext, from: Event) throws -> Request {
        return try Request(context: context, from: from)
    }
}

extension LambdaFunction where Output == APIGatewayResponse {
    /// Specialization of Lambda.request where `Output` is `APIGatewayResponse`
    public func output(from response: Response) async throws -> Output {
        return try await response.apiResponse()
    }
}

// conform `APIGatewayRequest` to `APIRequest` so we can use Request.init(context:application:from)
extension APIGatewayRequest: APIRequest {
    var queryString: String {
        func urlPercentEncoded(_ string: String) -> String {
            return string.addingPercentEncoding(withAllowedCharacters: .urlQueryComponentAllowed) ?? string
        }
        var queryParams: [String] = []
        var queryStringParameters = self.queryStringParameters ?? [:]
        // go through list of multi value query string params first, removing any
        // from the single value list if they are found in the multi value list
        self.multiValueQueryStringParameters?.forEach { multiValueQuery in
            queryStringParameters[multiValueQuery.key] = nil
            queryParams += multiValueQuery.value.map { "\(urlPercentEncoded(multiValueQuery.key))=\(urlPercentEncoded($0))" }
        }
        queryParams += queryStringParameters.map {
            "\(urlPercentEncoded($0.key))=\(urlPercentEncoded($0.value))"
        }
        return queryParams.joined(separator: "&")
    }

    var httpHeaders: [(name: String, value: String)] {
        var headerValues = [(name: String, value: String)].init()
        var originalHeaders = self.headers
        headerValues.reserveCapacity(headers.count)
        for header in self.multiValueHeaders {
            originalHeaders[header.key] = nil
            for value in header.value {
                headerValues.append((name: header.key, value: value))
            }
        }
        headerValues.append(contentsOf: originalHeaders.map { (name: $0.key, value: $0.value) })
        return headerValues
    }
}

// conform `APIGatewayResponse` to `APIResponse` so we can use Response.apiReponse()
extension APIGatewayResponse: APIResponse {}
