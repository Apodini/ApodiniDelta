//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// A `ParameterCombination` can be used to merge multiple parameters into a single one.
/// Which parameters are combined can be selected.
public protocol ParameterCombination {
    /// This property controls if ``merge(parameters:of:)`` is still called if the `Endpoint` doesn't
    /// have any parameters at all.
    /// By default this is `false`.
    var shouldCallForZeroParameters: Bool { get }

    /// This predicate indicates which Endpoint `Parameter` should be combined.
    ///
    /// - Parameter parameter: The `Parameter` which is checked.
    /// - Returns: Return `true` if the given parameter is part of the collection of parameters which get combined.
    func shouldBeMapped(parameter: Parameter) -> Bool

    /// After all `Parameter`s have been selected using ``shouldBeMapped``, this method is called to
    /// execute the actual combine step.
    /// Any changes done here must be **additional**. Meaning you must not e.g. remove a parameter or a type.
    /// You may abort the merge completely by returning `nil`.
    ///
    /// - Parameter endpoint: The `Endpoint` whose `Parameter`s get merged.
    ///     Use this to generate a unique Endpoint dependent type name.
    ///     Note: All `TypeInformation` of the provided endpoint is NOT dereferenced.
    /// - Parameter parameters: All the `Parameter`s which are to be combined.
    /// - Returns: The merged `Parameter`. Return `nil` to abort the merge (e.g. not merging a single parameter).
    func merge(parameters: [Parameter], of endpoint: Endpoint) -> Parameter?
}

extension ParameterCombination {
    /// By default false.
    public var shouldCallForZeroParameters: Bool {
        false
    }
}

// MARK: ParameterCombination
extension TypeProperty {
    /// Initialize a `TypeProperty` from a `Parameter`. This is used for ``ParameterMigration``.
    public init(from parameter: Parameter, context: Context = Context()) {
        self = TypeProperty(
            name: parameter.name,
            type: parameter.necessity == .optional
                ? parameter.typeInformation.asOptional
                : parameter.typeInformation,
            context: context
        )
    }
}


private struct EndpointWrappedParameters {
    let wrappedParameters: [DeltaIdentifier]
    let wrapperTypeId: DeltaIdentifier
}

enum ModelStorageDestination {
    case apiDocument
    case migrationGuide
}

extension APIDocument {
    /// This method can be used to combine several `Parameter`s of an `Endpoint` into a single one.
    /// The created wrapper types will be stored as `reference` types in the `Endpoint`. Use the `TypeStore`
    /// of the `APIDocument` or the model additions in the `MigrationGuide` respectively to resolve the types.
    ///
    /// - Parameters:
    ///   - migrationGuide: The `MigrationGuide` which should be considered. Change types are migrated accordingly.
    ///   - combination: The ``ParameterCombination``.
    public mutating func applyEndpointParameterCombination(
        considering migrationGuide: inout MigrationGuide,
        using combination: ParameterCombination
    ) {
        // we must do the following things for a proper mapping:
        // Combining the parameters:
        //  - search through all Endpoints of the APIDocument and combine (if applicable) to a single wrapper parameter
        //  - Introduces the new wrapper type into the type store of the APIDocument
        //
        // Migrate the MigrationGuide:
        //  - Map Parameter ADDITIONS, if they would be mapped into the wrapping parameter, as PROPERTY additions of the wrapper type.
        //  - Map Parameter UPDATES, which concern parameters of the wrapping parameter, to PROPERTY updates.
        //  - Lastly we also need to consider ADDED ENDPOINTS in the migrationGuide and apply all of the above.

        // mapping: [Endpoint: EndpointWrappedParameters]
        // this saves all combined parameters considering only parameters in the BASE APIDocument.
        // We don't track ADDED parameter (contained in the migration guide) as we don't need this information.
        // We only track this to detect if any of those parameters have a respective PARAMETER UPDATE in the migration guide.
        // Those must be mapped to PROPERTY UPDATE.
        var combinedParameters: [DeltaIdentifier: EndpointWrappedParameters] = [:]

        unsafeEndpoints = unsafeEndpoints.map { endpoint in
            // we have an unsafe endpoints access here, types are NOT dereferenced
            combineParameters(of: endpoint, considering: &migrationGuide, using: combination, tracking: &combinedParameters, storeInto: .apiDocument)
                ?? endpoint // if it returns nil, nothing was modified
        }

        handleParameterCombinationsOfAddedEndpoints(considering: &migrationGuide, using: combination)

        migrateParameterChangesToPropertyChanges(of: combinedParameters, considering: &migrationGuide, using: combination)
    }

