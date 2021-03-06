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

    var initializationContext: Lambda.InitializationContext {
        .init(logger: self.logger, eventLoop: self.eventLoopGroup.next(), allocator: self.allocator)
    }

    func newContext() -> Lambda.Context {
        Lambda.Context(
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

    func newEvent(uri: String, method: String, body: ByteBuffer? = nil) throws -> APIGateway.Request {
        let base64Body = body.map { "\"\(String(base64Encoding: $0.readableBytesView))\"" } ?? "null"
        let request = """
          {"httpMethod": "\(method)", "body": \(base64Body), "resource": "\(uri)", "requestContext": {"resourceId": "123456", "apiId": "1234567890", "resourcePath": "\(uri)", "httpMethod": "\(method)", "requestId": "c6af9ac6-7b61-11e6-9a41-93e8deadbeef", "accountId": "123456789012", "stage": "Prod", "identity": {"apiKey": null, "userArn": null, "cognitoAuthenticationType": null, "caller": null, "userAgent": "Custom User Agent String", "user": null, "cognitoIdentityPoolId": null, "cognitoAuthenticationProvider": null, "sourceIp": "127.0.0.1", "accountId": null}, "extendedRequestId": null, "path": "\(uri)"}, "queryStringParameters": null, "multiValueQueryStringParameters": null, "headers": {"Host": "127.0.0.1:3000", "Connection": "keep-alive", "Cache-Control": "max-age=0", "Dnt": "1", "Upgrade-Insecure-Requests": "1", "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36 Edg/78.0.276.24", "Sec-Fetch-User": "?1", "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3", "Sec-Fetch-Site": "none", "Sec-Fetch-Mode": "navigate", "Accept-Encoding": "gzip, deflate, br", "Accept-Language": "en-US,en;q=0.9", "X-Forwarded-Proto": "http", "X-Forwarded-Port": "3000"}, "multiValueHeaders": {"Host": ["127.0.0.1:3000"], "Connection": ["keep-alive"], "Cache-Control": ["max-age=0"], "Dnt": ["1"], "Upgrade-Insecure-Requests": ["1"], "User-Agent": ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/78.0.3904.87 Safari/537.36 Edg/78.0.276.24"], "Sec-Fetch-User": ["?1"], "Accept": ["text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3"], "Sec-Fetch-Site": ["none"], "Sec-Fetch-Mode": ["navigate"], "Accept-Encoding": ["gzip, deflate, br"], "Accept-Language": ["en-US,en;q=0.9"], "X-Forwarded-Proto": ["http"], "X-Forwarded-Port": ["3000"]}, "pathParameters": null, "stageVariables": null, "path": "\(uri)", "isBase64Encoded": \(body != nil)}
        """
        return try JSONDecoder().decode(APIGateway.Request.self, from: Data(request.utf8))
    }

    func testSimpleRoute() throws {
        struct HelloLambda: HBLambda {
            // define input and output
            typealias In = APIGateway.Request
            typealias Out = APIGateway.Response

            init(_ app: HBApplication) {
                app.middleware.add(HBLogRequestsMiddleware(.debug))
                app.router.get("hello") { _ in
                    return "Hello"
                }
            }
        }
        let lambda = try HBLambdaHandler<HelloLambda>(context: self.initializationContext)
        let context = self.newContext()
        let event = try newEvent(uri: "/hello", method: "GET")
        let response = try lambda.handle(context: context, event: event).wait()
        XCTAssertEqual(response.body, "Hello")
        XCTAssertEqual(response.statusCode, .ok)
        XCTAssertEqual(response.headers?["content-type"], "text/plain; charset=utf-8")
    }

    func testBase64Encoding() throws {
        struct HelloLambda: HBLambda {
            // define input and output
            typealias In = APIGateway.Request
            typealias Out = APIGateway.Response

            init(_ app: HBApplication) {
                app.middleware.add(HBLogRequestsMiddleware(.debug))
                app.router.post { request in
                    return request.body.buffer
                }
            }
        }
        let lambda = try HBLambdaHandler<HelloLambda>(context: self.initializationContext)
        let context = self.newContext()
        let data = (0...255).map { _ in UInt8.random(in: 0...255) }
        let event = try newEvent(uri: "/", method: "POST", body: ByteBufferAllocator().buffer(bytes: data))
        let response = try lambda.handle(context: context, event: event).wait()
        XCTAssertEqual(response.isBase64Encoded, true)
        XCTAssertEqual(response.body, String(base64Encoding: data))
    }
}
