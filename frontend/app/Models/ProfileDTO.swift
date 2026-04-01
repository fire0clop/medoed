// Models/ProfileDTO.swift

import Foundation

struct ProfileDTO: Codable {
    var email: String?
    var target_glucose_mmol: Double
    var insulin_sensitivity_factor: Double
    var ic_ratio_breakfast: Double
    var ic_ratio_lunch: Double
    var ic_ratio_dinner: Double
}
