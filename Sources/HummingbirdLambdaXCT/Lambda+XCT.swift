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
    public static func test<Value>(
        logLevel: Logger.Level = .debug,
        _ test: @escaping @Sendable (HBXCTLambdaClient<Self>) async throws -> Value
    ) async throws -> Value {
        let lambda = HBXCTLambda<Self>(logLevel: logLevel)
        return try await lambda.run(test)
    }
}
