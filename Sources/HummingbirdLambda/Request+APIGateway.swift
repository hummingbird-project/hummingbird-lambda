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
import HTTPTypes
import Hummingbird
import NIOCore

protocol APIRequest {
    var path: String { get }
    var httpMethod: AWSLambdaEvents.HTTPMethod { get }
    var queryString: String { get }
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
        if from.queryString.count > 0 {
            uri += "?\(from.queryString)"
        }
        // construct headers
        var authority: String?
        let headers = HTTPFields(headers: from.headers, multiValueHeaders: from.multiValueHeaders, authority: &authority)

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
                scheme: "https",
                authority: authority,
                path: uri,
                headerFields: headers
            ),
            body: body.map { .init(buffer: $0) } ?? .init(buffer: .init())
        )
    }
}

extension HTTPFields {
    /// Initialize HTTPFields from HTTP headers and multivalue headers in an APIGateway request
    /// - Parameters:
    ///   - headers: headers
    ///   - multiValueHeaders: multi-value headers
    ///   - authority: reference to authority string
    init(headers: AWSLambdaEvents.HTTPHeaders, multiValueHeaders: HTTPMultiValueHeaders, authority: inout String?) {
        self.init()
        self.reserveCapacity(headers.count)
        var firstHost = true
        for (name, values) in multiValueHeaders {
            if firstHost, name.lowercased() == "host" {
                if let value = values.first {
                    firstHost = false
                    authority = value
                    continue
                }
            }
            if let fieldName = HTTPField.Name(name) {
                for value in values {
                    self.append(HTTPField(name: fieldName, value: value))
                }
            }
        }
        for (name, value) in headers {
            if firstHost, name.lowercased() == "host" {
                firstHost = false
                authority = value
                continue
            }
            if let fieldName = HTTPField.Name(name) {
                if self[fieldName] != nil { continue }
                self.append(HTTPField(name: fieldName, value: value))
            }
        }
    }
}

extension CharacterSet {
    static var urlQueryComponentAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=")
        return cs
    }()
}
