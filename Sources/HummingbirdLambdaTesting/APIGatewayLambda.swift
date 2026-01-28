//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import AWSLambdaEvents
import ExtrasBase64
import HTTPTypes
import HummingbirdCore
import NIOCore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension APIGatewayRequest: LambdaTestableEvent {
    /// Construct APIGateway Event from uri, method, headers and body
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
        let singleQueryValues = queryValues.compactMapValues { $0.count == 1 ? $0.first : nil }
        let queryValuesString = try String(decoding: JSONEncoder().encode(singleQueryValues), as: UTF8.self)
        let multiQueryValuesString = try String(decoding: JSONEncoder().encode(queryValues), as: UTF8.self)
        let headerValues: [String: [String]] = headers.reduce(["host": ["127.0.0.1:8080"]]) { result, value in
            var result = result
            let key = String(value.name)
            var values = result[key] ?? []
            values.append(.init(value.value))
            result[key] = values
            return result
        }
        let singleHeaderValues = headerValues.compactMapValues { $0.count == 1 ? $0.first : nil }
        let headerValuesString = try String(decoding: JSONEncoder().encode(singleHeaderValues), as: UTF8.self)
        let multiHeaderValuesString = try String(decoding: JSONEncoder().encode(headerValues), as: UTF8.self)
        let eventJson = """
            {
                "httpMethod": "\(method)", 
                "body": \(base64Body), 
                "resource": "\(url.path)", 
                "requestContext": {
                    "resourceId": "123456", 
                    "apiId": "1234567890", 
                    "resourcePath": "\(url.path)", 
                    "httpMethod": "\(method)", 
                    "requestId": "\(UUID().uuidString)", 
                    "accountId": "123456789012", 
                    "stage": "Prod", 
                    "identity": {
                        "apiKey": null, 
                        "userArn": null, 
                        "cognitoAuthenticationType": null, 
                        "caller": null, 
                        "userAgent": "Custom User Agent String", 
                        "user": null, 
                        "cognitoIdentityPoolId": null, 
                        "cognitoAuthenticationProvider": null, 
                        "sourceIp": "127.0.0.1", 
                        "accountId": null
                    }, 
                    "extendedRequestId": null, 
                    "path": "\(uri)"
                }, 
                "queryStringParameters": \(queryValuesString), 
                "multiValueQueryStringParameters": \(multiQueryValuesString), 
                "headers": \(headerValuesString), 
                "multiValueHeaders": \(multiHeaderValuesString), 
                "pathParameters": null, 
                "stageVariables": null, 
                "path": "\(url.path)", 
                "isBase64Encoded": \(body != nil)
            }
            """
        self = try JSONDecoder().decode(Self.self, from: Data(eventJson.utf8))
    }
}