    private mutating func combineParameters(
        of endpoint: Endpoint,
        considering migrationGuide: inout MigrationGuide,
        using combination: ParameterCombination,
        tracking combinedParameters: inout [DeltaIdentifier: EndpointWrappedParameters],
        storeInto storage: ModelStorageDestination
    ) -> Endpoint? {
        var endpoint = endpoint

        var electedParameters: [Parameter] = []
        endpoint.parameters.removeAll { parameter in
            if combination.shouldBeMapped(parameter: parameter) {
                electedParameters.append(parameter)
                return true
            }
            return false
        }

        if electedParameters.isEmpty && (!electedParameters.isEmpty || !combination.shouldCallForZeroParameters) {
            return nil
        }

        guard var wrappedParameter = combination.merge(parameters: electedParameters, of: endpoint) else {
            // merge was aborted by returning nil
            return nil
        }

        // this save must happen before we store the typeInfo in the APIDocument.
        // Storing it will turn it into a type reference and we can't derive deltaIdentifiers from references!
        combinedParameters[endpoint.deltaIdentifier] = EndpointWrappedParameters(
            wrappedParameters: electedParameters.map { $0.deltaIdentifier },
            wrapperTypeId: wrappedParameter.typeInformation.deltaIdentifier
        )

        switch storage {
        case .apiDocument:
            // store the type in the APIDocument and store the type reference in the parameter
            wrappedParameter.typeInformation = add(type: wrappedParameter.typeInformation)
        case .migrationGuide:
            // encode the new type as a `addition` change
            migrationGuide.modelChanges.append(.addition(
                id: wrappedParameter.typeInformation.deltaIdentifier,
                added: wrappedParameter.typeInformation
            ))

            wrappedParameter.typeInformation = wrappedParameter.typeInformation.asReference()
        }

        // append the final parameter
        endpoint.parameters.append(wrappedParameter)
        return endpoint
    }

