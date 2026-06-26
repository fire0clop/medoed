// Utils/Constants.swift

import Foundation
import SwiftUI

enum Constants {
    static let baseURL = URL(string: "https://your-backend-host.example.com")!
}

// MARK: - Mulish шрифты

extension Font {
    static func gilroy(_ size: CGFloat, weight: Gilroy = .regular) -> Font {
        Font.custom(weight.fontName, size: size * deviceScale)
    }

    enum Gilroy {
        case regular, medium, semibold, bold

        var fontName: String {
            switch self {
            case .regular: return "Mulish-Regular"
            case .medium: return "Mulish-Medium"
            case .semibold: return "Mulish-SemiBold"
            case .bold: return "Mulish-Bold"
            }
        }
    }
}
