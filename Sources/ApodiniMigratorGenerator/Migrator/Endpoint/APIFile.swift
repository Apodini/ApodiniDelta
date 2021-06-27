//
//  File.swift
//  
//
//  Created by Eldi Cano on 27.06.21.
//

import Foundation

/// Represents the `API.swift` file of the client library
struct APIFile: SwiftFileTemplate {
    /// TypeInformation is a caseless enum named `API`
    let typeInformation: TypeInformation = .enum(name: .init(name: "API"), cases: [])
    /// Kind of the file
    let kind: Kind = .enum
    /// All migrated endpoints of the library
    let endpoints: [MigratedEndpoint]

    /// Initializes a new instance out all the migrated endpoints of the library
    init(_ endpoints: [MigratedEndpoint]) {
        self.endpoints = endpoints.sorted()
    }

    /// Renderes the wrapper method for the `migratedEndpoint`
    private func method(for migratedEndpoint: MigratedEndpoint) -> String {
        if migratedEndpoint.unavailable {
            return migratedEndpoint.unavailableBody()
        }
        let endpoint = migratedEndpoint.endpoint
        let nestedType = endpoint.response.nestedType.typeName.name
        var bodyInput = migratedEndpoint.parameters.map { "\($0.oldName): \($0.oldName)"}
        bodyInput.append(contentsOf: DefaultEndpointInput.allCases.map { $0.keyValue })
        let body =
        """
        \(migratedEndpoint.signature())
        \(nestedType).\(endpoint.deltaIdentifier)(\(String.lineBreak)\(bodyInput.joined(separator: ",\(String.lineBreak)"))\(String.lineBreak))
        }
        """
        return body
    }

    /// Renderes the content of the file
    public func render() -> String {
        """
        \(fileComment)

        \(Import(.foundation).render())

        \(MARKComment(typeNameString))
        \(kind.signature) \(typeNameString) {}

        \(MARKComment(.endpoints))
        \(Kind.extension.signature) \(typeNameString) {
        \(endpoints.map { method(for: $0) }.joined(separator: .doubleLineBreak))
        }
        """
    }
}