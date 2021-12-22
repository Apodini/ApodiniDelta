//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

@resultBuilder
public enum RootLibraryComponentBuilder {
    public static func buildExpression(_ expression: Sources) -> [LibraryComponent] {
        [expression]
    }

    public static func buildExpression(_ expression: Tests) -> [LibraryComponent] {
        [expression]
    }

    // TODO we currently do not allow ANY directories?

    public static func buildExpression(_ expression: LibraryNode) -> [LibraryComponent] {
        [expression]
    }

    public static func buildBlock(_ components: [LibraryComponent]...) -> [LibraryComponent] {
        components.flatten()
    }

    public static func buildEither(first component: [LibraryComponent]) -> [LibraryComponent] {
        component
    }

    public static func buildEither(second component: [LibraryComponent]) -> [LibraryComponent] {
        component
    }

    public static func buildOptional(_ component: [LibraryComponent]?) -> [LibraryComponent] {
        component ?? [Empty()]
    }

    public static func buildArray(_ components: [[LibraryComponent]]) -> [LibraryComponent] {
        components.flatten()
    }

    public static func buildFinalResult(_ component: [LibraryComponent]) -> RootDirectory {
        RootDirectory(content: component)
    }
}