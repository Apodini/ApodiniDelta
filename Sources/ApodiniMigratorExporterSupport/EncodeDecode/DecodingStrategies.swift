//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// A custom `DateEncodingStrategy` of `JSONDecoder`
/// - Note: Does not support `.formatted` and `.custom` cases of `JSONDecoder`
public enum DateDecodingStrategy: String, Codable, Equatable {
    /// Defer to `Date` for decoding. This is the default strategy.
    case deferredToDate

    /// Decode the `Date` as a UNIX timestamp from a JSON number.
    case secondsSince1970

    /// Decode the `Date` as UNIX millisecond timestamp from a JSON number.
    case millisecondsSince1970

    /// Encode the `Date` as an ISO-8601-formatted string (in RFC 3339 format) on available platforms. If not available, `.deferredToDate` is used
    case iso8601

    init(from strategy: JSONDecoder.DateDecodingStrategy) {
        switch strategy {
        case .deferredToDate:
            self = .deferredToDate
        case .secondsSince1970:
            self = .secondsSince1970
        case .millisecondsSince1970:
            self = .millisecondsSince1970
        case .iso8601:
            self = .iso8601
        default:
            self = .deferredToDate
        }
    }

    /// Corresponding strategy of `JSONDecoder`
    var toJSONDecoderStrategy: JSONDecoder.DateDecodingStrategy {
        switch self {
        case .deferredToDate:
            return .deferredToDate
        case .secondsSince1970:
            return .secondsSince1970
        case .millisecondsSince1970:
            return .millisecondsSince1970
        case .iso8601:
            return .iso8601
        }
    }
}

/// A custom `DataDecodingStrategy` of `JSONDecoder`
/// - Note: Does not support `.custom` case `JSONDecoder`
public enum DataDecodingStrategy: String, Codable, Equatable {
    /// Defer to `Data` for decoding.
    case deferredToData

    /// Decode the `Data` from a Base64-encoded string. This is the default strategy.
    case base64

    init(from strategy: JSONDecoder.DataDecodingStrategy) {
        switch strategy {
        case .deferredToData:
            self = .deferredToData
        case .base64:
            self = .base64
        default:
            self = .deferredToData
        }
    }

    /// Corresponding strategy of `JSONDecoder`
    var toJSONDecoderStrategy: JSONDecoder.DataDecodingStrategy {
        switch self {
        case .deferredToData:
            return .deferredToData
        case .base64:
            return .base64
        }
    }
}

/// A configuration object for `JSONDecoder`
public struct DecoderConfiguration: Codable, Hashable {
    /// `dateEncodingStrategy` to be set to a `JSONDecoder`
    public let dateDecodingStrategy: DateDecodingStrategy
    /// `dataEncodingStrategy` to be set to a `JSONDecoder`
    public let dataDecodingStrategy: DataDecodingStrategy
    
    
    /// Initializer of a `DecoderConfiguration` instance
    public init(dateDecodingStrategy: DateDecodingStrategy, dataDecodingStrategy: DataDecodingStrategy) {
        self.dateDecodingStrategy = dateDecodingStrategy
        self.dataDecodingStrategy = dataDecodingStrategy
    }

    public init(derivedFrom decoder: JSONDecoder) {
        self.dateDecodingStrategy = .init(from: decoder.dateDecodingStrategy)
        self.dataDecodingStrategy = .init(from: decoder.dataDecodingStrategy)
    }
    
    /// `default` configuration of a `JSONDecoder`
    public static var `default`: DecoderConfiguration {
        .init(dateDecodingStrategy: .deferredToDate, dataDecodingStrategy: .base64)
    }
}

/// JSONDecoder extension
public extension JSONDecoder {
    /// Configures `self` with the properties of `DecoderConfiguration`
    @discardableResult
    func configured(with configuration: DecoderConfiguration) -> JSONDecoder {
        dateDecodingStrategy = configuration.dateDecodingStrategy.toJSONDecoderStrategy
        dataDecodingStrategy = configuration.dataDecodingStrategy.toJSONDecoderStrategy
        return self
    }
}
