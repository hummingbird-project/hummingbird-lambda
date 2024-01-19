//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntime
import ExtrasBase64
import Foundation
import Hummingbird
import NIOCore
import NIOHTTP1

protocol APIRequest {
    var path: String { get }
    var httpMethod: AWSLambdaEvents.HTTPMethod { get }
    var queryStringParameters: [String: String]? { get }
    var multiValueQueryStringParameters: [String: [String]]? { get }
    var headers: AWSLambdaEvents.HTTPHeaders { get }
    var multiValueHeaders: HTTPMultiValueHeaders { get }
    var body: String? { get }
    var isBase64Encoded: Bool { get }
}

extension HBRequest {
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    init(context: LambdaContext, from: some APIRequest) throws {
        func urlPercentEncoded(_ string: String) -> String {
            return string.addingPercentEncoding(withAllowedCharacters: .urlQueryComponentAllowed) ?? string
        }

        guard let method = HTTPRequest.Method(from.httpMethod.rawValue) else {
            throw HBHTTPError(.badRequest)
        }

        // construct URI with query parameters
        var uri = from.path
        var queryParams: [String] = []
        var queryStringParameters = from.queryStringParameters ?? [:]
        // go through list of multi value query string params first, removing any
        // from the single value list if they are found in the multi value list
        from.multiValueQueryStringParameters?.forEach { multiValueQuery in
            queryStringParameters[multiValueQuery.key] = nil
            queryParams += multiValueQuery.value.map { "\(urlPercentEncoded(multiValueQuery.key))=\(urlPercentEncoded($0))" }
        }
        queryParams += queryStringParameters.map {
            "\(urlPercentEncoded($0.key))=\(urlPercentEncoded($0.value))"
        }
        if queryParams.count > 0 {
            uri += "?\(queryParams.joined(separator: "&"))"
        }
        // construct headers
        var headers = NIOHTTP1.HTTPHeaders(from.headers.map { ($0.key, $0.value) })
        from.multiValueHeaders.forEach { multiValueHeader in
            headers.remove(name: multiValueHeader.key)
            for header in multiValueHeader.value {
                headers.add(name: multiValueHeader.key, value: header)
            }
        }
        // get body
        let body: ByteBuffer?
        if let apiGatewayBody = from.body {
            if from.isBase64Encoded {
                let base64Decoded = try apiGatewayBody.base64decoded()
                body = context.allocator.buffer(bytes: base64Decoded)
            } else {
                body = context.allocator.buffer(string: apiGatewayBody)
            }
        } else {
            body = nil
        }

        self.init(
            head: .init(
                method: method,
                scheme: nil,
                authority: nil,
                path: uri
            ),
            body: body.map(HBRequestBody.byteBuffer) ?? .byteBuffer(.init())
        )
    }
}

extension CharacterSet {
    static var urlQueryComponentAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=")
        return cs
    }()
}
