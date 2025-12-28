import Foundation

extension PorscheConnect {
    public func summary(vin: String) async throws -> (
        summary: Summary?,
        response: HTTPURLResponse
    ) {
        let headers = try await performAuthFor(application: .api)
        
        let result = try await networkClient.get(
            Summary.self,
            url: networkRoutes.vehicle(vin: vin, measurements: VehicleMeasurement.allCases),
            headers: headers,
            jsonKeyDecodingStrategy: .useDefaultKeys)
        
        return (summary: result.data, response: result.response)
    }
}

// MARK: - Response types

public struct Summary: Decodable {
    
    // MARK: Properties
    public let vehicle: Vehicle
    public let measurements: Measurements
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.vehicle = try Vehicle(from: decoder)
        self.measurements = try container.decode(Measurements.self, forKey: .measurements)
    }
    
    enum CodingKeys: String, CodingKey {
        case measurements
    }
}

public extension Summary {
    
    struct Measurements: Decodable {
        public let mileage: Mileage
        public let tirePressure: Tires?
        
        public init(from decoder: any Decoder) throws {
            var container = try decoder.singleValueContainer()
            let measurements = try container.decode([Measurement].self)
            
            guard let mileage = measurements.compactMap({
                if case let .mileage(mileage) = $0 { return mileage } else { return nil }
            }).first else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Failed to decode the 'mileage' measurement"
                ))
            }
            self.mileage = mileage

            // Extract tire pressure (optional, not all vehicles have TPMS)
            self.tirePressure = measurements.compactMap({
                if case let .tirePressure(tires) = $0 { return tires } else { return nil }
            }).first
        }
        
        enum Measurement: Decodable {
            case mileage(Mileage)
            case tirePressure(Tires)
            case unknown
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let key = try container.decode(String.self, forKey: .key)

                switch key {
                case VehicleMeasurement.mileage.rawValue:
                    let mileage = try container.decode(Mileage.self, forKey: .value)
                    self = .mileage(mileage)
                case VehicleMeasurement.tirePressure.rawValue:
                    // Only decode if value exists (it won't exist if status.isEnabled = false)
                    if container.contains(.value) {
                        let tires = try container.decode(Tires.self, forKey: .value)
                        self = .tirePressure(tires)
                    } else {
                        self = .unknown
                    }
                default: self = .unknown
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case key
                case value
            }
        }
    }
    
    struct Mileage: Decodable {
        public let kilometers: Int
    }
}
