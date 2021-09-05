//
// This source file is part of the Apodini open source project
//
// SPDX-FileCopyrightText: 2019-2021 Paul Schmiedmayer and the Apodini project authors (see CONTRIBUTORS.md) <paul.schmiedmayer@tum.de>
//
// SPDX-License-Identifier: MIT
//

import XCTest
@testable import ApodiniMigrator
@testable import ApodiniMigratorShared
@testable import ApodiniMigratorCompare

final class MigrationGuideTests: ApodiniMigratorXCTestCase {
    func testPackageMigration() throws {
        let mig = try MigrationGuide.decode(from: try Documents.migrationGuide.data())
        let migrator = XCTAssertNoThrowWithResult(try Migrator(
            packageName: "TestMigPackage",
            packagePath: testDirectory,
            documentPath: Documents.v1.path.string,
            migrationGuide: mig
        ))
        
        XCTAssertNoThrow(try migrator.migrate())
        XCTAssert(try testDirectoryPath.recursiveSwiftFiles().isNotEmpty)
        XCTAssert(try (testDirectoryPath + "nonexisting").recursiveSwiftFiles().isEmpty)
    }
    
    func testProjectFilesUpdater() throws {
        try ProjectFilesUpdater.run()
    }
    
    func testMigrationGuideThrowing() throws {
        XCTAssertThrows(try MigrationGuide.from(Path(#file), .init(.endpoints)))
        XCTAssertThrows(try MigrationGuide.from("", ""))
    }
    
    func testEnumDelete() throws {
        struct User {
            let name: String
            let id: UUID
            let age: Int
        }
        // TODO review
        let typeInfo = try TypeInformation(type: User.self)
        _ = ObjectMigrator(typeInfo, changes: [DeleteChange(element: .object(typeInfo.deltaIdentifier, target: .`self`), deleted: .none, fallbackValue: .none, breaking: true, solvable: false, includeProviderSupport: false)])
        
        let endpoint = Endpoint(handlerName: "TestHandler", deltaIdentifier: "sayHelloWorld", operation: .read, absolutePath: "/v1/hello", parameters: [], response: .scalar(.string), errors: [.init(code: 404, message: "Could not say hello")])
        
        let change = DeleteChange(
            element: .endpoint(endpoint.deltaIdentifier, target: .`self`),
            deleted: .none,
            fallbackValue: .none,
            breaking: true,
            solvable: false,
            includeProviderSupport: false)
        _ = EndpointFile(typeInformation: .scalar(.string), endpoints: [endpoint], changes: [DeleteChange(element: .endpoint(endpoint.deltaIdentifier, target: .`self`), deleted: .none, fallbackValue: .none, breaking: true, solvable: false, includeProviderSupport: false)])
        let migrator = EndpointMethodMigrator(
            endpoint,
            changes: [change]
        )
        
        try (Path(#file).parent() + "Resources/ExpectedOutputs" + "deletedSayHelloWorld.md").write(migrator.render().indentationFormatted())
    }
    
    func testMigrationGuide() throws {
        let doc1 = try Documents.v1.instance() as Document
        let doc2 = try Documents.v2.instance() as Document
        
        let migrationGuide = MigrationGuide(for: doc1, rhs: doc2)
        try (testDirectoryPath + "migration_guide.json").write(migrationGuide.json)

        let decoded = try MigrationGuide.decode(from: testDirectoryPath + "migration_guide.json")
        XCTAssert(decoded == migrationGuide)
        XCTAssert(decoded != .empty)
    }
}
