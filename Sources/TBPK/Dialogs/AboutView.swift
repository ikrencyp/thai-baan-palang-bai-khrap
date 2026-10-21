import AppKit
import SwiftUI

struct AboutView: View {
    var showHelp: () -> Void
    var showWhatsNew: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 4) {
                Text(AppInfo.name).font(.title2.weight(.semibold))
                Text("Version \(AppInfo.version)").font(.callout).foregroundStyle(.secondary)
            }
            Text("Keeps this Mac awake with the lid closed, and tells you when it is left running.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("How to use", action: showHelp)
                Button("What\u{2019}s new", action: showWhatsNew)
                Button("Copy version") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(AppInfo.versionLine), macOS \(ProcessInfo.processInfo.operatingSystemVersionString)", forType: .string)
                }
            }
            Text("Developed by Meshikuto\nChaiyapong Jantarakanyabun")
                .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 340)
    }
}
