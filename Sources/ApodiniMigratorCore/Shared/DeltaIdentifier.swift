//
//  DeltaIdentifier.swift
//  ApodiniMigratorCore
//
//  Created by Eldi Cano on 29.06.21.
//  Copyright © 2021 TUM LS1. All rights reserved.
//

import Foundation

/// A protocol, that requires conforming objects to introduce a `DeltaIdentifier` property
public protocol DeltaIdentifiable {
    /// Delta identifier
    var deltaIdentifier: DeltaIdentifier { get }
}

/// A `DeltaIdentifier` uniquely identifies an object in ApodiniDelta
public struct DeltaIdentifier: Value, RawRepresentable {
    /// Raw value
    public let rawValue: String

    /// Initializes self from a rawValue
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Initializes self from a rawValue
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
    
    /// Initializes self from a RawRepresentable instance with string raw value
    public init<R: RawRepresentable>(_ rawRepresentable: R) where R.RawValue == String {
        self.rawValue = rawRepresentable.rawValue
    }

    /// Creates a new instance by decoding from the given decoder.
    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    /// Encodes self into the given encoder.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public extension Array where Element: DeltaIdentifiable {
    func identifiers() -> [DeltaIdentifier] {
        map { $0.deltaIdentifier }
    }
}

// MARK: - ExpressibleByStringLiteral
extension DeltaIdentifier: ExpressibleByStringLiteral {
    /// Creates an instance initialized to the given string value.
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension DeltaIdentifier: CustomStringConvertible {
    /// String representation of self
    public var description: String { rawValue }
}

extension DeltaIdentifier {
    /// :nodoc:
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

extension DeltaIdentifier: Comparable {
    /// :nodoc:
    public static func < (lhs: DeltaIdentifier, rhs: DeltaIdentifier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

extension DeltaIdentifier {
    /// :nodoc:
    public static func == (lhs: DeltaIdentifier, rhs: DeltaIdentifier) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}