import AppKit
import SwiftUI

struct HelpView: View {
    // The page shows the colours the person picked, not a fixed green and red.
    private let charger = LeafColor.stored(.charger)
    private let battery = LeafColor.stored(.battery)
    var body: some View {
        ScrollView { content }
            .frame(width: 480, height: 600)
    }

    var content: some View {
            VStack(alignment: .leading, spacing: 22) {
                section("The leaf in the menu bar") {
                    // The same drawing the menu bar uses, so what you read here is what you see up there.
                    HStack(spacing: 12) {
                        Image(nsImage: LeafGlyph.image(fill: 0, scale: 1, alpha: 1, tint: nil))
                            .renderingMode(.template).foregroundStyle(Color.secondary).frame(width: 26)
                        text("Outline leaf", "Normal sleep. Nothing is held.")
                    }
                    legend(charger.nsColor, "Leaf in a golden flame, beating",
                           "Awake and charging. The lid can close. It shows your On the charger colour (\(charger.name)) and lights up with a flash when you turn it on.")
                    legend(battery.nsColor, "Leaf on battery",
                           "Awake and not charging, or alerting. It shows your On battery colour (\(battery.name)) for as long as the Mac runs on battery.")
                    HStack(spacing: 12) {
                        Image(nsImage: LeafGlyph.failureImage() ?? NSImage())
                            .renderingMode(.template).foregroundStyle(Color.primary).frame(width: 26)
                        text("Triangle", "The last change failed. Open the menu to see why.")
                    }
                }
                section("Quick start") {
                    ForEach(Array(HelpTopic.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(index + 1)").font(.callout.weight(.semibold)).foregroundStyle(.secondary).frame(width: 18)
                            Text(step).font(.callout)
                        }
                    }
                }
                section("Every menu item") {
                    ForEach(HelpTopic.menu) { topic in card(topic) }
                }
            }
            .padding(24)
            .frame(width: 480, alignment: .leading)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func legend(_ color: NSColor, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: color, glow: 0.8, glowColor: StatusIconAnimator.powerGold)).frame(width: 26)
            text(title, detail)
        }
    }

    @ViewBuilder
    private func icon(_ symbol: String) -> some View {
        if symbol == HelpTopic.leafSymbol {
            Image(nsImage: LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: charger.nsColor, glow: 0.8,
                                         glowColor: StatusIconAnimator.powerGold)).frame(width: 26)
        } else {
            Image(systemName: symbol).font(.title3).foregroundStyle(Color(nsColor: StatusIconAnimator.powerGold)).frame(width: 26)
        }
    }

    private func text(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.callout.weight(.semibold))
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func card(_ topic: HelpTopic) -> some View {
        HStack(alignment: .top, spacing: 12) {
            icon(topic.symbol)
            VStack(alignment: .leading, spacing: 3) {
                Text(topic.title).font(.callout.weight(.semibold))
                Text(topic.summary).font(.callout)
                Text(topic.detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }
}
