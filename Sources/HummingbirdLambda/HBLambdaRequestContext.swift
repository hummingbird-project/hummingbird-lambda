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

import Hummingbird
import Logging
import NIOCore

public struct LambdaRequestContextSource<Event>: RequestContextSource {
    public init(event: Event, lambdaContext: LambdaContext) {
        self.event = event
        self.lambdaContext = lambdaContext
    }

    public let event: Event
    public let lambdaContext: LambdaContext

    public var allocator: ByteBufferAllocator { lambdaContext.allocator }
    public var logger: Logger { lambdaContext.logger }
}

/// A Request Context that is initialized with the Event that triggered the Lambda
///
/// All Hummingbird Lambdas require that your request context conforms to
/// LambdaRequestContext`. By default ``LambdaFunction`` will use ``BasicLambdaRequestContext``
/// for a request context. To get ``LambdaFunction`` to use a custom context you need to set the
/// `Context` associatedtype.
public protocol LambdaRequestContext<Event>: BaseRequestContext where Source == LambdaRequestContextSource<Event> {
    associatedtype Event
}
