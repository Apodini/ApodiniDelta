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
import OrderedCollections

class ProtoGRPCMessage: SomeGRPCMessage {
    let descriptor: Descriptor

    var name: String {
        descriptor.name
    }
    var relativeName: String
    var fullName: String

    var sourceCodeComments: String?

    var unavailable = false // TODO set
    var containsRootTypeChange = false // TODO use!

    var fields: [GRPCMessageField] = []

    var nestedEnums: OrderedDictionary<String, GRPCEnum> = [:]
    var nestedMessages: OrderedDictionary<String, GRPCMessage> = [:]

    init(descriptor: Descriptor, namer: SwiftProtobufNamer) {
        self.descriptor = descriptor

        precondition(descriptor.extensionRanges.isEmpty, "proto extensions are unsupported by the migrator")

        self.relativeName = namer.relativeName(message: descriptor)
        self.fullName = namer.fullName(message: descriptor)

        self.sourceCodeComments = descriptor.protoSourceComments()

        for field in descriptor.fields {
            fields.append(.init(ProtoGRPCMessageField(descriptor: field, namer: namer)))
        }

        for `enum` in descriptor.enums {
            nestedEnums[`enum`.name] = GRPCEnum(descriptor: `enum`, namer: namer)
        }

        for message in descriptor.messages {
            nestedMessages[message.name] = GRPCMessage(ProtoGRPCMessage(descriptor: message, namer: namer), namer: namer)
        }
    }

    func applyUpdateChange(_ change: ModelChange.UpdateChange) {
        // TODO deltaIdentifier verification!

        switch change.updated {
        case .rootType: // TODO model it as removal and addition?
            containsRootTypeChange = true // root type changes are unsupported
        case let .property(property):
            // TODO we ignore idChange right?
            if let addedProperty = property.modeledAdditionChange {
                // TODO how to we know the number? (guess?
            } else if let removedProperty = property.modeledRemovalChange {
                // TODO mark removed (just don't encode anymore?)
            } else if let updatedProperty = property.modeledUpdateChange {
                switch updatedProperty.updated {
                case let .necessity(from, to, necessityMigration):
                    // TODO update change!
                    break
                case let .type(from, to, forwardMigration, backwardMigration, conversionWarning):
                    // TODO first time handling type change!
                    // TODO requires Codable support!
                    break
                }
            }
        case .case, .rawValueType:
            fatalError("Tried updating message with enum-only change type!")
        }
    }
}