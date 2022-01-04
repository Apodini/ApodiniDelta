//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import OrderedCollections

/// Represents an endpoint
public struct Endpoint: Value, DeltaIdentifiable {
    /// Identifier of the handler
    public let deltaIdentifier: DeltaIdentifier

    /// Storage structure for any kind of identifier of a ``Endpoint``.
    /// Use ``add(identifier:)`` to add any ``EndpointIdentifier``s.
    /// Every ``Endpoint`` has the following identifiers by standard:
    ///  - ``TypeName`` (for the handlerName)
    ///  - ``Operation``
    ///  - ``EndpointPath``
    ///
    /// Use ``identifier(for:)`` or ``identifierIfAvailable(for:)`` to retrieve an ``EndpointIdentifier``.
    /// Or use ``handlerName``, ``operation`` or ``path`` computed properties for quick access.
    public var identifiers: OrderedDictionary<String, AnyEndpointIdentifier>

    /// The communicational pattern of the endpoint.
    public let communicationalPattern: CommunicationalPattern
    /// Parameters of the endpoint
    public var parameters: [Parameter]
    /// The reference of the `typeInformation` of the response
    public var response: TypeInformation
    /// Errors
    public let errors: [ErrorCode]

    public var handlerName: TypeName {
        self.identifier()
    }

    public var operation: Operation {
        self.identifier()
    }

    public var path: EndpointPath {
        self.identifier()
    }
    
    /// Initializes a new endpoint instance
    public init(
        handlerName: String,
        deltaIdentifier: String,
        operation: Operation,
        communicationalPattern: CommunicationalPattern,
        absolutePath: String,
        parameters: [Parameter],
        response: TypeInformation,
        errors: [ErrorCode]
    ) {
        let typeName = TypeName(rawValue: handlerName)

        var identifier = deltaIdentifier
        // checks for "x.x.x." style Apodini identifiers!
        if !identifier.split(separator: ".").compactMap({ Int($0) }).isEmpty {
            identifier = typeName.buildName()
        }

        self.deltaIdentifier = .init(identifier)
        self.identifiers = [:]

        self.parameters = Self.wrapContentParameters(from: parameters, with: typeName.buildName())
        self.communicationalPattern = communicationalPattern
        self.response = response
        self.errors = errors

        self.add(identifier: typeName)
        self.add(identifier: operation)
        self.add(identifier: EndpointPath(absolutePath))
    }

    /// Initializes a new endpoint instance
    public init(
        handlerName: TypeName,
        deltaIdentifier: String,
        operation: Operation,
        communicationalPattern: CommunicationalPattern,
        absolutePath: String,
        parameters: [Parameter],
        response: TypeInformation,
        errors: [ErrorCode]
    ) {
        self.init(
            handlerName: handlerName.rawValue,
            deltaIdentifier: deltaIdentifier,
            operation: operation,
            communicationalPattern: communicationalPattern,
            absolutePath: absolutePath,
            parameters: parameters,
            response: response,
            errors: errors
        )
    }

    public mutating func add<Identifier: EndpointIdentifier>(identifier: Identifier) {
        self.identifiers[Identifier.identifierType] = AnyEndpointIdentifier(from: identifier)
    }

    public func identifierIfPresent<Identifier: EndpointIdentifier>(for type: Identifier.Type = Identifier.self) -> Identifier? {
        guard let rawValue = self.identifiers[Identifier.identifierType]?.value else {
            return nil
        }

        return Identifier(rawValue: rawValue)
    }

    public func identifier<Identifier: EndpointIdentifier>(for type: Identifier.Type = Identifier.self) -> Identifier {
        guard let identifier = identifierIfPresent(for: Identifier.self) else {
            fatalError("Failed to retrieve required Identifier \(type) which wasn't present on endpoint \(deltaIdentifier).")
        }

        return identifier
    }
    
    mutating func dereference(in typeStore: TypesStore) {
        response = typeStore.construct(from: response)
        self.parameters = parameters.map {
            var param = $0
            param.dereference(in: typeStore)
            return param
        }
    }
    
