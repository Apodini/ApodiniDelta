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

@dynamicMemberLookup
struct GRPCEnum: SourceCodeRenderable {
    private static let unrecognizedCaseName = "UNRECOGNIZED"

    private let `enum`: SomeGRPCEnum
    var context: ProtoFileContext {
        `enum`.context
    }

    init(_ `enum`: SomeGRPCEnum) {
        self.enum = `enum`
    }

    subscript<T>(dynamicMember member: KeyPath<SomeGRPCEnum, T>) -> T {
        `enum`[keyPath: member]
    }

    func tryTyped<Enum: SomeGRPCEnum>(for type: Enum.Type = Enum.self) -> Enum? {
        `enum` as? Enum
    }

    var renderableContent: String {
        var deprecatedCases: [GRPCEnumCase] = []

        ""
        if var comments = `enum`.sourceCodeComments, !comments.isEmpty {
            _ = comments.removeLast() // removing last trailing "\n"
            comments
        }

        if `enum`.unavailable {
            "@available(*, deprecated, message: \"This enum was removed in the latest version!\")"
        } else if `enum`.containsRootTypeChange {
            """
            @available(*, deprecated, message: \"ApodiniMigrator is not able to handle the migration of this enum. \
            Change from enum to object or vice versa is currently not supported.\")
            """
        }

        "\(context.options.visibility) enum \(`enum`.relativeName): \(context.namer.swiftProtobufModuleName).Enum, CaseIterable {"
        Indent { // swiftlint:disable:this closure_body_length
            "\(context.options.visibility) typealias RawValue = Int"
            ""

            for enumCase in `enum`.uniquelyNamedValues {
                if enumCase.unavailable {
                    deprecatedCases.append(enumCase)
                }

                // if new cases are added, the client developer will be made aware of
                // through compiler errors to when it is required to adjust switch statements!

                if var comments = enumCase.sourceCodeComments, !comments.isEmpty {
                    _ = comments.removeLast() // removing last trailing "\n"
                    comments
                }

                if enumCase.unavailable {
                    "@available(*, deprecated, message: \"This enum case was removed in the latest version!\")"
                }

                if let aliasOf = enumCase.aliasOf {
                    "\(context.options.visibility) static let \(enumCase.relativeName) = \(aliasOf.relativeName)"
                } else {
                    "case \(enumCase.relativeName) // = \(enumCase.number)"
                }
            }
            if context.hasUnknownPreservingSemantics {
                "case \(Self.unrecognizedCaseName)(Int)"
            }

            // rawValue property
            ""
            "\(context.options.visibility) var rawValue: Int {"
            // rawValue is directly put into the proto encoder.
            // Therefore, as we otherwise can't handle it, rely on the web service parser to ignore removed fields
            // (which is the case for Apodini). This way, we also avoid to break any client applications which rely on `rawValue`.
            // Another option would be to use the enum `defaultValue`. Though the risk of breaking something is probably higher.
            Indent {
                "switch self {"
                for enumCase in `enum`.enumCasesSorted {
                    "case \(enumCase.dottedRelativeName): return \(enumCase.number)"
                }

                if context.hasUnknownPreservingSemantics {
                    "case let .\(Self.unrecognizedCaseName)(number): return number"
                }
                "}"
            }
            "}"

            // CaseIterable
            if context.hasUnknownPreservingSemantics {
                ""
                "\(context.options.visibility) static var allCases: [\(`enum`.fullName)] = ["
                Indent {
                    Joined(by: ",") {
                        for enumCase in `enum`.enumCasesSorted {
                            "\(enumCase.dottedRelativeName)"
                        }
                    }
                }
                "]"
            }


            // default value init
            ""
            "\(context.options.visibility) init() {"
            Indent("self = \(`enum`.defaultValue.dottedRelativeName)")
            "}"

            // RawValue init
            ""
            "\(context.options.visibility) init\(context.hasUnknownPreservingSemantics ? "": "?")(rawValue: Int) {"
            Indent {
                "switch rawValue {"
                var generatedNumbers: [Int] = []

                for enumCase in `enum`.enumCasesSorted where !enumCase.unavailable {
                    "case \(enumCase.number): self = \(enumCase.dottedRelativeName)"
                    generatedNumbers.append(enumCase.number)
                }

                // in some non-well maintained web service migrations it might be the case that
                // the grpc number of a removed case is reassigned to an existing or new property.
                // Therefore, whe need to avoid potential collisions
                for enumCase in `enum`.enumCasesSorted where enumCase.unavailable {
                    """
                    \(generatedNumbers.contains(enumCase.number) ? "// [DEPRECATED]" : "")\
                    case \(enumCase.number): self = \(enumCase.dottedRelativeName)
                    """
                }

                if context.hasUnknownPreservingSemantics {
                    "default: self = .\(Self.unrecognizedCaseName)(rawValue)"
                } else {
                    "default: return nil"
                }
                "}"
            }
            "}"
        }
        "}"
    }

