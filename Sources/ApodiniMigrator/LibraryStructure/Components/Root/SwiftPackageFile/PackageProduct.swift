//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

enum PackageProductType {
    case library
    case executable
    case plugin
}

struct PackageProduct: SourceCodeRenderable {
    let type: PackageProductType
    let name: [NameComponent]
    // Note: Library type for type=`.library` is unsupported right now!
    let targets: [[NameComponent]]

    var renderableContent: String {
        """
        .\(type)(name: "\(name.nameString)", targets: [\(
            targets.map { "\"\($0.nameString)\"" }.joined(separator: ",")
        )])
        """
    }
}
