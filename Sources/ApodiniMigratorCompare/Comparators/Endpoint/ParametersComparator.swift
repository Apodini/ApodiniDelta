//
//  ParametersComparator.swift
//  ApodiniMigratorCompare
//
//  Created by Eldi Cano on 07.08.21.
//  Copyright © 2021 TUM LS1. All rights reserved.
//

import Foundation

struct ParametersComparator: Comparator {
    let lhs: Endpoint
    let rhs: Endpoint
    let changes: ChangeContextNode
    var configuration: EncoderConfiguration
    let lhsParameters: [Parameter]
    let rhsParameters: [Parameter]
    
    init(lhs: Endpoint, rhs: Endpoint, changes: ChangeContextNode, configuration: EncoderConfiguration) {
        self.lhs = lhs
        self.rhs = rhs
        self.changes = changes
        self.configuration = configuration
        self.lhsParameters = lhs.parameters
        self.rhsParameters = rhs.parameters
    }
    
    func compare() {
        let matchedIds = lhsParameters.matchedIds(with: rhsParameters)
        let removalCandidates = lhsParameters.filter { !matchedIds.contains($0.deltaIdentifier) }
        let additionCandidates = rhsParameters.filter { !matchedIds.contains($0.deltaIdentifier) }
        handle(removalCandidates: removalCandidates, additionCandidates: additionCandidates)
        
        for matched in matchedIds {
            if let lhs = lhsParameters.firstMatch(on: \.deltaIdentifier, with: matched),
                let rhs = rhsParameters.firstMatch(on: \.deltaIdentifier, with: matched) {
                let parameterComparator = ParameterComparator(lhs: lhs, rhs: rhs, changes: changes, configuration: configuration, lhsEndpoint: self.lhs)
                parameterComparator.compare()
            }
        }
    }

    
    private func handle(removalCandidates: [Parameter], additionCandidates: [Parameter]) {
        var relaxedMatchings: Set<DeltaIdentifier> = []
        
        for candidate in removalCandidates {
            if let relaxedMatching = candidate.mostSimilarWithSelf(in: additionCandidates.filter { !relaxedMatchings.contains($0.deltaIdentifier) }) {
                relaxedMatchings += relaxedMatching.element.deltaIdentifier
                relaxedMatchings += candidate.deltaIdentifier
                
                changes.add(
                    UpdateChange(
                        element: element(.target(for: candidate)),
                        from: candidate.name,
                        to: relaxedMatching.element.name,
                        similarity: relaxedMatching.similarity,
                        breaking: true,
                        solvable: true,
                        includeProviderSupport: includeProviderSupport
                    )
                )
                let parameterComparator = ParameterComparator(lhs: candidate, rhs: relaxedMatching.element, changes: changes, configuration: configuration, lhsEndpoint: self.lhs)
                parameterComparator.compare()
            }
        }
        
        for removal in removalCandidates where !relaxedMatchings.contains(removal.deltaIdentifier) {
            changes.add(
                DeleteChange(
                    element: element(.target(for: removal)),
                    deleted: .id(from: removal),
                    fallbackValue: .none,
                    breaking: false,
                    solvable: true,
                    includeProviderSupport: includeProviderSupport
                )
            )
        }
        
        for addition in additionCandidates where !relaxedMatchings.contains(addition.deltaIdentifier) {
            var defaultValue: ChangeValue?
            let isRequired = addition.necessity == .required
            if isRequired {
                defaultValue = .value(from: addition.typeInformation, with: configuration, changes: changes)
            }
            
            changes.add(
                AddChange(
                    element: element(.target(for: addition)),
                    added: .element(addition.referencedType()),
                    defaultValue: defaultValue ?? .none,
                    breaking: isRequired,
                    solvable: true,
                    includeProviderSupport: includeProviderSupport
                )
            )
        }
    }
    
    private func element(_ target: EndpointTarget) -> ChangeElement {
        .for(endpoint: lhs, target: target)
    }
}
