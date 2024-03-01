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
import Foundation
import HTTPTypes
import HummingbirdCore
@_spi(HBXCT) import HummingbirdXCT
import NIOCore

extension APIGatewayV2Request: XCTLambdaEvent {
    public init(uri: String, method: HTTPRequest.Method, headers: HTTPFields, body: ByteBuffer?) throws {
        let url = HBURL(uri)
        let eventJson = """
        {
            "routeKey":"\(method) \(uri)",
            "version":"2.0",
            "rawPath":"\(uri)",
            "stageVariables":none,
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
                    "path":"\(uri)",
                    "userAgent":"Paw/3.1.10 (Macintosh; OS X/10.15.4) GCDHTTPRequest",
                    "method":"\(method)",
                    "protocol":"HTTP/1.1",
                    "sourceIp":"91.64.117.86"
                },
                "time":"24/Apr/2020:17:47:41 +0000"
            },
            "isBase64Encoded":false,
            "rawQueryString":"\(url.query ?? "")",
            "queryStringParameters":{
                "foo":"bar"
            },
            "headers":{
                "x-forwarded-proto":"https",
                "x-forwarded-for":"91.64.117.86",
                "x-forwarded-port":"443",
                "authorization":"Bearer abc123",
                "host":"hello.test.com",
                "x-amzn-trace-id":"Root=1-5ea3263d-07c5d5ddfd0788bed7dad831",
                "user-agent":"Paw/3.1.10 (Macintosh; OS X/10.15.4) GCDHTTPRequest",
                "content-length":"0"
            }
        }
        """
        self = try JSONDecoder().decode(Self.self, from: Data(eventJson.utf8))
    }
}
