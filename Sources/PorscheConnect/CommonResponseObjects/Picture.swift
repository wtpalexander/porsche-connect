import Foundation

public struct Picture: Codable {
    
    public let url: URL
    public let view: CameraView
    public let size: Int
    
    public init(
        url: URL,
        view: CameraView,
        size: Int
    ) {
        self.url = url
        self.view = view
        self.size = size
    }
}

extension Picture {
    
    public enum CameraView: String, Codable {
        case frontView
        case sideView
        case rearView
        case rearTopView
        case topView
        case unknown
        
        public init(from decoder: Decoder) throws {
            self = try CameraView(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
        }
    }
}
