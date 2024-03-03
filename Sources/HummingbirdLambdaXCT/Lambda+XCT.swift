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

import HummingbirdLambda
import Logging

extension HBLambda where Event: XCTLambdaEvent {
    /// Test `HBLambda`
    ///
    /// The `test` closure uses the provided test client to make calls to the
    /// lambda via `XCTExecute`. You can verify the contents of the output
    /// event returned.
    ///
    /// The example below is using the `.router` framework to test
    /// ```swift
    /// struct HelloLambda: HBAPIGatewayLambda {
    ///     init(context: LambdaInitializationContext) {}
    ///
    ///     func buildResponder() -> some HBResponder<Context> {
    ///         let router = HBRouter(context: Context.self)
    ///         router.get("hello") { request, _ in
    ///             return "Hello"
    ///         }
    ///         return router.buildResponder()
    ///     }
    /// }
    /// try await HelloLambda.test { client in
    ///     try await client.XCTExecute(uri: "/hello", method: .get) { response in
    ///         XCTAssertEqual(response.body, "Hello")
    ///     }
    /// }
    /// ```
    public static func test<Value>(
        logLevel: Logger.Level = .debug,
        _ test: @escaping @Sendable (HBXCTLambdaClient<Self>) async throws -> Value
    ) async throws -> Value {
        let lambda = HBXCTLambda<Self>(logLevel: logLevel)
        return try await lambda.run(test)
    }
}
