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
import HummingbirdLambdaTesting
import Logging
import NIOCore
import NIOPosix
import XCTest

@testable import AWSLambdaRuntimeCore
@testable import HummingbirdLambda

final class LambdaTests: XCTestCase {
    func testSimpleRoute() async throws {
        let router = Router(context: BasicLambdaRequestContext<APIGatewayRequest>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.get("hello") { request, _ in
            XCTAssertEqual(request.head.authority, "127.0.0.1:8080")
            return "Hello"
        }
        let lambda = APIGatewayLambdaFunction(router: router)
        try await lambda.test { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.body, "Hello")
                XCTAssertEqual(response.statusCode, .ok)
                XCTAssertEqual(response.headers?["Content-Type"], "text/plain; charset=utf-8")
            }
        }
    }

    func testBase64Encoding() async throws {
        let router = Router(context: BasicLambdaRequestContext<APIGatewayRequest>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, context in
            let buffer = try await request.body.collect(upTo: context.maxUploadSize)
            return Response(status: .ok, body: .init(byteBuffer: buffer))
        }
        let lambda = APIGatewayLambdaFunction(router: router)
        try await lambda.test { client in
            let body = ByteBuffer(bytes: (0...255).map { _ in UInt8.random(in: 0...255) })
            try await client.execute(uri: "/", method: .post, body: body) { response in
                XCTAssertEqual(response.isBase64Encoded, true)
                XCTAssertEqual(response.body, String(base64Encoding: body.readableBytesView))
            }
        }
    }

    func testHeaderValues() async throws {
        let router = Router(context: BasicLambdaRequestContext<APIGatewayRequest>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.headers[.userAgent], "HBXCT/2.0")
            XCTAssertEqual(request.headers[.acceptLanguage], "en")
            return .ok
        }
        router.post("/multi") { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.headers[.userAgent], "HBXCT/2.0")
            XCTAssertEqual(request.headers[values: .acceptLanguage], ["en", "fr"])
            return .ok
        }
        let lambda = APIGatewayLambdaFunction(router: router)
        try await lambda.test { client in
            try await client.execute(uri: "/", method: .post, headers: [.userAgent: "HBXCT/2.0", .acceptLanguage: "en"]) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
            var headers: HTTPFields = [.userAgent: "HBXCT/2.0", .acceptLanguage: "en"]
            headers[values: .acceptLanguage].append("fr")
            try await client.execute(uri: "/multi", method: .post, headers: headers) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
        }
    }

    func testQueryValues() async throws {
        let router = Router(context: BasicLambdaRequestContext<APIGatewayRequest>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.uri.queryParameters["foo"], "bar")
            return .ok
        }
        router.post("/multi") { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.uri.queryParameters.getAll("foo"), ["bar1", "bar2"])
            return .ok
        }
        let lambda = APIGatewayLambdaFunction(router: router)
        try await lambda.test { client in
            try await client.execute(uri: "/?foo=bar", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
            try await client.execute(uri: "/multi?foo=bar1&foo=bar2", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
        }
    }

    func testErrorEncoding() async throws {
        let router = Router(context: BasicLambdaRequestContext<APIGatewayRequest>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { _, _ -> String in
            throw HTTPError(.badRequest, message: "BadRequest")
        }
        let lambda = LambdaFunction(router: router, output: APIGatewayResponse.self)
        try await lambda.test { client in
            try await client.execute(uri: "/", method: .post) { response in
                let expectedBody = "{\"error\":{\"message\":\"BadRequest\"}}"
                XCTAssertEqual(response.statusCode, .badRequest)
                XCTAssertEqual(response.body, expectedBody)
                XCTAssertEqual(response.headers?["Content-Length"], expectedBody.utf8.count.description)
            }
        }
    }

    func testSimpleRouteV2() async throws {
        let router = Router(context: BasicLambdaRequestContext<APIGatewayV2Request>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ in
            XCTAssertEqual(request.head.authority, "127.0.0.1:8080")
            return ["response": "hello"]
        }
        let lambda = APIGatewayV2LambdaFunction(router: router)
        try await lambda.test { client in
            try await client.execute(uri: "/", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
                XCTAssertEqual(response.headers?["Content-Type"], "application/json; charset=utf-8")
                XCTAssertEqual(response.body, #"{"response":"hello"}"#)
            }
        }
    }

    func testBase64EncodingV2() async throws {
        let router = Router(context: BasicLambdaRequestContext<APIGatewayV2Request>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ in
            let buffer = try await request.body.collect(upTo: .max)
            return Response(status: .ok, body: .init(byteBuffer: buffer))
        }
        let lambda = APIGatewayV2LambdaFunction(router: router)
        try await lambda.test { client in
            let body = ByteBuffer(bytes: (0...255).map { _ in UInt8.random(in: 0...255) })
            try await client.execute(uri: "/", method: .post, headers: [.userAgent: "HBXCT/2.0"], body: body) { response in
                XCTAssertEqual(response.isBase64Encoded, true)
                XCTAssertEqual(response.body, String(base64Encoding: body.readableBytesView))
            }
        }
    }

    func testHeaderValuesV2() async throws {
        let router = Router(context: BasicLambdaRequestContext<APIGatewayV2Request>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.headers[.userAgent], "HBXCT/2.0")
            XCTAssertEqual(request.headers[.acceptLanguage], "en")
            return .ok
        }
        router.post("/multi") { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.headers[.userAgent], "HBXCT/2.0")
            XCTAssertEqual(request.headers[values: .acceptLanguage], ["en", "fr"])
            return .ok
        }
        let lambda = APIGatewayV2LambdaFunction(router: router)
        try await lambda.test { client in
            try await client.execute(uri: "/", method: .post, headers: [.userAgent: "HBXCT/2.0", .acceptLanguage: "en"]) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
            var headers: HTTPFields = [.userAgent: "HBXCT/2.0", .acceptLanguage: "en"]
            headers[values: .acceptLanguage].append("fr")
            try await client.execute(uri: "/multi", method: .post, headers: headers) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
        }
    }

    func testQueryValuesV2() async throws {
        let router = Router(context: BasicLambdaRequestContext<APIGatewayV2Request>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.uri.queryParameters["foo"], "bar")
            return .ok
        }
        router.post("/multi") { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.uri.queryParameters.getAll("foo"), ["bar1", "bar2"])
            return .ok
        }
        let lambda = APIGatewayV2LambdaFunction(router: router)
        try await lambda.test { client in
            try await client.execute(uri: "/?foo=bar", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
            try await client.execute(uri: "/multi?foo=bar1&foo=bar2", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
        }
    }

    func testCustomRequestContext() async throws {
        struct MyRequestContext: LambdaRequestContext {
            typealias Event = APIGatewayRequest

            var coreContext: CoreRequestContextStorage
            let string = "Hello"
            init(source: Source) {
                self.coreContext = .init(source: source)
            }
        }
        let router = Router(context: MyRequestContext.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, context in
            XCTAssertEqual(request.head.authority, "127.0.0.1:8080")
            return ["response": context.string]
        }
        let lambda = APIGatewayLambdaFunction(router: router)
        try await lambda.test { client in
            try await client.execute(uri: "/", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
                XCTAssertEqual(response.headers?["Content-Type"], "application/json; charset=utf-8")
                XCTAssertEqual(response.body, #"{"response":"Hello"}"#)
            }
        }
    }

    func testLambdaProtocol() async throws {
        struct HelloLambda: LambdaFunctionProtocol {
            typealias Event = APIGatewayRequest
            typealias Output = APIGatewayResponse

            var responder: some HTTPResponder<BasicLambdaRequestContext<APIGatewayRequest>> {
                let router = Router(context: BasicLambdaRequestContext<APIGatewayRequest>.self)
                router.middlewares.add(LogRequestsMiddleware(.debug))
                router.get("hello") { request, _ in
                    XCTAssertEqual(request.head.authority, "127.0.0.1:8080")
                    return "Hello"
                }
                return router.buildResponder()
            }
        }
        let lambda = HelloLambda()
        try await lambda.test { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.body, "Hello")
                XCTAssertEqual(response.statusCode, .ok)
                XCTAssertEqual(response.headers?["Content-Type"], "text/plain; charset=utf-8")
            }
        }
    }

}
