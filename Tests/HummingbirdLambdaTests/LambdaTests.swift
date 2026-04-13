//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import AWSLambdaEvents
import ExtrasBase64
import HummingbirdLambdaTesting
import Logging
import NIOCore
import NIOPosix
import Synchronization
import XCTest

@testable import Hummingbird
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
                XCTAssertEqual(response.body, Base64.encodeToString(bytes: body.readableBytesView))
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
                XCTAssertEqual(response.body, Base64.encodeToString(bytes: body.readableBytesView))
            }
        }
    }

    func testHeaderValuesV2() async throws {
        
        struct TestCookie: Sendable {
            let name: String
            let value: String
            let properties: Cookie.Properties

            var expires: Date? { self.properties[.expires].flatMap { Date(httpHeader: $0) } }
            /// indicates the maximum lifetime of the cookie in seconds. Max age has precedence over expires
            /// (not all user agents support max-age)
            var maxAge: Int? { self.properties[.maxAge].map { Int($0) } ?? nil }
            /// specifies those hosts to which the cookie will be sent
            var domain: String? { self.properties[.domain] }
            /// The scope of each cookie is limited to a set of paths, controlled by the Path attribute
            var path: String? { self.properties[.path] }
            /// The Secure attribute limits the scope of the cookie to "secure" channels
            var secure: Bool { self.properties[.secure] != nil }
            /// The HttpOnly attribute limits the scope of the cookie to HTTP requests
            var httpOnly: Bool { self.properties[.httpOnly] != nil }
            /// The SameSite attribute lets servers specify whether/when cookies are sent with cross-origin requests
            var sameSite: Cookie.SameSite? { self.properties[.sameSite].map { Cookie.SameSite(rawValue: $0) } ?? nil }
            
            init?(from header: String) {
                var iterator = header.splitSequence(separator: ";").makeIterator()
                guard let keyValue = iterator.next() else { return nil }
                var keyValueIterator = keyValue.splitMaxSplitsSequence(separator: "=", maxSplits: 1).makeIterator()
                guard let key = keyValueIterator.next() else { return nil }
                guard let value = keyValueIterator.next() else { return nil }
                self.name = String(key)
                self.value = String(value)

                var properties = Cookie.Properties()
                // extract elements
                while let element = iterator.next() {
                    var keyValueIterator = element.splitMaxSplitsSequence(separator: "=", maxSplits: 1).makeIterator()
                    guard var key = keyValueIterator.next() else { return nil }
                    key = key.drop(while: \.isWhitespace)
                    if let value = keyValueIterator.next() {
                        properties[key] = String(value)
                    } else {
                        properties[key] = ""
                    }
                }
                self.properties = properties
            }

            static func getName<S: StringProtocol>(from header: S) -> String? {
                if let equals = header.firstIndex(of: "=") {
                    return String(header[..<equals])
                }
                return nil
            }
            
            func toCookie() throws -> Cookie {
                return try Cookie.validated(name: name, value: value, expires: expires,
                                        maxAge: maxAge, domain: domain, path: path, secure: secure, httpOnly: httpOnly, sameSite: sameSite)
            }
            
        }
        
        struct TestCookies: Sendable {
            
            /// Construct cookies accessor from cookie header strings
            /// - Parameter cookieHeaders: An array of cookie header strings
            public init(from cookieHeaders: [String]) {
                
                let cookieStrings:[String:String] = cookieHeaders.reduce(into: [:])
                { results, header in
                    if let cookieName = TestCookie.getName(from: header) {
                        results[cookieName] = header
                    }
                }
                self.cookieStrings = cookieStrings
            }

            /// access cookies via dictionary subscript
            public subscript(_ key: String) -> TestCookie? {
                guard let cookieString = cookieStrings[key] else {
                    return nil
                }
                return TestCookie(from: cookieString)
            }

            var cookieStrings: [String:String]
        }
        
        
        let router = Router(context: BasicLambdaRequestContext<APIGatewayV2Request>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ -> Response in
            XCTAssertEqual(request.headers[.userAgent], "HBXCT/2.0")
            XCTAssertEqual(request.headers[.acceptLanguage], "en")
            let cookie = request.cookies["my-cookie"]
            XCTAssertEqual(cookie?.name, "my-cookie")
            XCTAssertEqual(cookie?.value, "bar")
            
            //Set-Cookie in response
            let respCookie = Cookie(name: "resp-cookie", value: "xxxxxxx", maxAge: 600,
                                    domain: "example.com", path: "/", secure: true,
                                    httpOnly: true, sameSite: .lax)
            var respHeaders = HTTPFields()
            respHeaders[values: .setCookie] = [respCookie.description]
            return Response(status: .ok, headers: respHeaders)
        }
        router.post("/multi") { request, _ -> Response in
            XCTAssertEqual(request.headers[.userAgent], "HBXCT/2.0")
            XCTAssertEqual(request.headers[values: .acceptLanguage], ["en", "fr"])
            // Cookies A & B are sent in the same header; cookie C is sent in a separate header
            let cookieA = request.cookies["my-cookie-a"]
            XCTAssertEqual(cookieA?.name, "my-cookie-a")
            XCTAssertEqual(cookieA?.value, "A")
            let cookieB = request.cookies["my-cookie-b"]
            XCTAssertEqual(cookieB?.name, "my-cookie-b")
            XCTAssertEqual(cookieB?.value, "B")
            let cookieC = request.cookies["my-cookie-c"]
            XCTAssertEqual(cookieC?.name, "my-cookie-c")
            XCTAssertEqual(cookieC?.value, "C")

            // Set Multivalue Cookies
            var respHeaders = HTTPFields()
            let cookieNames = ["id_token","access_token","refresh_token","auth_nonce"]
            for cookieName in cookieNames {
                let cookie = Cookie(name: cookieName, value: "xxxxxxx", maxAge: 600,
                                    domain: "example.com", path: "/", secure: true,
                                    httpOnly: true, sameSite: .lax)
                
                var cookies = respHeaders[values: .setCookie]
                cookies.append(cookie.description)
                respHeaders[values: .setCookie] = cookies
            }
            // Multivalue Headers
            respHeaders[values: .accept] = ["application/json"]
            respHeaders[values: .accept].append("text/html")
            // Single Value Headers
            respHeaders[.contentLanguage] = "en, de, fr"
            return Response(status: .ok, headers: respHeaders)
        }
        
        let lambda = APIGatewayV2LambdaFunction(router: router)
        try await lambda.test { client in
            try await client.execute(uri: "/", method: .post, headers: [.userAgent: "HBXCT/2.0", .acceptLanguage: "en", .cookie: "my-cookie=bar"]) {
                response in
                XCTAssertEqual(response.statusCode, .ok)
                
                // Cookie Validation
                XCTAssertEqual(response.cookies?.count, 1, "Should only have 1 cookie")
                let cookieStrings = try XCTUnwrap(response.cookies)
                let cookie = try XCTUnwrap(Cookies(from: cookieStrings)["resp-cookie"])
                XCTAssertEqual(cookie.name, "resp-cookie")
                XCTAssertEqual(cookie.value, "xxxxxxx")
                
                // TestCookies required because Cookies fails to load anything but name and value
                let tstCookies = TestCookies(from: cookieStrings)
                let tstCookie = try XCTUnwrap(tstCookies["resp-cookie"]?.toCookie())
                XCTAssertEqual(tstCookie.maxAge, 600)
                XCTAssertEqual(tstCookie.domain, "example.com")
                XCTAssertEqual(tstCookie.path, "/")
                XCTAssertTrue(tstCookie.secure)
                XCTAssertTrue(tstCookie.httpOnly)
                XCTAssertEqual(tstCookie.sameSite, .lax)
            }
            
            var headers: HTTPFields = [.userAgent: "HBXCT/2.0", .acceptLanguage: "en", .cookie: "my-cookie-a=A;my-cookie-b=B"]
            headers[values: .acceptLanguage].append("fr")
            headers[values: .cookie].append("my-cookie-c=C")
            try await client.execute(uri: "/multi", method: .post, headers: headers) { response in
                XCTAssertEqual(response.statusCode, .ok)
                
                // Cookie Validation
                XCTAssertEqual(response.cookies?.count, 4, "Should only have 4 cookies")
                let cookieStrings = try XCTUnwrap(response.cookies)
                let cookies = try XCTUnwrap(Cookies(from: cookieStrings))
                let tstCookies = TestCookies(from: cookieStrings)

                let cookieNames = ["id_token","access_token","refresh_token","auth_nonce"]
                for cookieName in cookieNames {
                    let cookie = try XCTUnwrap(cookies[cookieName])
                    // TestCookies required because Cookies fails to load anything but name and value
                    let tstCookie = try XCTUnwrap(tstCookies[cookieName]?.toCookie())

                    XCTAssertEqual(cookie.name, cookieName)
                    XCTAssertEqual(cookie.value, "xxxxxxx")
                    XCTAssertEqual(tstCookie.maxAge, 600)
                    XCTAssertEqual(tstCookie.domain, "example.com")
                    XCTAssertEqual(tstCookie.path, "/")
                    XCTAssertTrue(tstCookie.secure)
                    XCTAssertTrue(tstCookie.httpOnly)
                    XCTAssertEqual(tstCookie.sameSite, .lax)
                }

                // Single Value Header Validation
                let cLang = try XCTUnwrap(response.headers?.first(name: "Content-Language"))
                XCTAssertEqual(cLang, "en, de, fr")

                // Multivalue Header Validation
                let acceptExpect = ["application/json", "text/html"]
                let accept = try XCTUnwrap(response.headers?.first(name: "Accept"))
                let acceptItems = accept.split(separator: ",")
                XCTAssertEqual(acceptItems.count, 2, "Should only have 2 Accept headers")
                for acceptExpt in acceptExpect {
                    XCTAssertTrue(acceptItems.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == acceptExpt }))
                }
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

    func testSimpleRouteURLFunction() async throws {
        let router = Router(context: BasicLambdaRequestContext<FunctionURLRequest>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ in
            XCTAssertEqual(request.head.authority, "127.0.0.1:8080")
            return ["response": "hello"]
        }
        let lambda = FunctionURLLambdaFunction(router: router)
        try await lambda.test { client in
            try await client.execute(uri: "/", method: .post) { response in
                XCTAssertEqual(response.statusCode, .ok)
                XCTAssertEqual(response.headers?["Content-Type"], "application/json; charset=utf-8")
                XCTAssertEqual(response.body, #"{"response":"hello"}"#)
            }
        }
    }

    func testBase64EncodingURLFunction() async throws {
        let router = Router(context: BasicLambdaRequestContext<FunctionURLRequest>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ in
            let buffer = try await request.body.collect(upTo: .max)
            return Response(status: .ok, body: .init(byteBuffer: buffer))
        }
        let lambda = FunctionURLLambdaFunction(router: router)
        try await lambda.test { client in
            let body = ByteBuffer(bytes: (0...255).map { _ in UInt8.random(in: 0...255) })
            try await client.execute(uri: "/", method: .post, headers: [.userAgent: "HBXCT/2.0"], body: body) { response in
                XCTAssertEqual(response.isBase64Encoded, true)
                XCTAssertEqual(response.body, Base64.encodeToString(bytes: body.readableBytesView))
            }
        }
    }

    func testHeaderValuesURLFunction() async throws {
        let router = Router(context: BasicLambdaRequestContext<FunctionURLRequest>.self)
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
        let lambda = FunctionURLLambdaFunction(router: router)
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

    func testQueryValuesURLFunction() async throws {
        let router = Router(context: BasicLambdaRequestContext<FunctionURLRequest>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.post { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.uri.queryParameters["foo"], "bar")
            return .ok
        }
        router.post("/multi") { request, _ -> HTTPResponse.Status in
            XCTAssertEqual(request.uri.queryParameters.getAll("foo"), ["bar1", "bar2"])
            return .ok
        }
        let lambda = FunctionURLLambdaFunction(router: router)
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

    func testBaforeLambdaStart() async throws {
        let beforeLambdaStartHasRun = Atomic(false)
        let router = Router(context: BasicLambdaRequestContext<APIGatewayRequest>.self)
        router.middlewares.add(LogRequestsMiddleware(.debug))
        router.get("hello") { request, _ in
            beforeLambdaStartHasRun.load(ordering: .relaxed).description
        }
        var lambda = APIGatewayLambdaFunction(router: router)
        lambda.beforeLambdaStarts {
            beforeLambdaStartHasRun.store(true, ordering: .relaxed)
        }
        try await lambda.test { client in
            try await client.execute(uri: "/hello", method: .get) { response in
                XCTAssertEqual(response.body, "true")
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
