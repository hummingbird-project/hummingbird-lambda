//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Hummingbird

extension HBHTTPError {
    /// Generate response from error
    /// - Parameter allocator: Byte buffer allocator used to allocate message body
    /// - Returns: Response
    public func response(allocator: ByteBufferAllocator) -> HBResponse {
        var headers: HTTPHeaders = self.headers
        let body: HBResponseBody

        if let message = self.body {
            let buffer = allocator.buffer(string: message)
            body = .init(byteBuffer: buffer)
            headers.replaceOrAdd(name: "content-length", value: buffer.readableBytes.description)
        } else {
            body = .init()
        }

        return .init(status: status, headers: headers, body: body)
    }
}
