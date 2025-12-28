import Foundation

/// The status of all tires on the vehicle.
public struct Tires: Codable {
  public let frontLeftTire: Tire
  public let frontRightTire: Tire
  public let rearLeftTire: Tire
  public let rearRightTire: Tire
}

/// The status of a single tire on the vehicle.
public struct Tire: Codable {
  /// Difference from optimal pressure in bar
  public let differenceBar: Double

  /// Actual pressure in bar
  public let actualPressureBar: Double
}
