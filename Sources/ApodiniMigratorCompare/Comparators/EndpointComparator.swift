//
//  File.swift
//  
//
//  Created by Eldi Cano on 23.05.21.
//

import Foundation

struct EndpointComparator: Comparator {
    let lhs: Endpoint
    let rhs: Endpoint
    let changes: ChangeContainer
    var configuration: EncoderConfiguration
    
    var element: ChangeElement {
        .for(endpoint: lhs)
    }
    
    func compare() {
        if lhs.path != rhs.path { // Comparing resourcePaths
            changes.add(
                ValueChange(
                    element: element,
                    target: .path,
                    from: .string(lhs.path.resourcePath),
                    to: .string(rhs.path.resourcePath),
                    breaking: true,
                    solvable: true
                )
            )
        }
        
        if lhs.operation != rhs.operation {
            changes.add(
                ValueChange(
                    element: element,
                    target: .operation,
                    from: .string(lhs.operation.rawValue),
                    to: .string(rhs.operation.rawValue),
                    breaking: true,
                    solvable: true
                )
            )
        }
        
        let parametersComparator = ParametersComparator(lhs: lhs, rhs: rhs, changes: changes, configuration: configuration)
        parametersComparator.compare()
        
        let lhsResponse = lhs.response
        let rhsResponse = rhs.response
        
        if !(lhsResponse.sameType(with: rhsResponse) && (lhsResponse ?= rhsResponse)) {
            changes.add(
                ValueChange(
                    element: element,
                    target: .response,
                    from: .json(of: lhs.response),
                    to: .json(of: rhs.response),
                    convertFunction: "TODO Add js function",
                    breaking: true,
                    solvable: true
                )
            )
        }
    }
}
