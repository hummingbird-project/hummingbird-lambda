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

extension HBLambda where Event == APIGatewayRequest {
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    public func request(context: LambdaContext, application: HBApplication, from: Event) throws -> HBRequest {
        var request = try HBRequest(context: context, application: application, from: from)
        // store api gateway request so it is available in routes
        request.extensions.set(\.apiGatewayRequest, value: from)
        return request
    }
}

extension HBLambda where Output == APIGatewayResponse {
    /// Specialization of HBLambda.request where `Out` is `APIGateway.Response`
    public func output(from response: HBResponse) -> Output {
        return response.apiResponse()
    }
}

// conform `APIGatewayRequest` to `APIRequest` so we can use HBRequest.init(context:application:from)
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

    var httpHeaders: HTTPHeaders {
        var headers = HTTPHeaders(self.headers.map { ($0.key, $0.value) })
        self.multiValueHeaders.forEach { multiValueHeader in
            headers.remove(name: multiValueHeader.key)
            for header in multiValueHeader.value {
                headers.add(name: multiValueHeader.key, value: header)
            }
        }
        return headers
    }
}

// conform `APIGatewayResponse` to `APIResponse` so we can use HBResponse.apiReponse()
extension APIGatewayResponse: APIResponse {}

extension HBRequest {
    /// `APIGateway.Request` that generated this `HBRequest`
    public var apiGatewayRequest: APIGatewayRequest {
        self.extensions.get(\.apiGatewayRequest)
    }
}
