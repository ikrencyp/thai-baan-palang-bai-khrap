import AppKit
import SwiftUI

struct HelpView: View {
    static let size = NSSize(width: 520, height: 660)

    // The page shows the colours the person picked, not a fixed green and red.
    private let charger = LeafColor.stored(.charger)
    private let battery = LeafColor.stored(.battery)
    private var accent: Color { Color(nsColor: charger.nsColor) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView { pageContent }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    var pageContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            section("Quick start") { quickStart }
            section("The leaf in the menu bar") { leafLegend }
            section("Every menu item") {
                VStack(spacing: 10) { ForEach(HelpTopic.menu) { topic in card(topic) } }
            }
        }
        .padding(24)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: charger.nsColor, glow: 0.8,
                                           glowColor: StatusIconAnimator.powerGold))
                .frame(width: 26)
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text("How to use").font(.title2.weight(.semibold))
                Text("Keep this Mac working with the lid shut or the screen locked.").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    private var quickStart: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(HelpTopic.steps.enumerated()), id: \.offset) { index, step in
                if index > 0 { Divider().padding(.leading, 52).padding(.trailing, 14) }
                HStack(alignment: .center, spacing: 14) {
                    Text("\(index + 1)").font(.callout.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 26, height: 26).background(Circle().fill(accent))
                    Text(step).font(.callout).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10).padding(.horizontal, 14)
            }
        }
        .background(panel)
    }

    private var leafLegend: some View {
        VStack(alignment: .leading, spacing: 0) {
            legendRow(Image(nsImage: LeafGlyph.image(fill: 0, scale: 1, alpha: 1, tint: nil)).renderingMode(.template)
                .foregroundStyle(Color.secondary),
                      "Outline leaf", "Normal sleep. Nothing is held.")
            Divider().padding(.leading, 52).padding(.trailing, 14)
            legendRow(Image(nsImage: flameLeaf(charger.nsColor)),
                      "Leaf in a golden flame, beating",
                      "Awake and charging, so the lid can close. It shows your On the charger colour (\(charger.name)) and flashes when you turn it on.")
            Divider().padding(.leading, 52).padding(.trailing, 14)
            legendRow(Image(nsImage: flameLeaf(battery.nsColor)),
                      "Leaf on battery",
                      "Awake and not charging, or alerting. It shows your On battery colour (\(battery.name)) for as long as the Mac runs on battery.")
            Divider().padding(.leading, 52).padding(.trailing, 14)
            legendRow(Image(nsImage: LeafGlyph.failureImage() ?? NSImage()).renderingMode(.template).foregroundStyle(Color.primary),
                      "Triangle", "The last change failed. Open the menu to see why.")
        }
        .background(panel)
    }

    private func flameLeaf(_ color: NSColor) -> NSImage {
        LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: color, glow: 0.8, glowColor: StatusIconAnimator.powerGold)
    }

    private func legendRow(_ image: some View, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            image.frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 2)
            content()
        }
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
    }

    @ViewBuilder
    private func icon(_ symbol: String) -> some View {
        Group {
            if symbol == HelpTopic.leafSymbol {
                Image(nsImage: flameLeaf(charger.nsColor))
            } else {
                Image(systemName: symbol).font(.title3).foregroundStyle(Color(nsColor: StatusIconAnimator.powerGold))
            }
        }
        .frame(width: 26, height: 26)
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.06)))
    }

    private func card(_ topic: HelpTopic) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon(topic.symbol)
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title).font(.callout.weight(.semibold))
                Text(topic.summary).font(.callout).fixedSize(horizontal: false, vertical: true)
                Text(topic.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel)
    }
}
