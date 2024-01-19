import AWSLambdaRuntimeCore
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
import Logging
import NIOCore

/// A Request Context that contains the Event that triggered the Lambda
public protocol HBLambdaRequestContext<Event>: HBBaseRequestContext {
    /// The type of event that can trigger the Lambda
    associatedtype Event

    init(_ event: Event, lambdaContext: LambdaContext)
}
