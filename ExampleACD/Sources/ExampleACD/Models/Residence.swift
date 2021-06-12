//
//  Residence.swift
//
//  Created by ApodiniMigrator on 31.05.2021
//  Copyright © 2021 TUM LS1. All rights reserved.
//

import Foundation

// MARK: - Model
public struct Residence: Codable {
    // MARK: - CodingKeys
    private enum CodingKeys: String, CodingKey {
        case address = "address"
        case country = "country"
        case id = "id"
        case postalCode = "postalCode"
    }
    
    // MARK: - Properties
    public let address: String
    public let country: String
    public let id: UUID?
    public let postalCode: String
    
    // MARK: - Initializer
    public init(
        address: String,
        country: String,
        id: UUID?,
        postalCode: String
    ) {
        self.address = address
        self.country = country
        self.id = id
        self.postalCode = postalCode
    }
    
    // MARK: - Encodable
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(address, forKey: .address)
        try container.encode(country, forKey: .country)
        try container.encode(id, forKey: .id)
        try container.encode(postalCode, forKey: .postalCode)
    }
    
    // MARK: - Decodable
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        address = try container.decode(String.self, forKey: .address)
        country = try container.decode(String.self, forKey: .country)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        postalCode = try container.decode(String.self, forKey: .postalCode)
    }
}