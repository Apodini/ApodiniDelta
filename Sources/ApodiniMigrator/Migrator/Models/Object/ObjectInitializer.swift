//
//  ObjectInitializer.swift
//  ApodiniMigrator
//
//  Created by Eldi Cano on 23.08.21.
//  Copyright © 2021 TUM LS1. All rights reserved.
//

import Foundation

/// Represents initializer of an object
struct ObjectInitializer: Renderable {
    /// All properties of the object that this initializer belongs to (including added and deleted properties
    private let properties: [TypeProperty]
    /// Dictionary of default values of the added properties of the object
    private var defaultValues: [DeltaIdentifier: ChangeValue]
    
    /// Initializes a new instance out of old properties of the object and the added properties
    init(_ properties: [TypeProperty], addedProperties: [AddedProperty] = []) {
        var allProperties = properties
        defaultValues = [:]
        for added in addedProperties {
            defaultValues[added.typeProperty.deltaIdentifier] = added.defaultValue
            allProperties.append(added.typeProperty)
        }
        self.properties = allProperties.sorted(by: \.name)
    }
    
    /// Renders the content of the initializer in a non-formatted way
    func render() -> String {
        """
        public init(
        \(properties.map { "\($0.name): \(defaultValue(for: $0))" }.joined(separator: ",\(String.lineBreak)"))
        ) {
        \(properties.map { "\($0.initLine)" }.lineBreaked)
        }
        """
    }
    
    /// Returns the string of the type of the property appending a corresponding default value for added properties as provided in the migration guide
    private func defaultValue(for property: TypeProperty) -> String {
        var typeString = property.type.typeString
        if let defaultValue = defaultValues[property.deltaIdentifier] {
            let defaultValueString: String
            if case let .json(id) = defaultValue {
                defaultValueString = "try! \(typeString).instance(from: \(id))"
            } else {
                defaultValueString = "nil"
            }
            typeString += " = \(defaultValueString)"
        }
        return typeString
    }
}

/// TypeProperty extension
extension TypeProperty {
    /// The corresponding line of the property to be rendered inside `init`
    var initLine: String {
        "self.\(name) = \(name)"
    }
}
