//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2025 the Hummingbird authors
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
import HTTPTypes
import Hummingbird
import NIOCore

/// Protocol for APIGateway/APIGatewayV2 requests
protocol APIRequest: LambdaEvent {
    var path: String { get }
    var httpMethod: HTTPRequest.Method { get }
    var queryString: String { get }
    var httpHeaders: [(name: String, value: String)] { get }
    var body: String? { get }
    var isBase64Encoded: Bool { get }
}

extension APIRequest {
    public func request(context: LambdaContext) throws -> Request {
        // construct URI with query parameters
        var uri = self.path
        if self.queryString.count > 0 {
            uri += "?\(self.queryString)"
        }
        // construct headers
        var authority: String?
        let headers = HTTPFields(headers: self.httpHeaders, authority: &authority)

        // get body
        let body: ByteBuffer?
        if let apiGatewayBody = self.body {
            if self.isBase64Encoded {
                let base64Decoded = try apiGatewayBody.base64decoded()
                body = ByteBuffer(bytes: base64Decoded)
            } else {
                body = ByteBuffer(string: apiGatewayBody)
            }
        } else {
            body = nil
        }

        return Request(
            head: .init(
                method: self.httpMethod,
                scheme: "https",
                authority: authority,
                path: uri,
                headerFields: headers
            ),
            body: body.map(RequestBody.init) ?? RequestBody(buffer: .init())
        )
    }
}

extension Request {
    /// Specialization of Lambda.request where `In` is `APIGateway.Request`
    init(context: LambdaContext, from: some APIRequest) throws {
        // construct URI with query parameters
        var uri = from.path
        if from.queryString.count > 0 {
            uri += "?\(from.queryString)"
        }
        // construct headers
        var authority: String?
        let headers = HTTPFields(headers: from.httpHeaders, authority: &authority)

        // get body
        let body: ByteBuffer?
        if let apiGatewayBody = from.body {
            if from.isBase64Encoded {
                let base64Decoded = try apiGatewayBody.base64decoded()
                body = ByteBuffer(bytes: base64Decoded)
            } else {
                body = ByteBuffer(string: apiGatewayBody)
            }
        } else {
            body = nil
        }

        self.init(
            head: .init(
                method: from.httpMethod,
                scheme: "https",
                authority: authority,
                path: uri,
                headerFields: headers
            ),
            body: body.map(RequestBody.init) ?? RequestBody(buffer: .init())
        )
    }
}

extension HTTPFields {
    /// Initialize HTTPFields from HTTP headers and multivalue headers in an APIGateway request
    /// - Parameters:
    ///   - headers: headers
    ///   - multiValueHeaders: multi-value headers
    ///   - authority: reference to authority string
    init(headers: [(name: String, value: String)], authority: inout String?) {
        self.init()
        self.reserveCapacity(headers.count)
        var firstHost = true
        for (name, value) in headers {
            if firstHost, name.lowercased() == "host" {
                firstHost = false
                authority = value
                continue
            }
            if let fieldName = HTTPField.Name(name) {
                self.append(HTTPField(name: fieldName, value: value))
            }
        }
    }
}
