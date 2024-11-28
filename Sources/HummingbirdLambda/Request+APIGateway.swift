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
    var httpMethod: HTTPRequest.Method { get }
    var queryString: String { get }
    var httpHeaders: [(name: String, value: String)] { get }
    var body: String? { get }
    var isBase64Encoded: Bool { get }
}

extension Request {
    /// Specialization of Lambda.request where `In` is `APIGateway.Request`
    init(context: LambdaContext, from: some APIRequest) throws {
        func urlPercentEncoded(_ string: String) -> String {
            string.addingPercentEncoding(withAllowedCharacters: .urlQueryComponentAllowed) ?? string
        }

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

extension CharacterSet {
    static var urlQueryComponentAllowed: CharacterSet = {
        var cs = CharacterSet.urlQueryAllowed
        cs.remove(charactersIn: "&=")
        return cs
    }()
}
