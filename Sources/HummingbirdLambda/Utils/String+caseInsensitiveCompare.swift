//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

extension StringProtocol {
    @inlinable
    package func _lambdaCaseInsensitiveCompare<OtherString: StringProtocol>(_ other: OtherString) -> Bool {
        guard self.count == other.count else { return false }

        var iterator = self.makeIterator()
        var otherIterator = other.makeIterator()
        while let c = iterator.next() {
            let otherC = otherIterator.next()!
            if c.lowercased() != otherC.lowercased() {
                return false
            }
        }
        return true
    }
}
