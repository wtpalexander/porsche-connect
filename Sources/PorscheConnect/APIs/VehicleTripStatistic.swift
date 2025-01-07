//
//  VehicleTripStatistic.swift
//  PorscheConnect
//
//  Created by William Alexander on 07/01/2025.
//

enum VehicleTripStatistic: String, CaseIterable {
    case cyclic = "TRIP_STATISTICS_CYCLIC"
    case longTerm = "TRIP_STATISTICS_LONG_TERM"
    case longTermHistory = "TRIP_STATISTICS_LONG_TERM_HISTORY"
    case shortTermHistory = "TRIP_STATISTICS_SHORT_TERM_HISTORY"
    case cyclicHistory = "TRIP_STATISTICS_CYCLIC_HISTORY"
    case shortTerm = "TRIP_STATISTICS_SHORT_TERM"
}
