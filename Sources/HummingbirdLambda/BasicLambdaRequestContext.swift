//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

import Hummingbird
import Logging
import NIOCore

/// The default Lambda request context.
///
/// This context contains the event that triggered the lambda.
public struct BasicLambdaRequestContext<Event: Sendable>: LambdaRequestContext {
    /// The Event that triggered the Lambda
    public let event: Event

    public var coreContext: CoreRequestContextStorage

    /// Initialize Lambda request context
    public init(source: Source) {
        self.event = source.event
        self.coreContext = .init(source: source)
    }
}
