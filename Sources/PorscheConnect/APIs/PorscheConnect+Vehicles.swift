import Foundation
import SwiftUI

extension PorscheConnect {
    
    public func vehicles() async throws -> (vehicles: [Vehicle]?, response: HTTPURLResponse) {
        let headers = try await performAuthFor(application: .api)
        
        let result = try await networkClient.get(
            [Vehicle].self,
            url: networkRoutes.vehiclesURL,
            headers: headers,
            jsonKeyDecodingStrategy: .useDefaultKeys)
        return (vehicles: result.data, response: result.response)
    }
}

// MARK: - Response types

public struct Vehicle: Codable {
    
    // MARK: Properties
    
    public let vin: String
    public let modelType: ModelType
    public let exteriorColorName: String
    public let vehicleColor: VehicleColors
    
    // MARK: Computed Properties
    
    public var color: Color {
        Color(hex: vehicleColor.primaryExteriorColor)
    }
    
    public init(
        vin: String,
        modelType: Vehicle.ModelType,
        exteriorColorName: String,
        vehicleColor: Vehicle.VehicleColors
    ) {
        self.vin = vin
        self.modelType = modelType
        self.exteriorColorName = exteriorColorName
        self.vehicleColor = vehicleColor
    }
}

extension Vehicle {
    
    enum CodingKeys: String, CodingKey {
        case vin, modelType, exteriorColorName
        case vehicleColor = "color"
    }
    
    public struct ModelType: Codable {
        public let code: String
        public let year: String
        public let steeringPosition: String
        public let body: String
        public let generation: String
        public let revision: Int
        public let model: String
        public let engine: String
    }
    
    public struct VehicleColors: Codable {
        let primaryExteriorColor: String
    }
}
