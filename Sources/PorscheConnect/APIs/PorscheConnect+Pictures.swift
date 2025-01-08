import CoreLocation
import Foundation

extension PorscheConnect {
    public func pictures(vin: String) async throws -> (
        pictures: [Picture]?, response: HTTPURLResponse
    ) {
        let headers = try await performAuthFor(application: .api)
        
        let result = try await networkClient.get(
            PicturesResponse.self,
            url: networkRoutes.vehiclePicturesURL(vin: vin),
            headers: headers,
            jsonKeyDecodingStrategy: .useDefaultKeys)
        return (pictures: result.data?.pictures, response: result.response)
    }
}

// MARK: - Response types

public struct PicturesResponse: Decodable {
    public let pictures: [Picture]
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.singleValueContainer()
        self.pictures = try container.decode([Picture].self)
    }
}
