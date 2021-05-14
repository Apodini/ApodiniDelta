import Foundation
import JavaScriptCore


public extension Decodable {
    /// A function to that creates an instance of type `Self` with empty values
    static func defaultValue() throws -> Self {
        try JSONStringBuilder.instance(Self.self)
    }
    
    /// Creates an instance of type `Self`, out of an encodable value
    /// ```swift
    /// // MARK: - Code example
    /// struct Student: Codable {
    ///     let name: String
    ///     let matrNr: UUID
    /// }
    ///
    /// struct Developer: Codable {
    ///     let id: UUID
    ///     let name: String
    /// }
    /// ```
    /// In order to create a `Developer` instance out of a `Student`,
    /// the function would expect a `Student` instance for the `value` argument,
    /// and a valid javaScript code that handles the convertion
    /// ```swift
    /// let student = Student(name: "John", id: UUID())
    /// ```
    /// ```javascript
    /// function convert(input) {
    ///     let parsed = JSON.parse(input)
    ///     return JSON.stringify({ 'id' : parsed.matrNr, 'name' : parsed.name })
    /// }
    /// ```
    /// Steps inside the functions:
    /// 1. Creates a valid json represantion of `value` argument
    /// 2. Parses the function name of the javascript
    /// 3. Retrieves the `json` string returned from the javascript `convert` function with the input of Step 1.
    /// 4. The string data is used to decode the new `Developer` instance
    /// 5. The developer instance as defined in the script, is created with `id` from `matrNr` and `name` from `name` of the student
    /// 6. In case that the script is invalid, the instance is created with default empty values, e.g `Developer(name: "", id: UUID())`
    ///
    /// - Throws: The function throws if decoding fails
    static func from(_ value: Encodable, script: String) throws -> Self {
        return try initialize(from: [value.json], script: script)
    }
}

fileprivate extension Decodable {
    /// The function that handles the javascript code evaluation
    /// In case of invalidity of the script, the instance is created with default empty values
    /// - Parameters:
    ///     - jsonArgs: array with valid json strings, that will be passed in the same order as arguments in the `script`
    ///     - script: the script that will have as input the `jsonArgs` and handles the convertion
    /// - Throws: if decoding fails
    static func initialize(from jsonArgs: [String], script: String) throws -> Self {
        let context = JSContext()
        
        let functionName = script.functionName()
        
        context?.evaluateScript(script)
        
        let result = context?.objectForKeyedSubscript(functionName)?.call(withArguments: jsonArgs)?.toString()
        
        guard let jsonString = result, let data = jsonString.data(using: .utf8) else {
            return try defaultValue()
        }
        
        do {
            return try JSONStringBuilder.decode(Self.self, from: data)
        } catch {
            return try defaultValue()
        }
    }
}

public extension Decodable {
    
    /// Creates an instance of type `Self`, by means of the `value` of `EncodableContainer`
    ///
    /// ```swift
    /// // MARK: - Code example
    /// struct Student: Codable {
    ///     let name: String
    ///     let friend: Developer
    /// }
    ///
    /// struct Developer: Codable {
    ///     let id: UUID
    ///     let name: String
    /// }
    /// ```
    /// In order to create a `Student` instance the function would expect
    /// an `arg` and a `script` that are compatible, while javaScript code handles the convertion
    /// ```swift
    /// let developer = Developer(id: UUID(), name: "Swift Developer")
    /// let arg = EncodableContainer(developer)
    /// ```
    /// - Note: the `arg` must be parsed inside the function, and the value is contained in `value` field of the json string
    /// ```javascript
    /// function convert(input) {
    ///     let parsed = JSON.parse(input)
    ///     return JSON.stringify({ 'name' : "John", 'friend' : parsed.value })
    /// }
    /// ```
    /// Called with `arg` and the javascript string, the function creates a `Student`:
    /// ```swift
    /// let student = Student(name: "John", friend: developer)
    /// ```
    /// - Parameters:
    ///     - arg: `EncodableContainer` that hold the encodable value to be passed as argument in the script
    ///     - script: a valid js script that handles the convertion
    /// - Throws: The function throws if decoding fails
    static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self {
        return try initialize(from: [arg.json], script: script)
    }
    
    /// Creates an instance of type `Self`, by means of the `value` properties of `argX`
    /// - Note: See documentation for the single argument function
    /// ```swift
    /// static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self
    /// ```
    static func fromValues<E1: Encodable, E2: Encodable>(_ arg1: EncodableContainer<E1>, _ arg2: EncodableContainer<E2>, script: String) throws -> Self {
        return try initialize(from: [arg1.json, arg2.json], script: script)
    }
    