    private mutating func handleParameterCombinationsOfAddedEndpoints(
        considering migrationGuide: inout MigrationGuide,
        using combination: ParameterCombination
    ) {
        migrationGuide.endpointChanges = migrationGuide.endpointChanges.map { endpointChange -> EndpointChange in
            guard let additionChange = endpointChange.modeledAdditionChange else {
                return endpointChange
            }

            // we are actually not interested in collecting these. we dont need to migrate update changes for them.
            var sink: [DeltaIdentifier: EndpointWrappedParameters] = [:]
            if let modifiedEndpoint = combineParameters(
                of: additionChange.added,
                considering: &migrationGuide,
                using: combination,
                tracking: &sink,
                storeInto: .migrationGuide
            ) {
                return .addition(
                    id: additionChange.id,
                    added: modifiedEndpoint,
                    defaultValue: additionChange.defaultValue,
                    breaking: additionChange.breaking,
                    solvable: additionChange.solvable
                )
            }

            return endpointChange
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private mutating func migrateParameterChangesToPropertyChanges(
        of combinedParameters: [DeltaIdentifier: EndpointWrappedParameters],
        considering migrationGuide: inout MigrationGuide,
        using combination: ParameterCombination
    ) {
        // this method handles migration of `Endpoint.update` containing parameter changes.
        // We need to handle parameter changes of parameters which we combined previously to be mapped to property changes.
        for endpointChange in migrationGuide.endpointChanges {
            // we only consider update changes about parameters ...
            guard let updateChange = endpointChange.modeledUpdateChange,
                  case let .parameter(parameterChange) = updateChange.updated else {
                continue
            }

            // ... which concerns one of the affected endpoints
            guard let context = combinedParameters[endpointChange.id] else {
                continue
            }

            var migratedPropertyChange: PropertyChange?

            if let rename = parameterChange.modeledIdentifierChange {
                guard context.wrappedParameters.contains(parameterChange.id) else {
                    continue
                }

                migratedPropertyChange = .idChange(
                    from: rename.from,
                    to: rename.to,
                    similarity: rename.similarity,
                    breaking: rename.breaking,
                    solvable: rename.solvable
                )
            } else if let addition = parameterChange.modeledAdditionChange {
                guard combination.shouldBeMapped(parameter: addition.added) else {
                    continue
                }

                migratedPropertyChange = .addition(
                    id: addition.id,
                    added: TypeProperty(from: addition.added),
                    defaultValue: addition.defaultValue, // defaultValue is calculated the exact same way for both Parameters and Properties
                    breaking: addition.breaking,
                    solvable: addition.solvable
                )
            } else if let update = parameterChange.modeledUpdateChange {
                guard context.wrappedParameters.contains(parameterChange.id) else {
                    continue
                }

                let propertyUpdate: TypeProperty.Update
                switch update.updated {
                case let .necessity(from, to, necessityMigration):
                    propertyUpdate = .necessity(
                        from: from,
                        to: to,
                        necessityMigration: necessityMigration
                    )
                case let .type(from, to, forwardMigration, conversionWarning):
                    propertyUpdate = .type(
                        from: from,
                        to: to,
                        forwardMigration: forwardMigration,
                        // its fine that we have no backward migration.
                        // The type will never be used as a response type.
                        // It is nonetheless generated so consider the following:
                        // A call with a invalid script id will result in a JSScript with an empty string.
                        // Invalid scripts will result in a call to `defaultValue()` for calls to `from(_:script:).
                        // But again, the decode init will never be called.
                        backwardMigration: -1,
                        conversionWarning: conversionWarning
                    )
                case .parameterType:
                    continue
                }

                migratedPropertyChange = .update(
                    id: update.id,
                    updated: propertyUpdate,
                    // parameters necessity changes are not considered breaking if the `to` necessity
                    // is optional. For property changes its always breaking as the type might be used in a response.
                    // As this type only used as an endpoint input, this breaking classification is fine!
                    breaking: update.breaking,
                    solvable: update.solvable
                )
            } else if let removal = parameterChange.modeledRemovalChange {
                guard context.wrappedParameters.contains(parameterChange.id) else {
                    continue
                }

                // for TypeProperty migrations the `fallbackValue` and `breaking`
                // depends on if the property was required. Then a fallbackValue was set and it was considered breaking.
                // This is because the model might have been used as a response type. In those cases we require
                // a fallbackValue as the client library expects a value.
                // But parameters are always just used as an input type, therefore fallbackValue is always nil
                // and breaking is always false! This is fine as we can guarantee that this type is never
                // used in a response!
                migratedPropertyChange = .removal(
                    id: removal.id,
                    removed: nil,
                    fallbackValue: removal.fallbackValue,
                    breaking: false,
                    solvable: true
                )
            }

            if let propertyChange = migratedPropertyChange {
                // add the migrated model change
                migrationGuide.modelChanges.append(.update(
                    id: context.wrapperTypeId,
                    updated: .property(property: propertyChange),
                    breaking: propertyChange.breaking,
                    solvable: propertyChange.solvable
                ))

                // remove the endpoint change
                if let index = migrationGuide.endpointChanges.firstIndex(of: endpointChange) {
                    migrationGuide.endpointChanges.remove(at: index)
                } else {
                    fatalError("""
                               Encountered inconsistent data. Endpoint change which is part of the migration guide \
                               is not part of the migration guide! LMAO!
                               """)
                }
            }
        }
    }
}
