//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// Describes a set of identifiers for a `TypeInformation`
public protocol TypeIdentifiersDescription {
    /// The `ElementIdentifier`s stored in the `ElementIdentifierStorage` concerning the `Context` of the root `TypeInformation`.
    var identifiers: ElementIdentifierStorage { get }
    /// The individual `ElementIdentifierStorage`s concerning the children of the type (e.g. properties or enum cases).
    var childrenIdentifiers: [String: ElementIdentifierStorage] { get }
}

public extension TypeInformation {
    /// Write the identifiers of a `TypeIdentifiersDescription` into the `Context`s of the `TypeInformation` (and its children).
    /// - Parameter retrieveIdentifiers: A closure which returns the matching `TypeIdentifiersDescription` for the given `TypeInformation`.
    func augmentTypeWithIdentifiers(retrieveIdentifiers: (TypeInformation) -> TypeIdentifiersDescription?) {
        // swiftlint:disable:previous cyclomatic_complexity
        // disabled for compactness reasons

        switch self {
        case let .enum(_, _, cases, context):
            guard let identifiers = retrieveIdentifiers(self) else {
                break
            }

            // we might have multiple endpoints with the same return type.
            // This checks for possible duplications.
            if !context.get(valueFor: TypeInformationIdentifierContextKey.self).isEmpty {
                break
            }

            context.unsafeAdd(TypeInformationIdentifierContextKey.self, value: identifiers.identifiers)

            for (key, storage) in identifiers.childrenIdentifiers {
                guard let enumCase = cases.first(where: { $0.name == key }) else {
                    fatalError("Another exporter added enum case identifiers for a case we can't identify: \(key) adding \(storage)")
                }

                enumCase.context.unsafeAdd(TypeInformationIdentifierContextKey.self, value: storage)
            }
        case let .object(_, properties, context):
            guard let identifiers = retrieveIdentifiers(self) else {
                break
            }

            // we might have multiple endpoints with the same return type.
            // This checks for possible duplications.
            if !context.get(valueFor: TypeInformationIdentifierContextKey.self).isEmpty {
                break
            }

            context.unsafeAdd(TypeInformationIdentifierContextKey.self, value: identifiers.identifiers)

            for (key, storage) in identifiers.childrenIdentifiers {
                guard let property = properties.first(where: { $0.name == key }) else {
                    fatalError("Another exporter added property identifiers for a property we can't identify: \(key) adding \(storage)")
                }

                property.context.unsafeAdd(TypeInformationIdentifierContextKey.self, value: storage)
            }
        case let .optional(wrappedValue):
            return wrappedValue.augmentTypeWithIdentifiers(retrieveIdentifiers: retrieveIdentifiers)
        case let .repeated(element):
            return element.augmentTypeWithIdentifiers(retrieveIdentifiers: retrieveIdentifiers)
        case let .dictionary(_, value):
            return value.augmentTypeWithIdentifiers(retrieveIdentifiers: retrieveIdentifiers)
        case .scalar:
            break // do nothing on a scalar
        case .reference:
            fatalError("Unexpected referenced \(self) which we can't follow!")
        }
    }
}