    /// Creates an instance of type `Self`, by means of the `value` properties of `argX`
    /// - Note: See documentation for the single argument function:
    /// ```swift
    /// static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self
    /// ```
    static func fromValues<E1: Encodable, E2: Encodable, E3: Encodable>(_ arg1: EncodableContainer<E1>, _ arg2: EncodableContainer<E2>, _ arg3: EncodableContainer<E3>, script: String) throws -> Self {
        return try initialize(from: [arg1.json, arg2.json, arg3.json], script: script)
    }
    
    /// Creates an instance of type `Self`, by means of the `value` properties of `argX`
    /// - Note: See documentation for the single argument function:
    /// ```swift
    /// static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self
    /// ```
    static func fromValues<E1: Encodable, E2: Encodable, E3: Encodable, E4: Encodable>(_ arg1: EncodableContainer<E1>, _ arg2: EncodableContainer<E2>, _ arg3: EncodableContainer<E3>, arg4: EncodableContainer<E4>, script: String) throws -> Self {
        return try initialize(from: [arg1.json, arg2.json, arg3.json, arg4.json], script: script)
    }
    
    /// Creates an instance of type `Self`, by means of the `value` properties of `argX`
    /// - Note: See documentation for the single argument function:
    /// ```swift
    /// static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self
    /// ```
    static func fromValues<E1: Encodable, E2: Encodable, E3: Encodable, E4: Encodable, E5: Encodable>(_ arg1: EncodableContainer<E1>, _ arg2: EncodableContainer<E2>, _ arg3: EncodableContainer<E3>, arg4: EncodableContainer<E4>, arg5: EncodableContainer<E5>, script: String) throws -> Self {
        return try initialize(from: [arg1.json, arg2.json, arg3.json, arg4.json, arg5.json], script: script)
    }
    
    /// Creates an instance of type `Self`, by means of the `value` properties of `argX`
    /// - Note: See documentation for the single argument function:
    /// ```swift
    /// static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self
    /// ```
    static func fromValues<E1: Encodable, E2: Encodable, E3: Encodable, E4: Encodable, E5: Encodable, E6: Encodable>(_ arg1: EncodableContainer<E1>, _ arg2: EncodableContainer<E2>, _ arg3: EncodableContainer<E3>, arg4: EncodableContainer<E4>, arg5: EncodableContainer<E5>, arg6: EncodableContainer<E6>, script: String) throws -> Self {
        return try initialize(from: [arg1.json, arg2.json, arg3.json, arg4.json, arg5.json, arg6.json], script: script)
    }
    
    /// Creates an instance of type `Self`, by means of the `value` properties of `argX`
    /// - Note: See documentation for the single argument function:
    /// ```swift
    /// static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self
    /// ```
    static func fromValues<E1: Encodable, E2: Encodable, E3: Encodable, E4: Encodable, E5: Encodable, E6: Encodable, E7: Encodable>(_ arg1: EncodableContainer<E1>, _ arg2: EncodableContainer<E2>, _ arg3: EncodableContainer<E3>, arg4: EncodableContainer<E4>, arg5: EncodableContainer<E5>, arg6: EncodableContainer<E6>, arg7: EncodableContainer<E7>, script: String) throws -> Self {
        return try initialize(from: [arg1.json, arg2.json, arg3.json, arg4.json, arg5.json, arg6.json, arg7.json], script: script)
    }
    
    /// Creates an instance of type `Self`, by means of the `value` properties of `argX`
    /// - Note: See documentation for the single argument function:
    /// ```swift
    /// static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self
    /// ```
    static func fromValues<E1: Encodable, E2: Encodable, E3: Encodable, E4: Encodable, E5: Encodable, E6: Encodable, E7: Encodable, E8: Encodable>(_ arg1: EncodableContainer<E1>, _ arg2: EncodableContainer<E2>, _ arg3: EncodableContainer<E3>, arg4: EncodableContainer<E4>, arg5: EncodableContainer<E5>, arg6: EncodableContainer<E6>, arg7: EncodableContainer<E7>, arg8: EncodableContainer<E8>, script: String) throws -> Self {
        return try initialize(from: [arg1.json, arg2.json, arg3.json, arg4.json, arg5.json, arg6.json, arg7.json, arg8.json], script: script)
    }
    
