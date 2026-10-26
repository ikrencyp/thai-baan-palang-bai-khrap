import AppKit
import SwiftUI

struct WhatsNewView: View {
    static let size = NSSize(width: 460, height: 540)

    @State private var pager: ReleasePager
    let current: String
    let showMenu: (String) -> Void

    init(releases: [Release], current: String, showMenu: @escaping (String) -> Void = { _ in }) {
        _pager = State(initialValue: ReleasePager(releases: releases))
        self.current = current
        self.showMenu = showMenu
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView { pageContent }
            if pager.pageCount > 1 {
                Divider()
                footer
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    var pageContent: some View {
        VStack(spacing: 14) {
            if pager.releases.isEmpty {
                Text("The list of changes is not inside this copy of the app.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(pager.current, id: \.version) { release in card(release) }
        }
        .padding(20)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("What\u{2019}s new").font(.title2.weight(.semibold))
                Text("You are on version \(current)").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    private var footer: some View {
        HStack {
            Button { pager.showNewer() } label: { Label("Newer", systemImage: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(!pager.hasNewer)
                .frame(width: 90, alignment: .leading)
            Spacer()
            Text(pager.caption).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { pager.showOlder() } label: { Label("Older", systemImage: "chevron.right").labelStyle(TrailingIconLabelStyle()) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(!pager.hasOlder)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private func card(_ release: Release) -> some View {
        let isCurrent = AppVersion(release.version) == AppVersion(current)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(release.version).font(.title3.weight(.semibold))
                if isCurrent {
                    Text("You have this").font(.caption.weight(.semibold)).foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(release.lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\u{2022}").foregroundStyle(Color.accentColor)
                        Text(line).font(.callout).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            if let findIt = release.findIt { findItRow(findIt) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(isCurrent ? Color.accentColor.opacity(0.07) : Color.primary.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isCurrent ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1))
    }

    // The short tour of a release: where its new thing sits in the menu, and a button that opens the menu with the way marked.
    private func findItRow(_ path: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.accentColor).frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text("WHERE TO FIND IT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(path.components(separatedBy: " > ").joined(separator: "  \u{203A}  "))
                    .font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Show me where") { showMenu(path) }
                .controlSize(.small)
                .help("Opens the menu with a tag on each step of the way")
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.1)))
    }
}