    mutating func reference(in typeStore: inout TypesStore) {
        response = typeStore.store(response)
        self.parameters = parameters.map {
            var param = $0
            param.reference(in: &typeStore)
            return param
        }
    }
    
    /// Returns a version of self where occurrences of type information (response or parameters) are references
    public func referencedTypes() -> Endpoint {
        var retValue = self
        var typesStore = TypesStore()
        retValue.reference(in: &typesStore)
        return retValue
    }
}

// MARK: Codable
extension Endpoint: Codable {
    private enum CodingKeys: String, CodingKey {
        case deltaIdentifier
        case identifiers
        case communicationalPattern
        case parameters
        case response
        case errors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.deltaIdentifier = try container.decode(DeltaIdentifier.self, forKey: .deltaIdentifier)
        self.identifiers = try container.decode([String: String].self, forKey: .identifiers)
            .reduce(into: [:]) { result, entry in
                result[entry.key] = AnyEndpointIdentifier(id: entry.key, value: entry.value)
            }
        self.communicationalPattern = try container.decode(CommunicationalPattern.self, forKey: .communicationalPattern)
        self.parameters = try container.decode([Parameter].self, forKey: .parameters)
        self.response = try container.decode(TypeInformation.self, forKey: .response)
        self.errors = try container.decode([ErrorCode].self, forKey: .errors)
    }

    public func encode(to encoder: Encoder) throws {
        struct AnyCodingKey: CodingKey {
            var stringValue: String

            init(stringValue: String) {
                self.stringValue = stringValue
            }

            var intValue: Int? {
                fatalError("Can't access intValue for AnyCodingKey!")
            }

            init?(intValue: Int) {
                fatalError("Can't init from intValue for AnyCodingKey!")
            }
        }

        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(deltaIdentifier, forKey: .deltaIdentifier)
        
        var identifierContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .identifiers)
        var sortedIdentifiers = self.identifiers
        sortedIdentifiers.sort()
        for (key, value) in sortedIdentifiers {
            try identifierContainer.encode(value.value, forKey: AnyCodingKey(stringValue: key))
        }

        try container.encode(communicationalPattern, forKey: .communicationalPattern)
        try container.encode(parameters, forKey: .parameters)
        try container.encode(response, forKey: .response)
        try container.encode(errors, forKey: .errors)
    }
}

// MARK: Equatable
extension Endpoint: Equatable {
    public static func == (lhs: Endpoint, rhs: Endpoint) -> Bool {
        var lhsIdentifiers = lhs.identifiers
        var rhsIdentifiers = rhs.identifiers
        lhsIdentifiers.sort()
        rhsIdentifiers.sort()

        return lhs.deltaIdentifier == rhs.deltaIdentifier
            && lhsIdentifiers == rhsIdentifiers
            && lhs.communicationalPattern == rhs.communicationalPattern
            && lhs.parameters == rhs.parameters
            && lhs.response == rhs.response
            && lhs.errors == rhs.errors
    }
}

private extension Endpoint {
    // TODO this is REST specific! we have something similar (Parameter Wrapping) for GRPC
    static func wrapContentParameters(from parameters: [Parameter], with handlerName: String) -> [Parameter] {
        let contentParameters = parameters.filter { $0.parameterType == .content }
        guard !contentParameters.isEmpty else {
            return parameters
        }
        
        var contentParameter: Parameter?
        
        switch contentParameters.count {
        case 1:
            contentParameter = contentParameters.first
        default:
            let typeInformation = TypeInformation.object(
                name: Parameter.wrappedContentParameterTypeName(from: handlerName),
                properties: contentParameters.map {
                    TypeProperty(
                        name: $0.name,
                        type: $0.necessity == .optional ? $0.typeInformation.asOptional : $0.typeInformation
                    )
                }
            )
            
            contentParameter = .init(
                name: Parameter.wrappedContentParameter,
                typeInformation: typeInformation,
                parameterType: .content,
                isRequired: contentParameters.contains(where: { $0.necessity == .required })
            )
        }
        
        var result = parameters.filter { $0.parameterType != .content }
        
        contentParameter.map {
            result.append($0)
        }
        
        return result
    }
}