    private func nameMapLine(enumCase: GRPCEnumCase) -> String {
        if enumCase.aliases.isEmpty {
            return "\(enumCase.number): .same(proto: \"\(enumCase.name)\")"
        } else {
            let aliasNames = enumCase.aliases
                .map { "\"\($0.name)\"" }
                .joined(separator: ", ")
            return "\(enumCase.number): .aliased(proto: \"\(enumCase.name)\", aliases: [\(aliasNames)])"
        }
    }

    @SourceCodeBuilder
    var protobufferRuntimeSupport: String {
        ""
        MARKComment("RuntimeSupport")
        "extension \(`enum`.fullName): \(context.namer.swiftProtobufModuleName)._ProtoNameProviding {"
        Indent {
            "\(context.options.visibility) static let _protobuf_nameMap: \(context.namer.swiftProtobufModuleName)._NameMap = ["
            Indent {
                Joined(by: ",") {
                    // see above for explanation
                    var generatedNumbers: [Int] = []

                    for enumCase in `enum`.enumCasesSorted where !enumCase.unavailable {
                        nameMapLine(enumCase: enumCase)
                        generatedNumbers.append(enumCase.number)
                    }

                    for enumCase in `enum`.enumCasesSorted where enumCase.unavailable {
                        "\(generatedNumbers.contains(enumCase.number) ? "// [DEPRECATED] " : "")\(nameMapLine(enumCase: enumCase))"
                    }
                }
            }
            "]"
        }
        "}"
        ""
        MARKComment("Codable")
        "extension \(`enum`.fullName): Codable {"
        Indent {
            "private var nameRawValue: String {"
            Indent {
                "switch self {"
                for enumCase in `enum`.enumCasesSorted {
                    // we follow here the assumption of the `TypeInformation` framework that `name`=`rawValue`.
                    // All the Codable migration based stuff is build around this assumption.
                    // Therefore, we introduce this additional raw value type.
                    "case \(enumCase.dottedRelativeName): return \"\(enumCase.name)\""
                }
                // handling the `unrecognizedCase`
                "default: fatalError(\"Can't derive nameRawValue for \\(self)\")"
                "}"
            }
            "}"

            ""
            "\(context.options.visibility) func encode(to encoder: Encoder) throws {"
            Indent {
                """
                var container = encoder.singleValueContainer()

                try container.encode(self.nameRawValue)
                """
            }
            "}"

            ""
            "\(context.options.visibility) init(from decoder: Swift.Decoder) throws {"
            Indent {
                "let container = try decoder.singleValueContainer()"

                // As we need to conform to the SwiftProtobuf `Enum` protocol we have RawRepresentable conformance
                // with rawValue of `Int` (the proto number). The JSONStringBuilder works on the TypeInformation
                // representation of the type. Meaning it will create default value of `0` (Int rawValue type)
                // and this value will be passed to the decoder initializer. Either we change the logic in the JSONStringBuilder
                // or, as we do here, work around the issue, by implementing number decoding.
                "if let number = try? container.decode(Int.self) {"
                Indent {
                    "self = .init(rawValue: number)"
                    "return"
                }
                "}"
                ""

                "let nameRawValue: String = try container.decode(String.self)"
                "switch nameRawValue {"
                for enumCase in `enum`.enumCasesSorted {
                    "case \"\(enumCase.name)\": self = \(enumCase.dottedRelativeName)"
                }
                "default: self = \(`enum`.defaultValue.dottedRelativeName)"
                "}"
            }
            "}"
        }
        "}"
    }
}
