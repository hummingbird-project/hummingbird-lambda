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
import ExtrasBase64
import Foundation
import HTTPTypes
import HummingbirdCore
import NIOCore

extension APIGatewayV2Request: LambdaTestableEvent {
    /// Construct APIGatewayV2 Event from uri, method, headers and body
    public init(uri: String, method: HTTPRequest.Method, headers: HTTPFields, body: ByteBuffer?) throws {
        let base64Body = body.map { "\"\(Base64.encodeToString(bytes: $0.readableBytesView))\"" } ?? "null"
        let url = URI(uri)
        let queryValues: [String: [String]] = url.queryParameters.reduce([:]) { result, value in
            var result = result
            let key = String(value.key)
            var values = result[key] ?? []
            values.append(.init(value.value))
            result[key] = values
            return result
        }
        let queryValueStrings = try String(decoding: JSONEncoder().encode(queryValues.mapValues { $0.joined(separator: ",") }), as: UTF8.self)
        let headerValues: [String: [String]] = headers.reduce(["host": ["127.0.0.1:8080"]]) { result, value in
            var result = result
            let key = String(value.name)
            var values = result[key] ?? []
            values.append(.init(value.value))
            result[key] = values
            return result
        }
        let headerValueStrings = try String(decoding: JSONEncoder().encode(headerValues.mapValues { $0.joined(separator: ",") }), as: UTF8.self)
        let eventJson = """
            {
                "routeKey":"\(method) \(url.path)",
                "version":"2.0",
                "rawPath":"\(url.path)",
                "stageVariables":null,
                "requestContext":{
                    "timeEpoch":1587750461466,
                    "domainPrefix":"hello",
                    "authorizer":{
                        "jwt":{
                            "scopes":[
                                "hello"
                            ],
                            "claims":{
                                "aud":"customers",
                                "iss":"https://hello.test.com/",
                                "iat":"1587749276",
                                "exp":"1587756476"
                            }
                        }
                    },
                    "accountId":"0123456789",
                    "stage":"$default",
                    "domainName":"hello.test.com",
                    "apiId":"pb5dg6g3rg",
                    "requestId":"LgLpnibOFiAEPCA=",
                    "http":{
                        "path":"\(url.path)",
                        "userAgent":"Paw/3.1.10 (Macintosh; OS X/10.15.4) GCDHTTPRequest",
                        "method":"\(method)",
                        "protocol":"HTTP/1.1",
                        "sourceIp":"91.64.117.86"
                    },
                    "time":"24/Apr/2020:17:47:41 +0000"
                },
                "body": \(base64Body),
                "isBase64Encoded": \(body != nil),
                "rawQueryString":"\(url.query ?? "")",
                "queryStringParameters":\(queryValueStrings),
                "headers":\(headerValueStrings)
            }
            """
        self = try JSONDecoder().decode(Self.self, from: Data(eventJson.utf8))
    }
}
