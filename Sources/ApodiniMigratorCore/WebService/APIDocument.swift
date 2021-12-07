//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniTypeInformation

public enum DocumentVersion: String, Codable {
    // TODO make this more SemVer style (e.g. allow shorter versions strings e.g. "1" => "1.0.0"
    case v1 = "1.0.0"
    case v2 = "2.0.0"
}

/// A API document describing an Apodini Web Service.
public struct APIDocument: Value {
    public enum CodingError: Error {
        case encodingUnsupportedExporterConfiguration(exporter: ExporterConfiguration)
        case decodingUnsupportedExporterConfiguration
        case unsupportedDocumentVersion(version: DocumentVersion)
    }

    // MARK: Private Inner Types
    private enum CodingKeys: String, CodingKey {
        case id
        case documentVersion = "version"
        case serviceInformation = "service"
        case endpoints
        case types
    }
    
    /// Id of the document
    public let id: UUID // TODO how do we generate the Id (and persist it in API documents)
    /// Describes the version the ``Document`` was generate with
    public let documentVersion: DocumentVersion // TODO we don't really need this property?
    /// Metadata
    public var serviceInformation: ServiceInformation
    /// Endpoints
    public var endpoints: [Endpoint]

    // TODO turn into property (and maybe split up into response and parameters)
    public func allModels() -> [TypeInformation] {
        endpoints.reduce(into: Set<TypeInformation>()) { result, current in
                result.insert(current.response)
                current.parameters.forEach { parameter in
                    result.insert(parameter.typeInformation)
                }
            }
            .asArray
            .fileRenderableTypes()
            .sorted(by: \.typeName)
    }
    
    /// Name of the file, constructed as `api_{version}`
    public var fileName: String {
        "api_\(serviceInformation.version.string.replacingOccurrences(of: "_", with: ""))"
    }
    
    /// Initializes a new Apodini API document.
    public init(serviceInformation: ServiceInformation) {
        id = .init()
        documentVersion = .v2
        self.serviceInformation = serviceInformation
        endpoints = []
    }
    
    /// Adds a new endpoint
    public mutating func add(endpoint: Endpoint) {
        endpoints.append(endpoint)
    }

    public mutating func add<Configuration: ExporterConfiguration>(exporter: Configuration) {
        // TODO non generic func?
        serviceInformation.exporters.append(exporter)
    }
    
    /// Encodes self into the given encoder.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(documentVersion, forKey: .documentVersion)
        try container.encode(serviceInformation, forKey: .serviceInformation)

        var typesStore = TypesStore()
        let referencedEndpoints: [Endpoint] = endpoints.map {
            var endpoint = $0
            endpoint.reference(in: &typesStore)
            return endpoint
        }
        
        try container.encode(referencedEndpoints, forKey: .endpoints)
        try container.encode(typesStore.storage, forKey: .types)
    }
    
    /// Creates a new instance by decoding from the given decoder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        try documentVersion = container.decodeIfPresent(DocumentVersion.self, forKey: .documentVersion) ?? .v1
        guard case .v2 = documentVersion else {
            throw CodingError.unsupportedDocumentVersion(version: documentVersion)
        }

        try id = container.decode(UUID.self, forKey: .id)
        try serviceInformation = container.decode(ServiceInformation.self, forKey: .serviceInformation)

        var typesStore = TypesStore()
        try typesStore.storage = container.decode([String: TypeInformation].self, forKey: .types)

        let endpoints = try container.decode([Endpoint].self, forKey: .endpoints)
        self.endpoints = endpoints.map {
            var endpoint = $0
            endpoint.dereference(in: &typesStore)
            return endpoint
        }
    }
}
