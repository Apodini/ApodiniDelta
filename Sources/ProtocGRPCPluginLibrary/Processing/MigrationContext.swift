//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigrator

extension TypeInformationIdentifiers: TypeIdentifiersDescription {}

struct MigrationContext {
    /// The base `APIDocument`
    let document: APIDocument
    /// The `MigrationGuide`
    private(set) var migrationGuide: MigrationGuide
    /// This is a custom TypeStore we maintain which combines the `TypeStore` from the `APIDocument`
    /// and all types which are newly introduced via the `MigrationGuide`.
    /// This TypeStore also contains the wrapper types created through the `ParameterCombination`.
    let typeStore: TypesStore

    let lhsExporterConfiguration: GRPCExporterConfiguration
    let rhsExporterConfiguration: GRPCExporterConfiguration

    init(document: APIDocument, migrationGuide: MigrationGuide) {
        let lhsConfiguration = document.serviceInformation.exporter(for: GRPCExporterConfiguration.self)
        let rhsConfiguration = document.serviceInformation.exporter(for: GRPCExporterConfiguration.self, migrationGuide: migrationGuide)

        var document = document
        var migrationGuide = migrationGuide

        document.applyEndpointParameterCombination(
            considering: &migrationGuide,
            using: GRPCMethodParameterCombination(
                typeStore: document.typeStore,
                lhs: lhsConfiguration,
                rhs: rhsConfiguration,
                migrationGuide: migrationGuide
            )
        )

        document.applyEndpointResponseTypeWrapping(
            considering: &migrationGuide,
            using: GRPCMethodResponseWrapping(lhs: lhsConfiguration, rhs: rhsConfiguration, migrationGuide: migrationGuide)
        )

        // it is important that we pull out the typeStore only after the `ParameterCombination` has run.
        // Above operation will store new types (only for the endpoints which are part of the APIDocument!!)
        // which will be stored there. Endpoint Parameter will have `.reference` type.
        var typeStore = document.typeStore

        // Now we add all the newly introduced types contained in the migration guide to the custom maintained `TypeStore`.
        // This is important as e.g. newly added Endpoints will contain reference types which we need to resolved!
        for change in migrationGuide.modelChanges {
            guard let addition = change.modeledAdditionChange else {
                continue
            }

            _ = typeStore.store(addition.added)
        }

        self.document = document
        self.migrationGuide = migrationGuide
        self.typeStore = typeStore
        self.lhsExporterConfiguration = lhsConfiguration
        self.rhsExporterConfiguration = rhsConfiguration

        computeIdentifiersOfSynthesizedEndpointTypes()
    }

