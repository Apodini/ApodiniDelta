//
//  XCTestManifests.swift
//
//  Created by ApodiniMigrator on 30.05.2021
//  Copyright © 2021 TUM LS1. All rights reserved.
//

import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    [
        testCase(ExampleACDTests.allTests)
    ]
}
#endif
