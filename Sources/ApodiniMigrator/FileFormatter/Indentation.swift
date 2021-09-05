//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// An object representing a spacer / indentation in a swift file
struct Indentation: CustomStringConvertible {
    /// A space string with length of 4
    static let tab = String(repeating: " ", count: 4)
    /// A placeholder to add indentation to lines that start with a `.`, since the current logic of `IndentationFormatter` can't handle those cases
    static let placeholder = "____INDENTATION____"
    /// A placeholder to indicate to `IndentationFormatter` to ignore one level of indentation for the lines that start with `Indentation.skip`
    static let skip = "____SKIP____"

    /// The level of the indentation
    private var level: UInt
    
    /// Complete space of this indentation, repeating `Indentation.tab` `level`-times
    var description: String {
        String(repeating: Self.tab, count: Int(level))
    }
    
    // MARK: - Initializer
    init(_ level: UInt) {
        self.level = level
    }
    
    
    /// Decreases level by one
    mutating func dropLevel() {
        level = level > 0 ? level - 1 : 0
    }
    
    /// Adds indentation to `rhs`
    static func + (lhs: Self, rhs: String) -> String {
        lhs.description + rhs
    }
}
