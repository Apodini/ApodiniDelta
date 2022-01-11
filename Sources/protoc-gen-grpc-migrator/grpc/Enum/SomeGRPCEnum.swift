//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigrator
import SwiftProtobufPluginLibrary

protocol SomeGRPCEnum {
    var context: ProtoFileContext { get }

    var relativeName: String { get }
    var fullName: String { get }
    var sourceCodeComments: String? { get }

    var unavailable: Bool { get }
    var containsRootTypeChange: Bool { get }

    var enumCases: [GRPCEnumCase] { get }
    var uniquelyNamedValues: [GRPCEnumCase] { get } // TODO bro?
    var enumCasesSorted: [GRPCEnumCase] { get }

    var defaultValue: GRPCEnumCase { get } // TODO how is this calculcated?
}

extension SomeGRPCEnum {
    var sourceCodeComments: String? {
        nil
    }

    var unavailable: Bool {
        false
    }

    var containsRootTypeChange: Bool {
        false
    }
    var enumCasesSorted: [GRPCEnumCase] {
        enumCases.sorted(by: \.number)
    }
}