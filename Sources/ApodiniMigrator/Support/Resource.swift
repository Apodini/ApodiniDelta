//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// A protocol to allow manipulation of bundle resources
/// Conforming types should specify the `Bundle` where the resources are stored and the name of the file
/// By default `fileExtension` is set to `markdown`. `content()` and `data()` functions also provide default implementations
public protocol Resource {
    /// File extension of this resource
    var fileExtension: FileExtension { get }
    /// Name of the resource file (without extension)
    var name: String { get }
    /// Bundle where this resource is stored
    var bundle: Bundle { get }
    
    /// The read operations of these functions are performed from the `bundle`
    /// Returns string content of the resource
    func content() -> String
    /// Returns the raw data of this resource.
    func data() throws -> Data
}

/// Default internal implementations
extension Resource {
    /// name of the file
    var fileName: String {
        "\(name).\(fileExtension.description)"
    }
    
    /// url of the file
    var fileURL: URL {
        guard let fileURL = bundle.url(forResource: fileName, withExtension: nil) else {
            fatalError("Resource \(fileName) not found")
        }
        
        return fileURL
    }
    
    /// path of the resource file
    var path: Path {
        fileURL.path.asPath
    }
}

/// Default public implementations
public extension Resource {
    /// file extension
    var fileExtension: FileExtension { .markdown }
    
    /// string content of the file without last empty line
    func content() -> String {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            fatalError("Failed to read the resource")
        }
        let lines = content.sanitizedLines()
        return lines.last?.isEmpty == true ? (lines.dropLast().joined(separator: .lineBreak)) : content
    }
    
    /// raw data content of the file
    func data() throws -> Data {
        try Data(contentsOf: fileURL)
    }
    
    /// Returns the decoded instance of the resource file
    func instance<D: Decodable>() throws -> D {
        try D.decode(from: try data())
    }
}
