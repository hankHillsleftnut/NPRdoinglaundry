//
//  RFoundationGallery.swift
//  M14 step 1 proof: every type role and surface tier, light and dark, to compare side by side
//  with the Paper token sheet before any component is built.
//
import SwiftUI

struct RFoundationGallery: View {
    private let roles: [(String, RTextStyle)] = [
        ("inkTitle", .inkTitle), ("inkCard", .inkCard), ("displayTitle", .displayTitle),
        ("bodyReading", .bodyReading), ("body", .body), ("bodyMedium", .bodyMedium),
        ("textMd", .textMd), ("label", .label), ("labelMedium", .labelMedium),
        ("pill", .pill), ("tab", .tab), ("figure", .figure),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RDimension.space8) {
                VStack(alignment: .leading, spacing: RDimension.space3) {
                    ForEach(roles, id: \.0) { name, style in
                        VStack(alignment: .leading, spacing: RDimension.space1) {
                            Text(name).rText(.label).foregroundStyle(RColor.textLabel)
                            Text("what should retro read?").rText(style).foregroundStyle(RColor.textPrimary)
                        }
                    }
                }
                VStack(spacing: RDimension.space4) {
                    Text("wash").rText(.pill).padding(.horizontal, RDimension.space3).frame(height: 32).rWash()
                    Text("sunken").rText(.body).foregroundStyle(RColor.textTertiary).frame(maxWidth: .infinity, minHeight: 48).rSunken()
                    Text("raised").rText(.bodyMedium).frame(maxWidth: .infinity, minHeight: 64).rRaised()
                    Text("connect").rText(.pill).padding(.horizontal, RDimension.space3).frame(height: 32).rSecondary()
                    Text("continue").rText(.buttonLabel).frame(maxWidth: .infinity, minHeight: RDimension.sizeControlHero).rLit()
                }
                .foregroundStyle(RColor.textPrimary)
            }
            .padding(.horizontal, RDimension.spaceScreenMargin)
            .padding(.vertical, RDimension.space8)
        }
        .background(RColor.backgroundCanvas)
    }
}

#Preview("light") { RFoundationGallery().preferredColorScheme(.light) }
#Preview("dark (later: light ships first)") { RFoundationGallery().preferredColorScheme(.dark) }
