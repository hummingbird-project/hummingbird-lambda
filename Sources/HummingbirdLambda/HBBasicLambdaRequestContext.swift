//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaRuntimeCore
import Foundation
import Hummingbird
import HummingbirdFoundation
import Logging
import NIOCore

/// The default Lambda request context.
///
/// This context contains the ``HBBasicLambdaRequestContext/Event`` that triggered the lambda.
public struct HBBasicLambdaRequestContext<Event: Sendable>: HBLambdaRequestContext {
    /// The Event that triggered the Lambda
    public let event: Event

    public var coreContext: HBCoreRequestContext
    public var requestDecoder: JSONDecoder { .init() }
    public var responseEncoder: JSONEncoder { .init() }

    /// Initialize Lambda request context
    public init(_ event: Event, lambdaContext: LambdaContext) {
        self.event = event
        self.coreContext = .init(
            allocator: lambdaContext.allocator,
            logger: lambdaContext.logger
        )
    }
}