    /// Creates an instance of type `Self`, by means of the `value` properties of `argX`
    /// - Note: See documentation for the single argument function:
    /// ```swift
    /// static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self
    /// ```
    static func fromValues<E1: Encodable, E2: Encodable, E3: Encodable, E4: Encodable, E5: Encodable, E6: Encodable, E7: Encodable, E8: Encodable, E9: Encodable>(_ arg1: EncodableContainer<E1>, _ arg2: EncodableContainer<E2>, _ arg3: EncodableContainer<E3>, arg4: EncodableContainer<E4>, arg5: EncodableContainer<E5>, arg6: EncodableContainer<E6>, arg7: EncodableContainer<E7>, arg8: EncodableContainer<E8>, arg9: EncodableContainer<E9>, script: String) throws -> Self {
        return try initialize(from: [arg1.json, arg2.json, arg3.json, arg4.json, arg5.json, arg6.json, arg7.json, arg8.json, arg9.json], script: script)
    }
    
    /// Creates an instance of type `Self`, by means of the `value` properties of `argX`
    /// - Note: See documentation for the single argument function:
    /// ```swift
    /// static func fromValue<E: Encodable>(_ arg: EncodableContainer<E>, script: String) throws -> Self
    /// ```
    static func fromValues<E1: Encodable, E2: Encodable, E3: Encodable, E4: Encodable, E5: Encodable, E6: Encodable, E7: Encodable, E8: Encodable, E9: Encodable, E10: Encodable>(_ arg1: EncodableContainer<E1>, _ arg2: EncodableContainer<E2>, _ arg3: EncodableContainer<E3>, arg4: EncodableContainer<E4>, arg5: EncodableContainer<E5>, arg6: EncodableContainer<E6>, arg7: EncodableContainer<E7>, arg8: EncodableContainer<E8>, arg9: EncodableContainer<E9>, arg10: EncodableContainer<E10>, script: String) throws -> Self {
        return try initialize(from: [arg1.json, arg2.json, arg3.json, arg4.json, arg5.json, arg6.json, arg7.json, arg8.json, arg9.json, arg10.json], script: script)
    }
}


/// A util object used for creating an object by means of its encodable properties and a valid js script
/// Let's consider the following example
///```swift
/// // MARK: - Code example
/// struct Student: Codable {
///     let name: String
///     let id: Int
/// }
/// ```
/// In order to create an instance of type `Student`, we would simply need a `String` object for the name, and an `Int` object for the `id`
/// We could then make use of the following js script:
/// ```javascript
/// function convert(name, id) {
///     return JSON.stringify({ 'name' : JSON.parse(name), 'id' : JSON.parse(id)})
/// }
/// ```
/// We would need a function like this to create the instance:
/// ```
/// let student = try Student.instance("John", 42, script: script)
/// ```
///
/// `JSON.stringify` results the following output, e.g. for "John" and 42:
/// ```json
/// {
///     "name" : "John",
///     "id" : "42"
/// }
/// ```
/// While the produced `json` is valid, it can't be used to decode the `Student` type, since the `Int`, and in general
/// all primitve types are converted into strings from the `JSON.stringify`.
/// We overcome the issue by means of an `EncodableContainer` object
/// ```
/// let student = try Student.instance(EncodableContainer("John"), EncodableContainer(42), script: script)
/// ```
/// and an updated script:
/// ```javascript
/// function convert(name, id) {
///     let parsedName = JSON.parse(name)
///     let parsedId = JSON.parse(id)
///     return JSON.stringify({ 'name' : parsedName.value, 'id' : parsedId.value})
/// }
/// ```
/// Doing so, we obtain a valid json that can be used to decode the `Student` accordingly
/// - Note: Uses a `KeyedEncodingContainer` to encode the value under the key `value`
public struct EncodableContainer<E: Encodable>: Encodable {
    // MARK: Private Inner Types
    private enum CodingKeys: String, CodingKey {
        case value
    }
    
    /// The encodable value of the container
    public let value: E
    
    /// Initializer for `EncodableContainer`
    public init(_ value: E) {
        self.value = value
    }
    
    /// Encode method
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(value, forKey: .value)
    }
}

fileprivate extension String {
    
    /// A function to be applied on js scripts to retrieve the name of the function
    func functionName() -> String {
        let dropFunction = without("function ")
        
        if let idx = dropFunction.firstIndex(of: "(") {
            return String(dropFunction[dropFunction.startIndex ..< idx])
        }
        return self // the invalidity of the script is handled by creating defaultValue for Decodable type
    }
    
    /// A function to be applied on js scripts to retrieve the names of the input arguments
    func args() -> [String] {
        if
            let openingBracketIndex = firstIndex(of: "("),
            let closingBracketIndex = firstIndex(of: ")")
        {
            guard openingBracketIndex <= closingBracketIndex else {
                return []
            }
            
            let args = String(self[openingBracketIndex ..< closingBracketIndex].dropFirst())
            return args.split(string: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        return []
    }
}
