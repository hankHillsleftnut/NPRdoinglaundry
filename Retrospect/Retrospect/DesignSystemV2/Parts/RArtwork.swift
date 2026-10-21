//
//  RArtwork.swift
//  M14 S14 + S06: episode artwork and grain (principles/gradients.md). Artwork is a
//  base colour with soft blobs that fade in alpha (never a hue ramp), eased over five
//  stops, plus grain in soft light. Recipes are generated from gradient.mesh* into
//  RArtworkRecipes; corner radius is radius.artworkRatio of the size.
//
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

public struct RArtworkRecipe {
    public struct Blob {
        public let color: Color
        /// Centre, as a share of the width and height.
        public let x: Double
        public let y: Double
        /// Radius, as a share of the longer side.
        public let radius: Double
        /// Opacity at the centre; it eases to 0 at the radius.
        public let alpha: Double

        public init(color: Color, x: Double, y: Double, radius: Double, alpha: Double) {
            self.color = color
            self.x = x
            self.y = y
            self.radius = radius
            self.alpha = alpha
        }
    }

    public let base: Color
    public let blobs: [Blob]
    /// Grain opacity (0.05–0.06 for artwork).
    public let grain: Double

    public init(base: Color, blobs: [Blob], grain: Double) {
        self.base = base
        self.blobs = blobs
        self.grain = grain
    }
}

/// Episode artwork at any size.
struct RArtwork: View {
    let recipe: RArtworkRecipe
    var size: CGFloat = RDimension.sizeArtworkRow

    var body: some View {
        ZStack {
            recipe.base
            ForEach(recipe.blobs.indices, id: \.self) { index in
                let blob = recipe.blobs[index]
                RadialGradient(
                    stops: Self.easedStops(blob.color, alpha: blob.alpha),
                    center: UnitPoint(x: blob.x, y: blob.y),
                    startRadius: .zero,
                    endRadius: size * blob.radius
                )
            }
            RGrain(opacity: recipe.grain)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * RNumber.radiusArtworkRatio, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Five stops on a smoothstep, so the blob has no visible edge (gradients.md rule 2).
    private static func easedStops(_ color: Color, alpha: Double) -> [Gradient.Stop] {
        stride(from: 0.0, through: 1.0, by: 0.25).map { position in
            let eased = position * position * (3 - 2 * position)
            return .init(color: color.opacity(alpha * (1 - eased)), location: position)
        }
    }
}

// MARK: - S06 · Grain

/// Fractal-ish noise tiled over a surface in soft light (gradients.md rule 4: 3–6%,
/// 20% on the lit button). One small noise image is made once and tiled.
struct RGrain: View {
    let opacity: Double

    var body: some View {
        if let image = Self.noise {
            Image(uiImage: image)
                .resizable(resizingMode: .tile)
                .blendMode(.softLight)
                .opacity(opacity)
                .allowsHitTesting(false)
        }
    }

    private static let noise: UIImage? = {
        let tile = CGRect(origin: .zero, size: CGSize(width: RDimension.sizeArtworkHero, height: RDimension.sizeArtworkHero))
        let monochrome = CIFilter.colorControls()
        monochrome.inputImage = CIFilter.randomGenerator().outputImage?.cropped(to: tile)
        monochrome.saturation = .zero
        guard let output = monochrome.outputImage,
              let cgImage = CIContext().createCGImage(output, from: tile) else { return nil }
        return UIImage(cgImage: cgImage)
    }()
}

#if DEBUG
#Preview("artwork") {
    HStack(spacing: RDimension.space3) {
        RArtwork(recipe: RArtworkRecipes.morning)
        RArtwork(recipe: RArtworkRecipes.evening)
        RArtwork(recipe: RArtworkRecipes.quiet)
        RArtwork(recipe: RArtworkRecipes.weekly)
    }
    .padding(RDimension.spaceScreenMargin)
}
#endif
