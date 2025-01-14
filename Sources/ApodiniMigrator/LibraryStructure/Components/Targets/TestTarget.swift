//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// A swift test target placed in ``Tests``.
public class TestTarget: Directory, TargetDirectory {
    public var type: TargetType {
        .test
    }

    public var dependencies: [TargetDependency] = []
    public var resources: [TargetResource] = []

    override public init(_ name: Name, @DefaultLibraryComponentBuilder content: () -> [LibraryComponent] = { [] }) {
        super.init(name, _content: content())
    }
}
