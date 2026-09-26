//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HummingbirdLambda
public import Logging

extension LambdaFunctionProtocol where Event: LambdaTestableEvent {
    /// Test `LambdaFunction`
    ///
    /// The `test` closure provides a test client to make calls to the
    /// lambda via `execute`. You can verify the contents of the output
    /// event returned.
    ///
    /// ```swift
    /// let router = Router(context: Context.self)
    /// router.get("hello") { request, _ in
    ///     return "Hello"
    /// }
    /// let lambda = LambdaFunction(router: router)
    /// try await lambda.test { client in
    ///     try await client.execute(uri: "/hello", method: .get) { response in
    ///         XCTAssertEqual(response.body, "Hello")
    ///     }
    /// }
    /// ```
    public func test<Value>(
        logLevel: Logger.Level = .debug,
        _ test: @escaping @Sendable (LambdaTestClient<Self>) async throws -> Value
    ) async throws -> Value {
        let lambda = LambdaTestFramework(lambda: self)
        return try await lambda.run(test)
    }
}
