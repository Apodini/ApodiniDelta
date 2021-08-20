//
//  ParameterComparator.swift
//  ApodiniMigratorCompare
//
//  Created by Eldi Cano on 07.08.21.
//  Copyright © 2021 TUM LS1. All rights reserved.
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
            changes.add(
                UpdateChange(
                    element: element,
                    from: .element(lhsType.asReference()),
                    to: .element(rhsType.asReference()),
                    targetID: targetID,
                    convertFromTo: changes.store(script: jsScriptBuilder.convertFromTo),
                    convertionWarning: jsScriptBuilder.hint,
                    parameterTarget: .typeInformation,
                    breaking: true,
                    solvable: true
                )
            )
        }
    }
}
