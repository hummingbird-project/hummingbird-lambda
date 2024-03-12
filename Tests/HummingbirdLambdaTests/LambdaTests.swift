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
@testable import AWSLambdaRuntimeCore
@testable import HummingbirdLambda
import HummingbirdLambdaTesting
import Logging
import NIOCore
import NIOPosix
import XCTest

final class LambdaTests: XCTestCase {
    func testSimpleRoute() async throws {
        struct HelloLambda: APIGatewayLambdaFunction {
            typealias Context = BasicLambdaRequestContext<APIGatewayRequest>

            init(context: LambdaInitializationContext) {}

            func buildResponder() -> some HTTPResponder<Context> {
                let router = Router(context: Context.self)
                router.middlewares.add(LogRequestsMiddleware(.debug))
                router.get("hello") { request, _ in
                    XCTAssertEqual(request.head.authority, "127.0.0.1:8080")
                    return "Hello"
                }
                return router.buildResponder()
            }
        }
        try await HelloLambda.test { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.body, "Hello")
                XCTAssertEqual(response.statusCode, .ok)
                XCTAssertEqual(response.headers?["Content-Type"], "text/plain; charset=utf-8")
            }
        }
    }

    func testBase64Encoding() async throws {
        struct HelloLambda: APIGatewayLambdaFunction {
            typealias Context = BasicLambdaRequestContext<APIGatewayRequest>
            init(context: LambdaInitializationContext) {}
            func buildResponder() -> some HTTPResponder<Context> {
                let router = Router(context: Context.self)
                router.middlewares.add(LogRequestsMiddleware(.debug))
                router.post { request, context in
                    let buffer = try await request.body.collect(upTo: context.maxUploadSize)
                    return Response(status: .ok, body: .init(byteBuffer: buffer))
                }
                return router.buildResponder()
            }
        }
        try await HelloLambda.test { client in
            let body = ByteBuffer(bytes: (0...255).map { _ in UInt8.random(in: 0...255) })
            try await client.execute(uri: "/", method: .post, body: body) { response in
                XCTAssertEqual(response.isBase64Encoded, true)
                XCTAssertEqual(response.body, String(base64Encoding: body.readableBytesView))
            }
        }
    }

    func testHeaderValues() async throws {
        struct HelloLambda: APIGatewayLambdaFunction {
            typealias Context = BasicLambdaRequestContext<APIGatewayRequest>
            init(context: LambdaInitializationContext) {}

            func buildResponder() -> some HTTPResponder<Context> {
                let router = Router(context: Context.self)
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
                return router.buildResponder()
            }
        }
        try await HelloLambda.test { client in
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
        struct HelloLambda: APIGatewayLambdaFunction {
            typealias Context = BasicLambdaRequestContext<APIGatewayRequest>
            init(context: LambdaInitializationContext) {}

            func buildResponder() -> some HTTPResponder<Context> {
                let router = Router(context: Context.self)
                router.middlewares.add(LogRequestsMiddleware(.debug))
                router.post { request, _ -> HTTPResponse.Status in
                    XCTAssertEqual(request.uri.queryParameters["foo"], "bar")
                    return .ok
                }
                router.post("/multi") { request, _ -> HTTPResponse.Status in
                    XCTAssertEqual(request.uri.queryParameters.getAll("foo"), ["bar1", "bar2"])
                    return .ok
                }
                return router.buildResponder()
            }
        }
        try await HelloLambda.test { client in
            try await client.execute(uri: "/?foo=bar", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
            try await client.execute(uri: "/multi?foo=bar1&foo=bar2", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
        }
    }

    func testErrorEncoding() async throws {
        struct HelloLambda: APIGatewayLambdaFunction {
            typealias Context = BasicLambdaRequestContext<APIGatewayRequest>

            static let body = "BadRequest"
            init(context: LambdaInitializationContext) {}

            func buildResponder() -> some HTTPResponder<Context> {
                let router = Router(context: Context.self)
                router.middlewares.add(LogRequestsMiddleware(.debug))
                router.post { _, _ -> String in
                    throw HTTPError(.badRequest, message: Self.body)
                }
                return router.buildResponder()
            }
        }
        try await HelloLambda.test { client in
            try await client.execute(uri: "/", method: .post) { response in
                XCTAssertEqual(response.statusCode, .badRequest)
                XCTAssertEqual(response.body, HelloLambda.body)
                XCTAssertEqual(response.headers?["Content-Length"], HelloLambda.body.utf8.count.description)
            }
        }
    }

    func testSimpleRouteV2() async throws {
        struct HelloLambda: APIGatewayV2LambdaFunction {
            typealias Context = BasicLambdaRequestContext<APIGatewayV2Request>

            init(context: LambdaInitializationContext) {}

            func buildResponder() -> some HTTPResponder<Context> {
                let router = Router(context: Context.self)
                router.middlewares.add(LogRequestsMiddleware(.debug))
                router.post { request, _ in
                    XCTAssertEqual(request.head.authority, "127.0.0.1:8080")
                    return ["response": "hello"]
                }
                return router.buildResponder()
            }
        }
        try await HelloLambda.test { client in
            try await client.execute(uri: "/", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
                XCTAssertEqual(response.headers?["Content-Type"], "application/json; charset=utf-8")
                XCTAssertEqual(response.body, #"{"response":"hello"}"#)
            }
        }
    }

    func testBase64EncodingV2() async throws {
        struct HelloLambda: APIGatewayV2LambdaFunction {
            typealias Context = BasicLambdaRequestContext<APIGatewayV2Request>
            init(context: LambdaInitializationContext) {}
            func buildResponder() -> some HTTPResponder<Context> {
                let router = Router(context: Context.self)
                router.middlewares.add(LogRequestsMiddleware(.debug))
                router.post { request, _ in
                    let buffer = try await request.body.collect(upTo: .max)
                    return Response(status: .ok, body: .init(byteBuffer: buffer))
                }
                return router.buildResponder()
            }
        }
        try await HelloLambda.test { client in
            let body = ByteBuffer(bytes: (0...255).map { _ in UInt8.random(in: 0...255) })
            try await client.execute(uri: "/", method: .post, headers: [.userAgent: "HBXCT/2.0"], body: body) { response in
                XCTAssertEqual(response.isBase64Encoded, true)
                XCTAssertEqual(response.body, String(base64Encoding: body.readableBytesView))
            }
        }
    }

    func testHeaderValuesV2() async throws {
        struct HelloLambda: APIGatewayV2LambdaFunction {
            typealias Context = BasicLambdaRequestContext<APIGatewayV2Request>
            init(context: LambdaInitializationContext) {}

            func buildResponder() -> some HTTPResponder<Context> {
                let router = Router(context: Context.self)
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
                return router.buildResponder()
            }
        }
        try await HelloLambda.test { client in
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
        struct HelloLambda: APIGatewayV2LambdaFunction {
            typealias Context = BasicLambdaRequestContext<APIGatewayV2Request>
            init(context: LambdaInitializationContext) {}

            func buildResponder() -> some HTTPResponder<Context> {
                let router = Router(context: Context.self)
                router.middlewares.add(LogRequestsMiddleware(.debug))
                router.post { request, _ -> HTTPResponse.Status in
                    XCTAssertEqual(request.uri.queryParameters["foo"], "bar")
                    return .ok
                }
                router.post("/multi") { request, _ -> HTTPResponse.Status in
                    XCTAssertEqual(request.uri.queryParameters.getAll("foo"), ["bar1", "bar2"])
                    return .ok
                }
                return router.buildResponder()
            }
        }
        try await HelloLambda.test { client in
            try await client.execute(uri: "/?foo=bar", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
            try await client.execute(uri: "/multi?foo=bar1&foo=bar2", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
            }
        }
    }
}
