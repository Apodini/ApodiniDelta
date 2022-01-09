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

/// This file will generate and migrate models of a Proto file.
///
/// It aims to do a very basic proto file generation.
/// We don't support the following features (e.g. comparing against the `swift-protobuffer` implementation).
/// * We don't support heap based storage of fields. We currently assume non-recursive struct models
///   (e.g. due to https://github.com/Apodini/ApodiniTypeInformation/issues/5).
/// * We don't support proto `extensions` as they are not used within `ApodiniGRPC`
/// * We don't respect `useMessageSetWireFormat` as we are not interested in providing legacy compatibility
/// * We don't support `oneOf`s (used by `ApodiniGRPC` to render enums with associated values) as they are not
///   supported by the `ApodiniTypeInformation` framework. Thus, if you use ApodiniMigration you won't use enums with associated values.
class GRPCModelsFile: SourceCodeRenderable {
    let protoFile: FileDescriptor
    let document: APIDocument
    let migrationGuide: MigrationGuide
    let namer: SwiftProtobufNamer

    var modelIdTranslation: [DeltaIdentifier: TypeName] = [:]

    var enums: OrderedDictionary<String, GRPCEnum> = [:]
    var messages: OrderedDictionary<String, GRPCMessage> = [:]

    init(_ file: FileDescriptor, document: APIDocument, migrationGuide: MigrationGuide, namer: SwiftProtobufNamer) {
        self.protoFile = file
        self.document = document
        self.migrationGuide = migrationGuide
        self.namer = namer

        for `enum` in file.enums {
            self.enums[`enum`.name] = GRPCEnum(descriptor: `enum`, namer: namer)
        }

        for message in file.messages {
            self.messages[message.name] = GRPCMessage(descriptor: message, namer: namer)
        }

        for model in document.models {
            modelIdTranslation[model.deltaIdentifier] = model.typeName
        }

        parseModelChanges()
    }

    var renderableContent: String {
        FileHeaderComment()

        Import(.foundation)
        if !SwiftProtobufInfo.isBundledProto(file: protoFile.proto) {
            Import("\(namer.swiftProtobufModuleName)")
        }
        ""
        // TODO generatorOptions.protoToModuleMappings.neededModules(forFile: fileDescriptor)

        protobufAPIVersionCheck

        for `enum` in enums.values {
            `enum`.primaryModelType
        }

        for message in messages.values {
            message.primaryModelType
            // TODO generateCaseIterable for nested enums?
        }

        // TODO `_protobuf_package` thingy?

        for `enum` in messages.values {
            `enum`.protobufferRuntimeSupport
        }

        for message in messages.values {
            message.protobufferRuntimeSupport
        }

        // TODO generate codable support
        //  "extension \(fullName): Codable {}" // TODO unknown fields must conform to codable?
    }

    @SourceCodeBuilder
    private var protobufAPIVersionCheck: String {
        """
        // If the compiler emits an error on this type, it is because this file
        // was generated by a version of the `protoc` Swift plug-in that is
        // incompatible with the version of SwiftProtobuf to which you are linking.
        // Please ensure that you are building against the same version of the API
        // that was used to generate this file.
        """
        "fileprivate strut _GeneratedWithProtocGenSwiftVersion: \(namer.swiftProtobufModuleName).ProtobufAPIVersionCheck {"
        Indent {
            "struct _2: \(namer.swiftProtobufModuleName).ProtobufAPIVersion2 {}"
            "typealias Version = _2"
        }
        "}"
    }

    private func parseModelChanges() {
        var addedModels: [ModelChange.AdditionChange] = []
        var updatedModels: [ModelChange.UpdateChange] = []
        var removedModels: [ModelChange.RemovalChange] = []

        for change in migrationGuide.modelChanges {
            // we ignore idChange updates. Why? Because we always work with the older identifiers.
            // And client library should not modify identifiers, to maintain code compatibility

            if let addition = change.modeledAdditionChange {
                precondition(modelIdTranslation[addition.id] == nil, "Encountered model identifier conflict")
                modelIdTranslation[addition.id] = addition.added.typeName

                addedModels.append(addition)
            } else if let update = change.modeledUpdateChange {
                updatedModels.append(update)
            } else if let removal = change.modeledRemovalChange {
                removedModels.append(removal)
            }
        }

        // TODO we need empty message for nesting!

        for addedModel in addedModels {
            let model = addedModel.added
            let typeName = model.typeName // TODO we don't have refernece types right?

            for component in typeName {
                // TODO handle types nested into enums?
            }
            // TODO nested types?
        }

        for updatedModel in updatedModels {
            // TODO deltaIdentifier to TypeName translation!
            // TODO Search Model file!
        }

        for removedModel in removedModels {
            // TODO deltaIdentifier to TypeName translation!
            // TODO search model file!
        }
    }
}
