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
import AWSLambdaRuntime
import ExtrasBase64
import Foundation
import Hummingbird
import NIOHTTP1

protocol APIRequest {
    var path: String { get }
    var httpMethod: AWSLambdaEvents.HTTPMethod { get }
    var queryString: String { get }
    var httpHeaders: HTTPHeaders { get }
    var body: String? { get }
    var isBase64Encoded: Bool { get }
}

extension LambdaContext: HBRequestContext {
    public var remoteAddress: SocketAddress? { return nil }
}

extension HBRequest {
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    init<Request: APIRequest>(context: LambdaContext, application: HBApplication, from: Request) throws {
        func urlPercentEncoded(_ string: String) -> String {
            return string.addingPercentEncoding(withAllowedCharacters: .urlQueryComponentAllowed) ?? string
        }
        // construct URI with query parameters
        var uri = from.path
        if from.queryString.count > 0 {
            uri += "?\(from.queryString)"
        }
        // construct headers
        let headers = from.httpHeaders
        let head = HTTPRequestHead(
            version: .init(major: 2, minor: 0),
            method: .init(rawValue: from.httpMethod.rawValue),
            uri: uri,
            headers: headers
        )
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
            head: head,
            body: .byteBuffer(body),
            application: application,
            context: context
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
