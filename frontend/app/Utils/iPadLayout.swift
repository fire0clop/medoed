// Utils/iPadLayout.swift
import SwiftUI

// MARK: - Scale factor

/// 1.5x scale on iPad relative to iPhone. iPhone always 1.0.
let deviceScale: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 1.5 : 1.0

/// Scales a size (icon, padding, cornerRadius) proportionally for iPad.
func ds(_ size: CGFloat) -> CGFloat { size * deviceScale }

// MARK: - Width constraint

private let iPadContentMaxWidth: CGFloat = 740

extension View {
    /// Constrains content width on iPad with side margins and centers it. No-op on iPhone.
    @ViewBuilder
    func ipadReadable() -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self
                .frame(maxWidth: iPadContentMaxWidth)
                .frame(maxWidth: .infinity)
        } else {
            self
        }
    }
}
