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
import Hummingbird
import NIOCore
import NIOHTTP1

/// Typealias for Lambda function triggered by APIGateway
///
/// ```swift
/// let router = Router(context: BasicLambdaRequestContext<APIGatewayRequest>.self)
/// router.get { request, context in
///     "Hello!"
/// }
/// let lambda = APIGatewayLambdaFunction(router: router)
/// try await lambda.runService()
/// ```
public typealias APIGatewayLambdaFunction<Responder: HTTPResponder> = LambdaFunction<Responder, APIGatewayRequest, APIGatewayResponse>
where Responder.Context: InitializableFromSource<LambdaRequestContextSource<APIGatewayRequest>>

// conform `APIGatewayRequest` to `APIRequest` so we can use Request.init(context:application:from)
extension APIGatewayRequest: APIRequest {
    var queryString: String {
        func urlPercentEncoded(_ string: String) -> String {
            return string.addingPercentEncoding(withAllowedCharacters: .urlQueryComponentAllowed) ?? string
        }
        var queryParams: [String] = []
        var queryStringParameters = self.queryStringParameters
        // go through list of multi value query string params first, removing any
        // from the single value list if they are found in the multi value list
        for (key, value) in self.multiValueQueryStringParameters {
            queryStringParameters[key] = nil
            queryParams += value.map { "\(urlPercentEncoded(key))=\(urlPercentEncoded($0))" }
        }
        queryParams += queryStringParameters.map {
            "\(urlPercentEncoded($0.key))=\(urlPercentEncoded($0.value))"
        }
        return queryParams.joined(separator: "&")
    }

    var httpHeaders: [(name: String, value: String)] {
        var headerValues = [(name: String, value: String)]()
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
