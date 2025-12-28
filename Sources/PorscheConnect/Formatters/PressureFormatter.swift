import Foundation

/// A formatter that converts Pressure values into their textual representations.
///
/// All properties will be formatted based on the provided locale.
public final class PressureFormatter {

  public init() {
  }

  /// The locale to use for all textual representations.
  public var locale: Locale = .current

  /// Returns a textual representation of a pressure value.
  public func string(from pressure: Pressure) -> String {
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 1
    formatter.maximumFractionDigits = 2

    guard let formattedValue = formatter.string(from: pressure.value as NSNumber) else {
      return ""
    }

    let unitString = pressure.unit == .bar ? "bar" : "psi"
    return "\(formattedValue) \(unitString)"
  }

  /// Returns a textual representation for optional pressure.
  public func string(from pressure: Pressure?) -> String {
    guard let pressure = pressure else {
      return "--"
    }
    return string(from: pressure)
  }
}
