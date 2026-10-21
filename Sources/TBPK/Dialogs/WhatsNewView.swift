import SwiftUI

struct WhatsNewView: View {
    @State private var pager: ReleasePager
    let current: String

    init(releases: [Release], current: String) {
        _pager = State(initialValue: ReleasePager(releases: releases))
        self.current = current
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if pager.releases.isEmpty {
                        Text("The list of changes is not inside this copy of the app.").font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(pager.current, id: \.version) { release in card(release) }
                }
                .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 12)
                .frame(width: 440, alignment: .leading)
            }
            if pager.pageCount > 1 { footer }
        }
        .frame(width: 440, height: 480)
    }

    private var footer: some View {
        HStack {
            Button { pager.showNewer() } label: { Label("Newer", systemImage: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(!pager.hasNewer)
            Spacer()
            Text(pager.caption).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button { pager.showOlder() } label: { Label("Older", systemImage: "chevron.right").labelStyle(TrailingIconLabelStyle()) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(!pager.hasOlder)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Color.primary.opacity(0.04))
    }

    private func card(_ release: Release) -> some View {
        let isCurrent = AppVersion(release.version) == AppVersion(current)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(release.version).font(.title3.weight(.semibold))
                if isCurrent {
                    Text("You have this").font(.caption.weight(.semibold)).foregroundStyle(.green)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                }
            }
            ForEach(Array(release.lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").foregroundStyle(.secondary)
                    Text(line).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(isCurrent ? 0.08 : 0.04)))
    }
}
