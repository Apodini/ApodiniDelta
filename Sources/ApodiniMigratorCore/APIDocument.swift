//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniTypeInformation

/// This enum describes the document format version of the ``APIDocument``.
/// ``APIDocumentVersion`` follows the SemVer versioning scheme.
public enum APIDocumentVersion: String, Codable {
    /// The original/legacy document format introduced with version 0.1.0.
    /// - Note: This version is assumed when no `version` field is present in the document root.
    ///     ApodiniMigrator supports parsing legacy documents till 0.3.0.
    case v1 = "1.0.0"
    /// The current document format introduced with version 0.2.0.
    case v2 = "2.0.0"
}

/// A API document describing an Apodini Web Service.
public struct APIDocument: Value {
    /// Id of the document
    public let id: UUID
    /// Metadata
    public var serviceInformation: ServiceInformation
    /// Endpoints
    private var _endpoints: [Endpoint]
    public var endpoints: [Endpoint] {
        _endpoints
            .map {
                var endpoint = $0
                endpoint.dereference(in: types)
                return endpoint
            }
    }

    private var types: TypesStore

    public var models: [TypeInformation] {
        Array(types.keys)
            .map { TypeInformation.reference($0) }
            .map { types.construct(from: $0) }
    }
    
    /// Name of the file, constructed as `api_{version}`
    public var fileName: String {
        "api_\(serviceInformation.version.string.replacingOccurrences(of: "_", with: ""))"
    }
    
    /// Initializes a new Apodini API document.
    public init(serviceInformation: ServiceInformation) {
        self.id = .init()
        self.serviceInformation = serviceInformation
        self._endpoints = []
        self.types = TypesStore()
    }
    
    /// Adds a new endpoint
    public mutating func add(endpoint: Endpoint) {
        precondition(
            !_endpoints.contains(where: { $0.deltaIdentifier == endpoint.deltaIdentifier }),
            "Tried adding `Endpoint` to `APIDocument` with colliding identifiers (or just added it twice)."
        )

        var endpoint = endpoint
        endpoint.reference(in: &types)
        _endpoints.append(endpoint)
    }

    public mutating func add<Configuration: ExporterConfiguration>(exporter: Configuration) {
        serviceInformation.add(exporter: exporter)
    }
}

// MARK: Codable
extension APIDocument: Codable {
    public enum CodingError: Error {
        case unsupportedDocumentVersion(version: String)
    }

    // MARK: Private Inner Types
    private enum CodingKeys: String, CodingKey {
        case id
        case documentVersion = "version"
        case serviceInformation = "service"
        case endpoints
        case types

        case legacyServiceInformation = "info"
        case legacyTypes = "components"
    }

    /// Creates a new instance by decoding from the given decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let documentVersion: APIDocumentVersion
        do {
            try documentVersion = container.decodeIfPresent(APIDocumentVersion.self, forKey: .documentVersion) ?? .v1
        } catch {
            // failed to decode APIDocumentVersion, probably because its an unknown version!
            throw CodingError.unsupportedDocumentVersion(version: try container.decode(String.self, forKey: .documentVersion))
        }

        try id = container.decode(UUID.self, forKey: .id)

        switch documentVersion {
        case .v1:
            let legacyInformation = try container.decode(LegacyServiceInformation.self, forKey: .legacyServiceInformation)
            try self.serviceInformation = ServiceInformation(from: legacyInformation)

            let endpoints = try container.decode([LegacyEndpoint].self, forKey: .endpoints)
            self._endpoints = endpoints.map { Endpoint(from: $0) }

            try types = container.decode(TypesStore.self, forKey: .legacyTypes)
        case .v2:
            try serviceInformation = container.decode(ServiceInformation.self, forKey: .serviceInformation)
            try _endpoints = container.decode([Endpoint].self, forKey: .endpoints)
            try types = container.decode(TypesStore.self, forKey: .types)
        }
    }

    /// Encodes self into the given encoder.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(APIDocumentVersion.v2, forKey: .documentVersion)
        try container.encode(serviceInformation, forKey: .serviceInformation)
        try container.encode(_endpoints, forKey: .endpoints)
        try container.encode(types, forKey: .types)
    }
}