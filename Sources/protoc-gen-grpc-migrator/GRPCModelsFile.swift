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
/// * We don't support nesting types into enums (as the proto spec doesn't support this).
class GRPCModelsFile: SourceCodeRenderable, ModelContaining {
    let protoFile: FileDescriptor
    let context: ProtoFileContext
    let migration: MigrationContext

    var fullName: String {
        ""
    }

    var modelIdTranslation: [DeltaIdentifier: TypeName] = [:]

    var nestedEnums: OrderedDictionary<String, GRPCEnum> = [:]
    var nestedMessages: OrderedDictionary<String, GRPCMessage> = [:]

    init(_ file: FileDescriptor, context: ProtoFileContext, migration: MigrationContext) {
        precondition(file.syntax != .proto2, "Proto2 syntax is unsupported!")
        self.protoFile = file
        self.context = context
        self.migration = migration

        for `enum` in file.enums {
            self.nestedEnums[`enum`.name] = GRPCEnum(
                ProtoGRPCEnum(descriptor: `enum`, context: context)
            )
        }

        for message in file.messages {
            self.nestedMessages[message.name] = GRPCMessage(
                ProtoGRPCMessage(descriptor: message, context: context, migration: migration)
            )
        }

        for model in migration.document.models {
            modelIdTranslation[model.deltaIdentifier] = model.typeName
        }

        parseModelChanges()
    }

    var renderableContent: String {
        FileHeaderComment()

        Import(.foundation)
        if !SwiftProtobufInfo.isBundledProto(file: protoFile.proto) {
            Import("\(context.namer.swiftProtobufModuleName)")
        }
        ""

        protobufAPIVersionCheck

        for `enum` in nestedEnums.values {
            `enum`
        }

        for message in nestedMessages.values {
            message
        }

        if !protoFile.package.isEmpty && !nestedMessages.isEmpty {
            // TODO check update grpc configuration for updated package name!
            ""
            "fileprivate let _protobuf_package = \"\(protoFile.package)\""
        }

        for `enum` in nestedEnums.values {
            `enum`.protobufferRuntimeSupport
        }

        for message in nestedMessages.values {
            message.protobufferRuntimeSupport
        }
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
        "private struct _GeneratedWithProtocGenSwiftVersion: \(context.namer.swiftProtobufModuleName).ProtobufAPIVersionCheck {"
        Indent {
            "struct _2: \(context.namer.swiftProtobufModuleName).ProtobufAPIVersion_2 {}"
            "typealias Version = _2"
        }
        "}"
    }

    private func parseModelChanges() { // swiftlint:disable:this cyclomatic_complexity
        var renamedModels: [ModelChange.IdentifierChange] = []
        var addedModels: [ModelChange.AdditionChange] = []
        var updatedModels: [ModelChange.UpdateChange] = []
        var removedModels: [ModelChange.RemovalChange] = []

        for change in migration.migrationGuide.modelChanges {
            if let rename = change.modeledIdentifierChange {
                // we ignore idChange updates. Why? Because we always work with the older identifiers.
                // And client library should not modify identifiers, to maintain code compatibility
                // Nonetheless, as this is all built around the central `Changeable` protocol,
                // we still forward those changes to the `ProtoGRPCMessage` or `ProtoGRPCEnum`.

                renamedModels.append(rename)
            } else if let addition = change.modeledAdditionChange {
                precondition(modelIdTranslation[addition.id] == nil, "Encountered model identifier conflict")
                modelIdTranslation[addition.id] = addition.added.typeName

                addedModels.append(addition)
            } else if let update = change.modeledUpdateChange {
                updatedModels.append(update)
            } else if let removal = change.modeledRemovalChange {
                removedModels.append(removal)
            }
        }

        // Add Endpoint Parameter wrapper types (result of the `GRPCMethodParameterCombination`)
        for model in migration.apiDocumentModelAdditions {
            // TODO only add models which aren't in the proto file!
            var this = self
            this.add(model: model)
        }

        for renamedModel in renamedModels {
            guard let typeName = modelIdTranslation[renamedModel.from] else {
                fatalError("Encountered identifier change with id \(renamedModel.from) which isn't present in our typeName lookup!")
            }

            guard let result = find(for: typeName) else {
                fatalError("Failed to locate renamed model with typeName \(typeName) and id: \(renamedModel.from) (\(renamedModel))!")
            }

            result.handleIdChange(change: renamedModel)
        }

        // we sort them such that we don't cause any conflicts with creation of `EmptyGRPCMessage` structs
        for addedModel in addedModels.sorted(by: \.added.typeName.nestedTypes.count) {
            let model = migration.typeStore.construct(from: addedModel.added)

            // see https://stackoverflow.com/questions/51623693/cannot-use-mutating-member-on-immutable-value-self-is-immutable
            var this = self // we are a class so this works!
            this.add(model: model)
        }

        for updatedModel in updatedModels {
            guard let typeName = modelIdTranslation[updatedModel.id] else {
                fatalError("Encountered update change with id \(updatedModel.id) which isn't present in our typeName lookup!")
            }

            guard let result = find(for: typeName) else {
                fatalError("Failed to locate updated model with typeName '\(typeName.rawValue)' and id: \(updatedModel.id) (\(updatedModel))!")
            }

            result.handleUpdateChange(change: updatedModel)
        }

        for removedModel in removedModels {
            guard let typeName = modelIdTranslation[removedModel.id] else {
                fatalError("Encountered remove change with id \(removedModel.id) which isn't present in our typeName lookup!")
            }

            guard let result = find(for: typeName) else {
                fatalError("Failed to locate removed model with typeName \(typeName) and id: \(removedModel.id) (\(removedModel))!")
            }

            result.handleRemovalChange(change: removedModel)
        }
    }
}