    private mutating func computeIdentifiersOfSynthesizedEndpointTypes() {
        for endpoint in document.endpoints {
            let swiftTypeName = endpoint.swiftTypeName
            let updatedSwiftTypeName = endpoint.updatedSwiftTypeName(considering: migrationGuide)

            guard let lhsIdentifiers = lhsExporterConfiguration.identifiersOfSynthesizedTypes[swiftTypeName] else {
                continue // happens when neither input nor output type of an endpoint is synthesized
            }

            // we have the base type which didn't change, which we augment with the base identifiers
            _augmentIdentifiersOfSynthesizedTypes(of: endpoint, with: lhsIdentifiers)

            guard let rhsIdentifiers = rhsExporterConfiguration.identifiersOfSynthesizedTypes[updatedSwiftTypeName] else {
                continue // endpoint (and its types) were probably removed in latest version (or aren't synthesized anymore)
            }

            // additionally we need to check for the following:
            // - added properties
            // - updated identifiers (grpc number or field type)
            // - As we match children via their property name, we need to check if anything got renamed!

            var modelChanges: [ModelChange] = []

            if lhsIdentifiers.inputIdentifiers != nil || rhsIdentifiers.inputIdentifiers != nil {
                let lhsInputIdentifiers = lhsIdentifiers.inputIdentifiers ?? TypeInformationIdentifiers()
                let rhsInputIdentifiers = rhsIdentifiers.inputIdentifiers ?? TypeInformationIdentifiers()

                precondition(endpoint.parameters.count == 1, "Unexpected endpoint count for \(endpoint)")
                let parameter = endpoint.parameters[0]

                computeIdentifiersOfSynthesizedType(
                    of: parameter.typeInformation,
                    lhs: lhsInputIdentifiers,
                    rhs: rhsInputIdentifiers,
                    collectInto: &modelChanges
                )
            }

            if lhsIdentifiers.outputIdentifiers != nil || rhsIdentifiers.outputIdentifiers != nil {
                let lhsOutputIdentifiers = lhsIdentifiers.outputIdentifiers ?? TypeInformationIdentifiers()
                let rhsOutputIdentifiers = rhsIdentifiers.outputIdentifiers ?? TypeInformationIdentifiers()
                computeIdentifiersOfSynthesizedType(
                    of: endpoint.response,
                    lhs: lhsOutputIdentifiers,
                    rhs: rhsOutputIdentifiers,
                    collectInto: &modelChanges
                )
            }

            for change in modelChanges {
                migrationGuide.modelChanges.append(change)
            }
        }

        for change in migrationGuide.endpointChanges {
            guard let addedEndpoint = change.modeledAdditionChange,
                  let identifiers = rhsExporterConfiguration.identifiersOfSynthesizedTypes[addedEndpoint.added.swiftTypeName] else {
                // either not an added endpoint or added endpoint doesn't have any synthesized types!
                continue
            }

            var endpoint = addedEndpoint.added
            endpoint.dereference(in: typeStore)

            _augmentIdentifiersOfSynthesizedTypes(of: endpoint, with: identifiers)
        }

        // we rewrite the `GRPCName` identifier for all added models to use the previous packageName!
        for change in migrationGuide.modelChanges {
            guard let addedModel = change.modeledAdditionChange,
                  let context = addedModel.added.context,
                  var identifiers = context.get(valueFor: TypeInformationIdentifierContextKey.self),
                  let grpcName = identifiers.identifierIfPresent(for: GRPCName.self) else {
                continue
            }

            let parsed = grpcName.parsed(migration: self)
            identifiers.add(identifier: GRPCName(rawValue: parsed.rawValue))

            context.unsafeAdd(TypeInformationIdentifierContextKey.self, value: identifiers, allowOverwrite: true)
        }
    }

    private mutating func computeIdentifiersOfSynthesizedType(
        of typeInformation: TypeInformation,
        lhs lhsIdentifiers: TypeInformationIdentifiers,
        rhs rhsIdentifiers: TypeInformationIdentifiers,
        collectInto modelChanges: inout [ModelChange]
    ) {
        // Step 1: compare the identifier storage of the type itself
        var rootIdentifierChanges: [ElementIdentifierChange] = []
        let rootComparator = ElementIdentifiersComparator(
            lhs: Array(lhsIdentifiers.identifiers.values),
            rhs: Array(rhsIdentifiers.identifiers.values)
        )
        rootComparator.compare(&rootIdentifierChanges)

        for change in rootIdentifierChanges {
            migrationGuide.modelChanges.append(.update(
                id: typeInformation.deltaIdentifier,
                updated: .identifier(identifier: change),
                breaking: change.breaking,
                solvable: change.solvable
            ))
        }

        // Step 2: compare the identifier storage of the type children
        switch typeInformation.unwrapped {
        case let .object(_, properties, _):
            let propertyChanges: [PropertyChange] = migrationGuide.modelChanges.compactMap { change in
                guard change.id == typeInformation.deltaIdentifier,
                      let updateChange = change.modeledUpdateChange,
                      case let .property(propertyChange) = updateChange.updated else {
                    return nil
                }
                return propertyChange
            }

            let modelChanges = computeIdentifiersOfSynthesizedTypeChildren(
                parent: typeInformation.deltaIdentifier,
                children: properties,
                changes: propertyChanges,
                lhsIdentifiers: lhsIdentifiers,
                rhsIdentifiers: rhsIdentifiers
            )

            migrationGuide.modelChanges.append(contentsOf: modelChanges)
        case .enum:
            preconditionFailure("Some assumption broke. Encountered synthesized wrapper type which is a enum. Expected a object: \(typeInformation)")
        default:
            fatalError("Encountered unexpected typeInformation model \(typeInformation) when computing changes of synthesized type children")
        }
    }

