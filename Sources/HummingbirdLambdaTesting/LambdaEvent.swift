//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

public import HTTPTypes
public import NIOCore

/// Lambda event that can be used with HummingbirdLambdaTesting
public protocol LambdaTestableEvent {
    init(uri: String, method: HTTPRequest.Method, headers: HTTPFields, body: ByteBuffer?) throws
}
