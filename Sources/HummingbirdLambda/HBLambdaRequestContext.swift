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

/// A Request Context that is initialized with the Event that triggered the Lambda
///
/// All Hummingbird Lambdas require that your request context conforms to
/// `HBLambdaRequestContext`. By default ``HBLambda`` will use ``HBBasicLambdaRequestContext``
/// for a request context. To get ``HBLambda`` to use a custom context you need to set the
/// `Context` associatedtype.
public protocol LambdaRequestContext<Event>: BaseRequestContext {
    /// The type of event that can trigger the Lambda
    associatedtype Event

    init(_ event: Event, lambdaContext: LambdaContext)
}
