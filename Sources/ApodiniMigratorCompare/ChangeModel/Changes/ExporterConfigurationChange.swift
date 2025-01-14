//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// ``Change`` type which is related to an `ExporterConfiguration`.
/// `.update` changes are encoded as ``ExporterConfigurationUpdateChange``.
public typealias ExporterConfigurationChange = Change<AnyExporterConfiguration>

extension AnyExporterConfiguration: ChangeableElement {
    public typealias Update = ExporterConfigurationUpdateChange
}

public struct ExporterConfigurationUpdateChange: Codable, Equatable {
    public let from: AnyExporterConfiguration
    public let to: AnyExporterConfiguration
}
