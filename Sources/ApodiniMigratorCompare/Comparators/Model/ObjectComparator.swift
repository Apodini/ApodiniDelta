//
//  ObjectComparator.swift
//  ApodiniMigratorCompare
//
//  Created by Eldi Cano on 29.06.21.
//  Copyright © 2021 TUM LS1. All rights reserved.
//

import Foundation

struct ObjectComparator: Comparator {
    let lhs: TypeInformation
    let rhs: TypeInformation
    let changes: ChangeContextNode
    let configuration: EncoderConfiguration
    let lhsProperties: [TypeProperty]
    let rhsProperties: [TypeProperty]
    
    init(lhs: TypeInformation, rhs: TypeInformation, changes: ChangeContextNode, configuration: EncoderConfiguration) {
        self.lhs = lhs
        self.rhs = rhs
        self.changes = changes
        self.configuration = configuration
        self.lhsProperties = lhs.objectProperties
        self.rhsProperties = rhs.objectProperties
    }
    
    func compare() {
        let matchedIds = lhsProperties.matchedIds(with: rhsProperties)
        let removalCandidates = lhsProperties.filter { !matchedIds.contains($0.deltaIdentifier) }
        let additionCandidates = rhsProperties.filter { !matchedIds.contains($0.deltaIdentifier) }
        handle(removalCandidates: removalCandidates, additionCandidates: additionCandidates)
        
        for matched in matchedIds {
            if let lhs = lhsProperties.firstMatch(on: \.deltaIdentifier, with: matched),
               let rhs = rhsProperties.firstMatch(on: \.deltaIdentifier, with: matched) {
                compare(lhs: lhs, rhs: rhs)
            }
        }
        
        changes.store(rhs: rhs, encoderConfiguration: configuration)
    }
    
    private func compare(lhs: TypeProperty, rhs: TypeProperty) {
        let lhsType = lhs.type
        let rhsType = rhs.type
        
        let targetID = lhs.deltaIdentifier
        
        if sameNestedTypes(lhs: lhsType, rhs: rhsType), lhs.necessity != rhs.necessity {
            let currentLhsType = changes.currentVersion(of: lhsType)
            changes.add(
                UpdateChange(
                    element: element(.necessity),
                    from: .element(lhs.necessity),
                    to: .element(rhs.necessity),
                    necessityValue: .value(from: currentLhsType.unwrapped, with: configuration, changes: changes),
                    targetID: targetID,
                    breaking: true,
                    solvable: true
                )
            )
        } else if typesNeedConvert(lhs: lhsType, rhs: rhsType) {
            let jsScriptBuilder = JSScriptBuilder(from: lhsType, to: rhsType, changes: changes, encoderConfiguration: configuration)
            changes.add(
                UpdateChange(
                    element: element(.property),
                    from: .element(reference(lhsType)),
                    to: .element(reference(rhsType)),
                    targetID: targetID,
                    convertFromTo: changes.store(script: jsScriptBuilder.convertFromTo),
                    convertToFrom: changes.store(script: jsScriptBuilder.convertToFrom),
                    convertionWarning: jsScriptBuilder.hint,
                    breaking: true,
                    solvable: true
                )
            )
        }
    }
    
    private func handle(removalCandidates: [TypeProperty], additionCandidates: [TypeProperty]) {
        var relaxedMatchings: Set<DeltaIdentifier> = []
        
        assert(Set(removalCandidates.identifiers()).isDisjoint(with: additionCandidates.identifiers()), "Encoutered removal and addition candidates with same id")
        
        for candidate in removalCandidates {
            if let relaxedMatching = candidate.mostSimilarWithSelf(in: additionCandidates) {
                relaxedMatchings += relaxedMatching.deltaIdentifier
                relaxedMatchings += candidate.deltaIdentifier
                
                changes.add(
                    UpdateChange(
                        element: element(.property),
                        from: candidate.name,
                        to: relaxedMatching.name,
                        breaking: true,
                        solvable: true,
                        includeProviderSupport: includeProviderSupport
                    )
                )
                
                compare(lhs: candidate, rhs: relaxedMatching)
            }
        }
        
        for removal in removalCandidates where !relaxedMatchings.contains(removal.deltaIdentifier) {
            let wasRequired = removal.necessity == .required
            changes.add(
                DeleteChange(
                    element: element(.property),
                    deleted: .id(from: removal),
                    fallbackValue: wasRequired ? .value(from: removal.type, with: configuration, changes: changes) : .none,
                    breaking: wasRequired,
                    solvable: true,
                    includeProviderSupport: includeProviderSupport
                )
            )
        }
        
        for addition in additionCandidates where !relaxedMatchings.contains(addition.deltaIdentifier) {
            let isRequired = addition.necessity == .required
            changes.add(
                AddChange(
                    element: element(.property),
                    added: .element(addition),
                    defaultValue: isRequired ? .value(from: addition.type, with: configuration, changes: changes) : .none,
                    breaking: isRequired,
                    solvable: true,
                    includeProviderSupport: includeProviderSupport
                )
            )
        }
    }
    
    private func element(_ target: ObjectTarget) -> ChangeElement {
        .for(object: lhs, target: target)
    }
}
