import Foundation

enum TypeDescriptor: Value {
    /// A scalar type
    case scalar(PrimitiveType)
    /// A repeated type (set or array), with `TypeDescriptor` elements
    indirect case repeated(element: TypeDescriptor)
    /// A dictionary with primitive keys and `TypeDescriptor` values
    indirect case dictionary(key: PrimitiveType, value: TypeDescriptor)
    /// An optional type with `TypeDescriptor` wrapped values
    indirect case optional(wrappedValue: TypeDescriptor)
    /// An enum type with `String` cases
    case `enum`(name: TypeName, cases: [EnumCase])
    /// An object type with properties of containing `TypeDescriptor` and a name
    case object(name: TypeName, properties: [TypeProperty])
    /// A reference created at `TypesStore` that uniquely identifies the type inside the store
    case reference(ReferenceKey)
}

// MARK: - TypeDescriptor + Equatable
extension TypeDescriptor {
    static func == (lhs: TypeDescriptor, rhs: TypeDescriptor) -> Bool {
        if !lhs.sameType(with: rhs) {
            return false
        }
        
        switch (lhs, rhs) {
        case let (.scalar(lhsPrimitiveType), .scalar(rhsPrimitiveType)):
            return lhsPrimitiveType == rhsPrimitiveType
        case let (.repeated(lhsElement), .repeated(rhsElement)):
            return lhsElement == rhsElement
        case let (.dictionary(lhsKey, lhsValue), .dictionary(rhsKey, rhsValue)):
            return lhsKey == rhsKey && lhsValue == rhsValue
        case let (.optional(lhsWrappedValue), .optional(rhsWrappedValue)):
            return lhsWrappedValue == rhsWrappedValue
        case let (.enum(lhsName, lhsCases), .enum(rhsName, rhsCases)):
            return lhsName == rhsName && lhsCases.equalsIgnoringOrder(to: rhsCases)
        case let (.object(lhsName, lhsProperties), .object(rhsName, rhsProperties)):
            return lhsName == rhsName && lhsProperties.equalsIgnoringOrder(to: rhsProperties)
        case let (.reference(lhsKey), .reference(rhsKey)):
            return lhsKey == rhsKey
        default: return false
        }
    }
}

// MARK: - TypeDescriptor + Codable
extension TypeDescriptor {
    // MARK: CodingKeys
    private enum CodingKeys: String, CodingKey {
        case scalar, repeated, dictionary, optional, `enum`, object, reference
    }
    
    private enum DictionaryKeys: String, CodingKey {
        case key, value
    }
    
    private enum EnumKeys: String, CodingKey {
        case typeName, cases
    }
    
    private enum ObjectKeys: String, CodingKey {
        case typeName, properties
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .scalar(primitiveType): try container.encode(primitiveType, forKey: .scalar)
        case let .repeated(element): try container.encode(element, forKey: .repeated)
        case let .dictionary(key, value):
            var dictionaryContainer = container.nestedContainer(keyedBy: DictionaryKeys.self, forKey: .dictionary)
            try dictionaryContainer.encode(key, forKey: .key)
            try dictionaryContainer.encode(value, forKey: .value)
        case let .optional(wrappedValue): try container.encode(wrappedValue, forKey: .optional)
        case let .enum(name, cases):
            var enumContainer = container.nestedContainer(keyedBy: EnumKeys.self, forKey: .enum)
            try enumContainer.encode(name, forKey: .typeName)
            try enumContainer.encode(cases, forKey: .cases)
        case let .object(name, properties):
            var objectContainer = container.nestedContainer(keyedBy: ObjectKeys.self, forKey: .object)
            try objectContainer.encode(name, forKey: .typeName)
            try objectContainer.encode(properties, forKey: .properties)
        case let .reference(key): try container.encode(key, forKey: .reference)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let key = container.allKeys.first
        switch key {
        case .scalar: self = .scalar(try container.decode(PrimitiveType.self, forKey: .scalar))
        case .repeated: self = .repeated(element: try container.decode(TypeDescriptor.self, forKey: .repeated))
        case .optional: self = .optional(wrappedValue: try container.decode(TypeDescriptor.self, forKey: .optional))
        case .dictionary:
            let dictionaryContainer = try container.nestedContainer(keyedBy: DictionaryKeys.self, forKey: .dictionary)
            self = .dictionary(
                key: try dictionaryContainer.decode(PrimitiveType.self, forKey: .key),
                value: try dictionaryContainer.decode(TypeDescriptor.self, forKey: .value)
            )
        case .enum:
            let enumContainer = try container.nestedContainer(keyedBy: EnumKeys.self, forKey: .enum)
            let name = try enumContainer.decode(TypeName.self, forKey: .typeName)
            let cases = try enumContainer.decode([EnumCase].self, forKey: .cases)
            self = .enum(name: name, cases: cases)
        case .object:
            let objectContainer = try container.nestedContainer(keyedBy: ObjectKeys.self, forKey: .object)
            self = .object(
                name: try objectContainer.decode(TypeName.self, forKey: .typeName),
                properties: try objectContainer.decode([TypeProperty].self, forKey: .properties)
            )
        case .reference: self = .reference(try container.decode(ReferenceKey.self, forKey: .reference))
        default: fatalError("Failed to decode type container")
        }
    }
}

// MARK: - TypeDescriptor + CustomStringConvertible + CustomDebugStringConvertible
extension TypeDescriptor: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String {
        json
    }
    
    var debugDescription: String {
        json
    }
}