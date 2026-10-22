//
//  RArtwork.swift
//  M14 S14 + S06: episode artwork (principles/gradients.md). A base colour and a few
//  points; each point pulls the colour toward itself with a soft falloff, mixed in OKLab
//  (the mesh look of mmeshy, chosen by the founder 21 Oct), with grain drawn in the same
//  pass (RArtwork.metal). Recipes are generated from gradient.mesh* into RArtworkRecipes;
//  corner radius is radius.artworkRatio of the size.
//
import simd
import SwiftUI

public struct RArtworkRecipe {
    public struct Blob {
        public let color: Color
        /// Centre, as a share of the width and height.
        public let x: Double
        public let y: Double
        /// How far the point reaches, as a share of the longer side.
        public let radius: Double
        /// How strongly the point pulls the colour toward itself at its centre (0–1).
        public let weight: Double

        public init(color: Color, x: Double, y: Double, radius: Double, weight: Double) {
            self.color = color
            self.x = x
            self.y = y
            self.radius = radius
            self.weight = weight
        }
    }

    /// mono: one grain for all channels. multi: a separate grain per channel (coloured).
    public enum GrainMode { case mono, multi }

    public struct Grain {
        public let mode: GrainMode
        /// Soft-light strength (gradients.md rule 4: 3–6% on artwork).
        public let opacity: Double
        /// Grain cell in device pixels.
        public let size: Double

        public init(mode: GrainMode, opacity: Double, size: Double) {
            self.mode = mode
            self.opacity = opacity
            self.size = size
        }
    }

    public let base: Color
    public let blobs: [Blob]
    /// 0–1; widens every point's falloff.
    public let softness: Double
    public let grain: Grain
    /// The points and base in OKLab, worked out once for the shader.
    let shaderPoints: [Float]
    let shaderBase: SIMD3<Float>

    public init(base: Color, blobs: [Blob], softness: Double, grain: Grain) {
        self.base = base
        self.blobs = blobs
        self.softness = softness
        self.grain = grain
        shaderPoints = blobs.flatMap { blob -> [Float] in
            let lab = Self.oklab(blob.color)
            return [Float(blob.x), Float(blob.y), Float(blob.radius), Float(blob.weight), lab.x, lab.y, lab.z]
        }
        shaderBase = Self.oklab(base)
    }

    /// Linear sRGB to OKLab (Björn Ottosson's matrices).
    private static func oklab(_ color: Color) -> SIMD3<Float> {
        let resolved: Color.Resolved = color.resolve(in: EnvironmentValues())
        let linear = SIMD3<Float>(resolved.linearRed, resolved.linearGreen, resolved.linearBlue)
        let lms = lmsFromLinear * linear
        return labFromLMS * SIMD3<Float>(cbrtf(lms.x), cbrtf(lms.y), cbrtf(lms.z))
    }

    private static let lmsFromLinear = simd_float3x3(rows: [
        SIMD3<Float>(0.4122214708, 0.5363325363, 0.0514459929), // literal-ok: OKLab matrix
        SIMD3<Float>(0.2119034982, 0.6806995451, 0.1073969566), // literal-ok: OKLab matrix
        SIMD3<Float>(0.0883024619, 0.2817188376, 0.6299787005), // literal-ok: OKLab matrix
    ])

    private static let labFromLMS = simd_float3x3(rows: [
        SIMD3<Float>(0.2104542553, 0.7936177850, -0.0040720468), // literal-ok: OKLab matrix
        SIMD3<Float>(1.9779984951, -2.4285922050, 0.4505937099), // literal-ok: OKLab matrix
        SIMD3<Float>(0.0259040371, 0.7827717662, -0.8086757660), // literal-ok: OKLab matrix
    ])
}

/// Episode artwork at any size.
struct RArtwork: View {
    let recipe: RArtworkRecipe
    var size: CGFloat = RDimension.sizeArtworkRow
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .frame(width: size, height: size)
            .colorEffect(ShaderLibrary.rArtworkMesh(
                .float2(size, size),
                .floatArray(recipe.shaderPoints),
                .float3(recipe.shaderBase.x, recipe.shaderBase.y, recipe.shaderBase.z),
                .float(recipe.softness),
                .float(recipe.grain.opacity),
                .float(recipe.grain.mode == .mono ? 0 : 1),
                .float(recipe.grain.size / displayScale)
            ))
            .clipShape(RShape.rect(size * RNumber.radiusArtworkRatio))
            .accessibilityHidden(true)
    }
}

#if DEBUG
/// Every recipe at hero size and at row size, for the lab's artwork page.
struct RArtworkLab: View {
    private let recipes: [(String, RArtworkRecipe)] = [
        ("morning", RArtworkRecipes.morning), ("evening", RArtworkRecipes.evening),
        ("quiet", RArtworkRecipes.quiet), ("weekly", RArtworkRecipes.weekly),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space6) {
                ForEach(recipes, id: \.0) { name, recipe in
                    VStack(alignment: .leading, spacing: RDimension.space2) {
                        Text(name).rText(.label).foregroundStyle(RColor.textSecondary)
                        HStack(alignment: .bottom, spacing: RDimension.space3) {
                            RArtwork(recipe: recipe, size: RDimension.sizeArtworkHero)
                            RArtwork(recipe: recipe)
                        }
                    }
                }
            }
            .padding(RDimension.spaceScreenMargin)
        }
    }
}

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
