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
      let formatter = PressureFormatter()

      print(NSLocalizedString("\nTire Pressures:", comment: kBlankString))
      print(NSLocalizedString(
        "  Front Left:  Current: \(formatter.string(from: tires.frontLeft.currentPressure)), Optimal: \(formatter.string(from: tires.frontLeft.optimalPressure))",
        comment: kBlankString))
      print(NSLocalizedString(
        "  Front Right: Current: \(formatter.string(from: tires.frontRight.currentPressure)), Optimal: \(formatter.string(from: tires.frontRight.optimalPressure))",
        comment: kBlankString))
      print(NSLocalizedString(
        "  Rear Left:   Current: \(formatter.string(from: tires.backLeft.currentPressure)), Optimal: \(formatter.string(from: tires.backLeft.optimalPressure))",
        comment: kBlankString))
      print(NSLocalizedString(
        "  Rear Right:  Current: \(formatter.string(from: tires.backRight.currentPressure)), Optimal: \(formatter.string(from: tires.backRight.optimalPressure))",
        comment: kBlankString))
    }
  }
}
