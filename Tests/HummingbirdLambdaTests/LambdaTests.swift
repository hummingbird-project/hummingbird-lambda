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
@testable import AWSLambdaRuntimeCore
import HummingbirdLambda
import Logging
import NIOPosix
import XCTest

final class LambdaTests: XCTestCase {
    var eventLoopGroup: EventLoopGroup!
    let allocator = ByteBufferAllocator()
    let logger = Logger(label: "LambdaTests")

    override func setUp() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    override func tearDown() {
        try! self.eventLoopGroup.syncShutdownGracefully()
    }

    var initializationContext: LambdaInitializationContext {
        .init(
            logger: self.logger,
            eventLoop: self.eventLoopGroup.next(),
            allocator: self.allocator,
            terminator: .init()
        )
    }

    func newContext() -> LambdaContext {
        LambdaContext(
            requestID: UUID().uuidString,
            traceID: "abc123",
            invokedFunctionARN: "aws:arn:",
            deadline: .now() + .seconds(3),
            cognitoIdentity: nil,
            clientContext: nil,
            logger: Logger(label: "test"),
            eventLoop: self.eventLoopGroup.next(),
            allocator: ByteBufferAllocator()
        )
    }

    func newEvent(uri: String, method: String, body: ByteBuffer? = nil) throws -> APIGatewayRequest {
        let base64Body = body.map { "\"\(String(base64Encoding: $0.readableBytesView))\"" } ?? "null"
        let request = """
          {"httpMethod": "\(method)", "body": \(base64Body), "resource": "\(uri)", "requestContext": {"resourceId": "123456", "apiId": "1234567890", "resourcePath": "\(uri)", "httpMethod": "\(method)", "requestId": "c6af9ac6-7b61-11e6-9a41-93e8deadbeef", "accountId": "123456789012", "stage": "Prod", "identity": {"apiKey": null, "userArn": null, "cognitoAuthenticationType": null, "caller": null, "userAgent": "Custom User Agent String", "user": null, "cognitoIdentityPoolId": null, "cognitoAuthenticationProvider": null, "sourceIp": "127.0.0.1", "accountId": null}, "extendedRequestId": null, "path": "\(uri)"}, "queryStringParameters": null, "multiValueQueryStringParameters": null, "headers": {"Host": "127.0.0.1:3000", "Connection": "keep-alive", "Cache-Control": "max-age=0", "Dnt": "1", "Upgrade-Insecure-Requests": "1", "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36 Edg/78.0.276.24", "Sec-Fetch-User": "?1", "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3", "Sec-Fetch-Site": "none", "Sec-Fetch-Mode": "navigate", "Accept-Encoding": "gzip, deflate, br", "Accept-Language": "en-US,en;q=0.9", "X-Forwarded-Proto": "http", "X-Forwarded-Port": "3000"}, "multiValueHeaders": {"Host": ["127.0.0.1:3000"], "Connection": ["keep-alive"], "Cache-Control": ["max-age=0"], "Dnt": ["1"], "Upgrade-Insecure-Requests": ["1"], "User-Agent": ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36 Edg/78.0.276.24"], "Sec-Fetch-User": ["?1"], "Accept": ["text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3"], "Sec-Fetch-Site": ["none"], "Sec-Fetch-Mode": ["navigate"], "Accept-Encoding": ["gzip, deflate, br"], "Accept-Language": ["en-US,en;q=0.9"], "X-Forwarded-Proto": ["http"], "X-Forwarded-Port": ["3000"]}, "pathParameters": null, "stageVariables": null, "path": "\(uri)", "isBase64Encoded": \(body != nil)}
        """
        return try JSONDecoder().decode(APIGatewayRequest.self, from: Data(request.utf8))
    }

    func newV2Event(uri: String, method: String) throws -> APIGatewayV2Request {
        let request = """
        {
            "routeKey":"\(method) \(uri)",
            "version":"2.0",
            "rawPath":"\(uri)",
            "stageVariables":{
                "foo":"bar"
            },
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
            "rawQueryString":"foo=bar",
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
        return try JSONDecoder().decode(APIGatewayV2Request.self, from: Data(request.utf8))
    }

    func testSimpleRoute() throws {
        struct HelloLambda: HBLambda {
            // define input and output
            typealias Event = APIGatewayRequest
            typealias Output = APIGatewayResponse

            init(_ app: HBApplication) {
                app.middleware.add(HBLogRequestsMiddleware(.debug))
                app.router.get("hello") { _ in
                    return "Hello"
                }
            }
        }
        let lambda = try HBLambdaHandler<HelloLambda>.makeHandler(context: self.initializationContext).wait()
        let context = self.newContext()
        let event = try newEvent(uri: "/hello", method: "GET")
        let response = try lambda.handle(event, context: context).wait()
        XCTAssertEqual(response.body, "Hello")
        XCTAssertEqual(response.statusCode, .ok)
        XCTAssertEqual(response.headers?["content-type"], "text/plain; charset=utf-8")
    }

    func testBase64Encoding() throws {
        struct HelloLambda: HBLambda {
            // define input and output
            typealias Event = APIGatewayRequest
            typealias Output = APIGatewayResponse

            init(_ app: HBApplication) {
                app.middleware.add(HBLogRequestsMiddleware(.debug))
                app.router.post { request in
                    return request.body.buffer
                }
            }
        }
        let lambda = try HBLambdaHandler<HelloLambda>.makeHandler(context: self.initializationContext).wait()
        let context = self.newContext()
        let data = (0...255).map { _ in UInt8.random(in: 0...255) }
        let event = try newEvent(uri: "/", method: "POST", body: ByteBufferAllocator().buffer(bytes: data))
        let response = try lambda.handle(event, context: context).wait()
        XCTAssertEqual(response.isBase64Encoded, true)
        XCTAssertEqual(response.body, String(base64Encoding: data))
    }

    func testAPIGatewayV2Decoding() throws {
        struct HelloLambda: HBLambda {
            // define input and output
            typealias Event = APIGatewayV2Request
            typealias Output = APIGatewayV2Response

            init(_ app: HBApplication) {
                app.middleware.add(HBLogRequestsMiddleware(.debug))
                app.router.post { _ in
                    return "hello"
                }
            }
        }
        let lambda = try HBLambdaHandler<HelloLambda>.makeHandler(context: self.initializationContext).wait()
        let context = self.newContext()
        let event = try newV2Event(uri: "/", method: "POST")
        let response = try lambda.handle(event, context: context).wait()
        XCTAssertEqual(response.statusCode, .ok)
        XCTAssertEqual(response.body, "hello")
    }

    func testErrorEncoding() throws {
        struct HelloLambda: HBLambda {
            // define input and output
            typealias Event = APIGatewayV2Request
            typealias Output = APIGatewayV2Response

            init(_ app: HBApplication) {
                app.middleware.add(HBLogRequestsMiddleware(.debug))
                app.router.post { _ -> String in
                    throw HBHTTPError(.badRequest, message: "BadRequest")
                }
            }
        }
        let lambda = try HBLambdaHandler<HelloLambda>.makeHandler(context: self.initializationContext).wait()
        let context = self.newContext()
        let event = try newV2Event(uri: "/", method: "POST")
        let response = try lambda.handle(event, context: context).wait()
        XCTAssertEqual(response.statusCode, .badRequest)
        XCTAssertEqual(response.body, "BadRequest")
    }
}
