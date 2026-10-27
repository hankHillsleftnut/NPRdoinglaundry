//
//  AnimationPreviewView.swift
//  Retrospect
//
//  Full-screen, black, vertically-scrollable cards — one animation per screen,
//  so each variation can be looked through on its own.
//

import SwiftUI

struct AnimationVariant: Identifiable {
    let id = UUID()
    let name: String
    let blurb: String
    let fragmentName: String
}

enum FluidVariants {
    static let all: [AnimationVariant] = [
        .init(
            name: "Fluid Dots",
            blurb: "A ring of metaball dots — the original",
            fragmentName: "fluidDotsFragment"
        ),
        .init(
            name: "Orbit",
            blurb: "A nucleus with electrons on pulsing orbits",
            fragmentName: "variantOrbitFragment"
        ),
        .init(
            name: "Spiral",
            blurb: "Dots tracing a slowly rotating spiral arm",
            fragmentName: "variantSpiralFragment"
        ),
        .init(
            name: "Lava",
            blurb: "Blobs drifting and merging, lava-lamp style",
            fragmentName: "variantLavaFragment"
        ),
        .init(
            name: "Mercury",
            blurb: "Droplets coalescing like liquid metal",
            fragmentName: "variantMercuryFragment"
        ),
        .init(
            name: "Wave",
            blurb: "A thick, playful flowing waveform",
            fragmentName: "variantWaveFragment"
        ),
        .init(
            name: "Ribbon",
            blurb: "Two ribbons weaving past each other",
            fragmentName: "variantRibbonFragment"
        ),
        .init(
            name: "Swarm",
            blurb: "Fireflies gathering and dispersing",
            fragmentName: "variantSwarmFragment"
        ),
        .init(
            name: "Burst",
            blurb: "A ring of dots breathing outward and back",
            fragmentName: "variantBurstFragment"
        ),
    ]
}

struct AnimationPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    private let variants = FluidVariants.all

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(variants) { variant in
                        AnimationCard(variant: variant)
                            .containerRelativeFrame([.horizontal, .vertical])
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .ignoresSafeArea()

            Button {
                HapticManager.shared.playLightImpact()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 20)
            .padding(.top, 16)
        }
    }
}

private struct AnimationCard: View {
    let variant: AnimationVariant

    var body: some View {
        ZStack {
            Color.black

            FluidDotsView(fragmentName: variant.fragmentName)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Text(variant.name)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                Text(variant.blurb)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 80)
        }
    }
}

#if DEBUG
/// Verification-only grid that renders every variation at once (used by the
/// `-AnimationPreview` launch flag to screenshot them all in one shot).
struct AnimationVariantGrid: View {
    private let variants = FluidVariants.all
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(variants) { variant in
                        VStack(spacing: 6) {
                            FluidDotsView(fragmentName: variant.fragmentName)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            Text(variant.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}
#endif
