import XCTest
@testable import ApodiniMigrator
@testable import ApodiniMigratorClientSupport
@testable import ApodiniMigratorGenerator
@testable import ApodiniMigratorCompare

extension ApodiniMigratorCodable {
    static var encoder: JSONEncoder {
        .init()
    }
    static var decoder: JSONDecoder {
        .init()
    }
}

typealias Codable = ApodiniMigratorCodable

final class JavaScriptConvertTests: XCTestCase {
    func testDecodableExample() throws {
        struct Student: Codable, Equatable {
            let name: String
            let matrNr: UUID
        }
        
        struct Developer: Codable, Equatable {
            let id: UUID
            let name: String
        }
        
        let student = Student(name: "John", matrNr: UUID())
        let studentToDeveloperScript =
        """
        function convert(object) {
            let parsed = JSON.parse(object)
            return JSON.stringify({ 'id' : parsed.matrNr, 'name' : parsed.name })
        }
        """
        let developer = try Developer.from(student, script: studentToDeveloperScript)
        
        let developerToStudentScript =
        """
        function convert(object) {
            let parsed = JSON.parse(object)
            return JSON.stringify({ 'matrNr' : parsed.id, 'name' : parsed.name })
        }
        """
        
        let initialStudent = try Student.from(developer, script: developerToStudentScript)
        XCTAssert(developer.id == student.matrNr)
        XCTAssert(developer.name == student.name)
        
        XCTAssert(student == initialStudent)
    }
    
    func testMultipleArguments() throws {
        struct Student: Codable, Equatable {
            let name: String
            let matrNr: UUID
            let dog: Dog
        }
        
        struct Dog: Codable, Equatable {
            let name: String
        }
        
        let constructScript =
        """
        function convert(name, matrNr, dog) {
            let parsedName = JSON.parse(name)
            let parsedMatrNr = JSON.parse(matrNr)
            let parsedDog = JSON.parse(dog)
            return JSON.stringify({ 'name' : parsedName.value, 'matrNr' : parsedMatrNr.value, 'dog' : parsedDog.value })
        }
        """
        
        let student = try Student.fromValues(.init("John"), .init(UUID()), .init(Dog(name: "Dog")), script: constructScript)
        
        
        XCTAssert(student.dog.name == "Dog")
        XCTAssert(student.name == "John")
    }
    
    func testMalformedInputAndScript() throws {
        struct Student: Codable, Equatable {
            let name: String
            let github: URL
            let dog: Dog
        }
        
        struct Dog: Codable, Equatable {
            let name: String
        }
        
        let constructScript =
        """
        function convert(name, matrNr, dog) {
            return JSON object { name, s, dog with name dog }
        }
        """
        
        let someInstance: [String???]? = []
        
        // input is wrong, and the script is invalid, the default empty instance is created
        let student = try Student.from(someInstance, script: constructScript)
        
        XCTAssert(student.name == .defaultValue)
        XCTAssert(student.github == .defaultValue)
    }
    
    func testPackageGenerator() throws {
        let packagePath: Path = .desktop
        
        let document = Path.desktop + "document.json"
        
        let gen = try ApodiniMigratorGenerator(packageName: "HelloWorld", packagePath: packagePath.string, documentPath: document.string)
        XCTAssertNoThrow(try gen.build())
    }
    
    func testPackageFilesCollector() throws {
        let packageFilesCollector = PackageFilesCollector(packageName: "HelloWorld", packagePath: .desktop)
        
        let user = packageFilesCollector.model(name: "Contact")
        
        var objectFileParser = try ObjectFileParser(path: user)
        
        let endpoint = packageFilesCollector.endpoint(name: "Contact")
        
        let fileParser = try EndpointFileParser(path: endpoint)
        try fileParser.save()
        objectFileParser.addCodingKeyCase(name: "someTest")
        try objectFileParser.save()
    }
    
    func testMigraionGuideGeneration() throws {
        let doc = Path.desktop + "document.json"
        let doc2 = Path.desktop + "document_updated.json"
        
        let document1 = try Document.decode(from: doc)
        let document2 = try Document.decode(from: doc2)
        
        let migrationGuide = MigrationGuide(for: document1, rhs: document2)
        try! (Path.desktop + "migration_guide.json").write(migrationGuide.json)
    }
    
    func testEndpointPath() throws {
        let string = "/v1/{some}/users/{id}"
        let string1 = "/v1/{s}/users/{idsdad}"
        let string2 = "/v2/{s}/users/{idsdad}" // still considered equal, change is delegated to networking due to version change
  
        XCTAssert(EndpointPath(string) == EndpointPath(string1))
        XCTAssert(EndpointPath(string1) == EndpointPath(string2))
    }
    
//    func testFluent() throws {
//        let contact = try TypeInformation(type: Contact.self)
//        let residence = try TypeInformation(type: Residence.self)
//        
//        contact.write(at: .desktop, fileName: "Contact")
//        residence.write(at: .desktop, fileName: "Residence")
//        
//        let planetTag = try TypeInformation(type: PlanetTag.self)
//        planetTag.write(at: .desktop, fileName: "PlanetTag")
//    }
}