    private func computeIdentifiersOfSynthesizedTypeChildren(
        parent typeId: DeltaIdentifier,
        children: [TypeProperty],
        changes: [PropertyChange],
        lhsIdentifiers: TypeInformationIdentifiers,
        rhsIdentifiers: TypeInformationIdentifiers
    ) -> [ModelChange] {
        // in order to compare updated children identifiers,
        // we need to collect the update names to properly match them together.
        var childrenNameMapping: [DeltaIdentifier: DeltaIdentifier] = [:]
        // further we collect the removed children to know where we don't need to expect updated identifiers.
        var removedChildren: Set<DeltaIdentifier> = []

        for change in changes {
            if let additionChange = change.modeledAdditionChange {
                let addedChild = additionChange.added

                guard let storage = rhsIdentifiers.childrenIdentifiers[addedChild.name] else {
                    continue
                }

                addedChild.context.unsafeAdd(TypeInformationIdentifierContextKey.self, value: storage)
            } else if let renameChange = change.modeledIdentifierChange {
                childrenNameMapping[renameChange.from] = renameChange.to
            } else if let removalChange = change.modeledRemovalChange {
                removedChildren.insert(removalChange.id)
            }
        }

        var childrenChanges: [PropertyChange] = []

        for child in children {
            guard !removedChildren.contains(child.deltaIdentifier) else {
                continue
            }

            let updatedName = childrenNameMapping[child.deltaIdentifier] ?? child.deltaIdentifier

            guard let lhsStorage = lhsIdentifiers.childrenIdentifiers[child.name],
                  let rhsStorage = rhsIdentifiers.childrenIdentifiers[updatedName.rawValue]  else {
                fatalError("Found property for which we couldn't find matching identifier storage \(child) in '\(typeId.rawValue)'")
            }

            var identifierChanges: [ElementIdentifierChange] = []
            let comparator = ElementIdentifiersComparator(
                lhs: Array(lhsStorage.values),
                rhs: Array(rhsStorage.values)
            )
            comparator.compare(&identifierChanges)

            childrenChanges.append(contentsOf: identifierChanges.map { change in
                .update(
                    id: child.deltaIdentifier,
                    updated: .identifier(identifier: change),
                    breaking: change.breaking,
                    solvable: change.solvable
                )
            })
        }

        return childrenChanges.map { change in
            .update(
                id: typeId,
                updated: .property(property: change),
                breaking: change.breaking,
                solvable: change.solvable
            )
        }
    }

    private func _augmentIdentifiersOfSynthesizedTypes(of endpoint: Endpoint, with identifiers: EndpointSynthesizedTypes) {
        if var inputIdentifiers = identifiers.inputIdentifiers {
            precondition(endpoint.parameters.count == 1, "Unexpected endpoint count for \(endpoint)")
            let parameter = endpoint.parameters[0]

            inputIdentifiers.rewritePackageName(migration: self)

            parameter.typeInformation.augmentTypeWithIdentifiers(retrieveIdentifiers: { _ in inputIdentifiers })
        }

        if var outputIdentifiers = identifiers.outputIdentifiers {
            outputIdentifiers.rewritePackageName(migration: self)

            endpoint.response.augmentTypeWithIdentifiers(retrieveIdentifiers: { _ in outputIdentifiers })
        }
    }
}

private extension TypeInformationIdentifiers {
    mutating func rewritePackageName(migration: MigrationContext) {
        guard let grpcName = identifiers.identifierIfPresent(for: GRPCName.self) else {
            return
        }

        let parsed = grpcName.parsed(migration: migration)
        identifiers.add(identifier: GRPCName(rawValue: parsed.rawValue))
    }
}
