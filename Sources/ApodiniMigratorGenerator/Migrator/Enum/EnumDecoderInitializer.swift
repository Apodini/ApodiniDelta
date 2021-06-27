//
//  File.swift
//  
//
//  Created by Eldi Cano on 09.05.21.
//

import Foundation

struct EnumDecoderInitializer: Renderable {
    /// The default enum case to be set in the initializer
    let defaultCase: EnumCase
    
    /// Initializer
    init(_ cases: [EnumCase]) {
        guard let defaultCase = cases.first else {
            fatalError("Something went fundamentally wrong. Enum types supported by ApodiniMigrator, must encode and decode their rawValue as String")
        }
        self.defaultCase = defaultCase
    }
    
    /// Renders the content of the initializer in a non-formatted way
    func render() -> String {
        """
        public init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(RawValue.self)) ?? .\(defaultCase.name)
        }
        """
    }
}