//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

struct ParameterComparator: Comparator {
    let lhs: Parameter
    let rhs: Parameter
    let changes: ChangeContextNode
    let configuration: EncoderConfiguration
    let lhsEndpoint: Endpoint
    
    private var element: ChangeElement {
        .for(endpoint: lhsEndpoint, target: .target(for: lhs))
    }
    
    private var targetID: DeltaIdentifier {
        lhs.deltaIdentifier
    }
    
    init(lhs: Parameter, rhs: Parameter, changes: ChangeContextNode, configuration: EncoderConfiguration, lhsEndpoint: Endpoint) {
        self.lhs = lhs
        self.rhs = rhs
        self.changes = changes
        self.configuration = configuration
        self.lhsEndpoint = lhsEndpoint
    }
    
    func compare() {
        if lhs.parameterType != rhs.parameterType {
            let change: ParameterChange = .update(
                id: lhs.deltaIdentifier,
                updated: .parameterType(
                    from: lhs.parameterType,
                    to: rhs.parameterType
                )
            )

            changes.add(
                UpdateChange(
                    element: element,
                    from: .element(lhs.parameterType),
                    to: .element(rhs.parameterType),
                    targetID: targetID,
                    parameterTarget: .kind,
                    breaking: true,
                    solvable: true
                )
            )
        }
        
        if sameNestedTypes(lhs: lhs.typeInformation, rhs: rhs.typeInformation), lhs.necessity != rhs.necessity, rhs.necessity == .required {
            let change: ParameterChange = .update(
                id: lhs.deltaIdentifier,
                updated: .necessity(
                    from: lhs.necessity,
                    to: rhs.necessity,
                    necessityMigration: 0 // TODO retrive from the .value call!
                ),
                breaking: rhs.necessity == .required
            )

            return changes.add(
                UpdateChange(
                    element: element,
                    from: .element(lhs.necessity),
                    to: .element(rhs.necessity),
                    targetID: targetID,
                    necessityValue: .value(from: rhs.typeInformation, with: configuration, changes: changes),
                    parameterTarget: .necessity,
                    breaking: rhs.necessity == .required,
                    solvable: true
                )
            )
        }
        
        let lhsType = lhs.typeInformation
        let rhsType = rhs.typeInformation
        
        if typesNeedConvert(lhs: lhsType, rhs: rhsType) {
            let jsScriptBuilder = JSScriptBuilder(from: lhsType, to: rhsType, changes: changes, encoderConfiguration: configuration)
            let migrationInt = changes.store(script: jsScriptBuilder.convertFromTo)

            let change: ParameterChange = .update(
                id: lhs.deltaIdentifier,
                updated: .type(
                    from: lhsType.referenced(),
                    to: rhsType.referenced(),
                    forwardMigration: migrationInt,
                    conversionWarning: jsScriptBuilder.hint
                )
            )

            changes.add(
                UpdateChange(
                    element: element,
                    from: .element(lhsType.referenced()),
                    to: .element(rhsType.referenced()),
                    targetID: targetID,
                    convertFromTo: migrationInt,
                    convertionWarning: jsScriptBuilder.hint,
                    parameterTarget: .typeInformation,
                    breaking: true,
                    solvable: true
                )
            )
        }
    }
}
