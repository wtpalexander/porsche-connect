import ArgumentParser
import Foundation
import PorscheConnect

extension Porsche {

  struct ShowSummary: AsyncParsableCommand {
    // MARK: - Properties

    @OptionGroup()
    var options: Options

    @Argument(help: ArgumentHelp(NSLocalizedString("Your vehicle VIN.", comment: kBlankString)))
    var vin: String

    // MARK: - Lifecycle

    func run() async throws {
      let porscheConnect = PorscheConnect(
        username: options.username,
        password: options.password,
        environment: options.resolvedEnvironment
      )
      await callSummaryService(porscheConnect: porscheConnect, vin: vin)
      dispatchMain()
    }

    // MARK: - Private functions

    private func callSummaryService(porscheConnect: PorscheConnect, vin: String) async {

      do {
        let result = try await porscheConnect.summary(vin: vin)
        if let summary = result.summary {
          printSummary(summary)
        }
        Porsche.ShowSummary.exit()
      } catch {
        Porsche.ShowSummary.exit(withError: error)
      }
    }

    private func printSummary(_ summary: Summary) {
      let output = NSLocalizedString(
        "Model Description: \(summary.vehicle.modelName))",
        comment: kBlankString)
      print(output)

      // Display tire pressures if available
      if let tires = summary.measurements.tirePressure {
        printTirePressures(tires)
      } else {
        print(NSLocalizedString(
          "\nTire pressure monitoring: Not available",
          comment: kBlankString))
      }
    }

    private func printTirePressures(_ tires: Tires) {
      print(NSLocalizedString("\nTire Pressures:", comment: kBlankString))

      func formatTire(_ tire: Tire, label: String) {
        let optimal = tire.actualPressureBar - tire.differenceBar
        let difference = tire.differenceBar >= 0 ? "+\(tire.differenceBar)" : "\(tire.differenceBar)"
        print(NSLocalizedString(
          "  \(label): \(String(format: "%.1f", tire.actualPressureBar)) bar (optimal: \(String(format: "%.1f", optimal)) bar, \(difference))",
          comment: kBlankString))
      }

      formatTire(tires.frontLeftTire, label: "Front Left ")
      formatTire(tires.frontRightTire, label: "Front Right")
      formatTire(tires.rearLeftTire, label: "Rear Left  ")
      formatTire(tires.rearRightTire, label: "Rear Right ")
    }
  }
}
