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

struct MigrateREST: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "rest",
        abstract: "Migrate a gRPC client library from an API document and a migration guide."
    )

    @OptionGroup
    var globalOptions: GlobalMigrateOptions

    func run() throws {
        let logger = RESTMigrator.logger

        logger.info("Starting migration of package \(globalOptions.packageName)")

        do {
            let migrator = try RESTMigrator(documentPath: globalOptions.documentPath, migrationGuidePath: globalOptions.migrationGuidePath)

            try migrator.run(packageName: globalOptions.packageName, packagePath: globalOptions.targetDirectory)
            logger.info("Package \(globalOptions.packageName) was migrated successfully. You can open the package via \(globalOptions.packageName)/Package.swift")
        } catch {
            logger.error("Package migration failed with error: \(error)")
        }
    }
}
