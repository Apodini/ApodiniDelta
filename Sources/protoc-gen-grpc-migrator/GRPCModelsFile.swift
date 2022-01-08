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
    let migrationGuide: MigrationGuide
    let namer: SwiftProtobufNamer

    var enums: OrderedDictionary<String, GRPCEnum> = [:]
    var messages: OrderedDictionary<String, GRPCMessage> = [:]

    init(_ file: FileDescriptor, migrationGuide: MigrationGuide, namer: SwiftProtobufNamer) {
        self.protoFile = file
        self.migrationGuide = migrationGuide
        self.namer = namer

        for `enum` in file.enums {
            self.enums[`enum`.name] = GRPCEnum(descriptor: `enum`, namer: namer)
        }

        for message in file.messages {
            self.messages[message.name] = GRPCMessage(descriptor: message, namer: namer)
        }
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
}
