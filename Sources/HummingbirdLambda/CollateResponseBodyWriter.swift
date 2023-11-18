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
import HummingbirdCore

internal actor CollateResponseBodyWriter: HBResponseBodyWriter {
    var buffer: ByteBuffer

    init() {
        self.buffer = ByteBuffer()
    }

    func write(_ buffer: ByteBuffer) async throws {
        self.buffer.writeImmutableBuffer(buffer)
    }
}
