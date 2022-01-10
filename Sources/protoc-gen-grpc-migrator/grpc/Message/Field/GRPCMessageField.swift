//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ApodiniMigrator

@dynamicMemberLookup
struct GRPCMessageField {
    private let field: SomeGRPCMessageField

    var generateTraverseUsesLocals: Bool { // TODO what the hell is this
        !field.isRepeated && field.hasFieldPresence
    }

    init(_ field: SomeGRPCMessageField) {
        self.field = field
    }

    subscript<T>(dynamicMember member: KeyPath<SomeGRPCMessageField, T>) -> T {
        field[keyPath: member]
    }

    // TODO tryTyped?

    @SourceCodeBuilder
    var propertyInterface: String {
        // TODO visibility on all generated thingys
        if let comments = field.sourceCodeComments {
            comments
        }

        // TODO heapStorage thingy?

        if field.hasFieldPresence {
            "public var \(field.name): \(field.typeName) {"
            Indent {
                "get {"
                Indent("return \(field.privateName) ?? \(field.defaultValue)")
                "}"
                "set {"
                Indent("\(field.privateName) = newValue")
                "}"
            }
            "}"
        } else {
            "public var \(field.name): \(field.storageType) = \(field.defaultValue)"
        }

        if field.hasFieldPresence {
            ""
            "public var \(field.propertyHasName): Bool {"
            Indent("return \(field.privateName) != nil")
            "}"
            ""
            "public mutating func \(field.funcClearName)() {"
            Indent("\(field.privateName) = nil")
            "}"
        }
    }

    @SourceCodeBuilder
    var fieldDecodeCase: String {
        var decoderMethod: String = ""
        var fieldTypeArg: String = ""

        if field.isMap {
            decoderMethod = "decodeMapField"
            fieldTypeArg = "fieldType: \(field.traitsType).self, "
        } else {
            let modifier = field.isRepeated ? "Repeated" : "Singular"
            decoderMethod = "decode\(modifier)\(field.protoGenericType)Field"
            fieldTypeArg = ""
        }

        "case \(field.number): try { try decoder.\(decoderMethod)(\(fieldTypeArg)value: &\(field.storedProperty)) }()"
    }

    @SourceCodeBuilder
    var traverseExpression: String {
        var visitMethod: String = ""
        var traitsArg: String = ""
        if field.isMap {
            visitMethod = "visitMapField"
            traitsArg = "fieldType: \(field.traitsType).self, "
        } else {
            let modifier = field.isPacked ? "Packed" : field.isRepeated ? "Repeated" : "Singular"
            visitMethod = "visit\(modifier)\(field.protoGenericType)Field"
            traitsArg = ""
        }

        let varName = field.hasFieldPresence ? "value" : field.storedProperty

        var usesLocals = false
        var conditional: String = ""
        if field.isRepeated {
            conditional = "!\(varName).isEmpty"
        } else if field.hasFieldPresence {
            conditional = "let value = \(field.storedProperty)"
            usesLocals = true
        } else {
            switch field.type {
            case .string, .bytes:
                conditional = ("!\(varName).isEmpty")
            default:
                conditional = ("\(varName) != \(field.defaultValue)")
            }
        }


        assert(usesLocals == generateTraverseUsesLocals)

        let prefix = usesLocals ? "try { " : ""
        let suffix = usesLocals ? " }()" : ""

        "\(prefix)if \(conditional) {"
        Indent("try visitor.\(visitMethod)(\(traitsArg)value: \(varName), fieldNumber: \(field.number))")
        "}\(suffix)"
    }
}