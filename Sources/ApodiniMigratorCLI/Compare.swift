//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2022 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import Foundation
import ArgumentParser
import RESTMigrator
import ApodiniDocumentExport

struct Compare: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Compare API documents and automatically generate a migration guide between two versions."
    )
    
    @Option(name: .shortAndLong, help: "Path to API document of the old version, e.g. /path/to/api_v1.0.0.json")
    var oldDocumentPath: String
    
    @Option(name: .shortAndLong, help: "Path to API document of the new version, e.g. /path/to/api_v1.2.0.yaml")
    var newDocumentPath: String
    
    @Option(name: .shortAndLong, help: "Path to a directory where the migration guide should be persisted, e.g. /path/to/directory")
    var migrationGuidePath: String
    
    @Option(name: .shortAndLong, help: "Output format of the migration guide, either JSON or YAML. JSON by default")
    var format: OutputFormat = .json
    
    func run() throws {
        let logger = RESTMigrator.logger

        logger.info("Starting generation of the migration guide...")
        do {
            let migrationGuideFileName = "migration_guide"
            let migrationGuide = try MigrationGuide.from(Path(oldDocumentPath), Path(newDocumentPath))
            let filePath = try migrationGuide.write(at: migrationGuidePath, outputFormat: format, fileName: migrationGuideFileName)
            logger.info("Migration guide was generated successfully at \(filePath).")
        } catch {
            logger.error("Migration guide generation failed with error: \(error)")
        }
    }
}
