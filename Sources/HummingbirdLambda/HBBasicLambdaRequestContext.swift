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
import Logging
import NIOCore

/// The default Lambda request context.
///
/// This context contains the event that triggered the lambda.
public struct BasicLambdaRequestContext<Event: Sendable>: LambdaRequestContext {
    /// The Event that triggered the Lambda
    public let event: Event

    public var coreContext: CoreRequestContext

    /// Initialize Lambda request context
    public init(source: Source) {
        self.event = source.event
        self.coreContext = .init(source: source)
    }
}
