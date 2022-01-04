//
//  Created by ApodiniMigrator on 15.08.20
//  Copyright © 2020 TUM LS1. All rights reserved.
//

import Foundation

// MARK: - Endpoints
public extension TestResponse {
    /// API call for TestHandler at: updatedTests/{second}
    static func testEndpoint(
        first: String,
        isDriving: String?,
        second: UUID,
        third: TestTypesCar,
        authorization: String? = nil,
        httpHeaders: HTTPHeaders = [:]
    ) -> ApodiniPublisher<TestResponse> {
        var parameters = Parameters()
        parameters.set(first, forKey: "first")
        parameters.set(isDriving, forKey: "isDriving")
        
        var headers = httpHeaders
        headers.setContentType(to: "application/json")
        
        var errors: [ApodiniError] = []
        errors.addError(404, message: "Not found")
        
        let handler = Handler<TestResponse>(
            path: "updatedTests/\(second)",
            httpMethod: .get,
            parameters: parameters,
            headers: headers,
            content: NetworkingService.encode(third),
            authorization: authorization,
            errors: errors
        )
        
        return NetworkingService.trigger(handler)
    }
}
