//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// Defines a element which changes can be described via the ApodiniMigrator ``Change`` model.
public protocol ChangeableElement: DeltaIdentifiable, Equatable, Codable {
    /// Represents the type how an update change is represented.
    associatedtype Update: Codable, Equatable
}
