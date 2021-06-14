//
//  File.swift
//  
//
//  Created by Eldi Cano on 23.05.21.
//

import Foundation

struct DocumentComparator: Comparator {
    let lhs: Document
    let rhs: Document
    let changes: ChangeContainer
    let configuration: EncoderConfiguration
    
    var currentEncoderConfiguration: EncoderConfiguration {
        rhs.metaData.encoderConfiguration
    }
    
    /// Perhaps consider comparing all models here already, olddoc.allModels, vs newDoc.allModels, Content compare can be skipped from endpoints
    func compare() {
        let metaDataComparator = MetaDataComparator(lhs: lhs.metaData, rhs: rhs.metaData, changes: changes, configuration: configuration)
        metaDataComparator.compare()
        
        let modelsComparator = ModelsComparator(lhs: lhs.allModels(), rhs: rhs.allModels(), changes: changes, configuration: configuration)
        modelsComparator.compare()
        
        let endpointsComparator = EndpointsComparator(lhs: lhs.endpoints, rhs: rhs.endpoints, changes: changes, configuration: configuration)
        endpointsComparator.compare()
    }
}
