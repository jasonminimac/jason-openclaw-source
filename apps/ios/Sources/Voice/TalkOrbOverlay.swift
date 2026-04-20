import SwiftUI

struct TalkOrbOverlay: View {
    @Environment(NodeAppModel.self) private var appModel
    @State private var pulse: Bool = false
    @State private var textInput: String = ""
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        let seam = self.appModel.seamColor
        let status = self.appModel.talkMode.statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        let mic = min(max(self.appModel.talkMode.micLevel, 0), 1)

        VStack(spacing: 14) {
            // ── Orb ──────────────────────────────────────────────────────────
            ZStack {
                Circle()
                    .stroke(seam.opacity(0.26), lineWidth: 2)
                    .frame(width: 320, height: 320)
                    .scaleEffect(self.pulse ? 1.15 : 0.96)
                    .opacity(self.pulse ? 0.0 : 1.0)
                    .animation(.easeOut(duration: 1.3).repeatForever(autoreverses: false), value: self.pulse)

                Circle()
                    .stroke(seam.opacity(0.18), lineWidth: 2)
                    .frame(width: 320, height: 320)
                    .scaleEffect(self.pulse ? 1.45 : 1.02)
                    .opacity(self.pulse ? 0.0 : 0.9)
                    .animation(.easeOut(duration: 1.9).repeatForever(autoreverses: false).delay(0.2), value: self.pulse)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                seam.opacity(0.75 + (0.20 * mic)),
                                seam.opacity(0.40),
                                Color.black.opacity(0.55),
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: 112))
                    .frame(width: 190, height: 190)
                    .scaleEffect(1.0 + (0.12 * mic))
                    .overlay(
                        Circle()
                            .stroke(seam.opacity(0.35), lineWidth: 1))
                    .shadow(color: seam.opacity(0.32), radius: 26, x: 0, y: 0)
                    .shadow(color: Color.black.opacity(0.50), radius: 22, x: 0, y: 10)
            }
            .contentShape(Circle())
            .onTapGesture {
                self.appModel.talkMode.userTappedOrb()
            }

            let agentName = self.appModel.activeAgentName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !agentName.isEmpty {
                Text("Bot: \(agentName)")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.70))
            }

            if !status.isEmpty, status != "Off" {
                Text(status)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.40))
                            .overlay(
                                Capsule().stroke(seam.opacity(0.22), lineWidth: 1)))
            }

            if self.appModel.talkMode.isListening {
                Capsule()
                    .fill(seam.opacity(0.90))
                    .frame(width: max(18, 180 * mic), height: 6)
                    .animation(.easeOut(duration: 0.12), value: mic)
                    .accessibilityLabel("Microphone level")
            }

            // ── Transcript panel ──────────────────────────────────────────────
            let entries = self.appModel.talkMode.transcriptEntries
            if !entries.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(entries) { entry in
                                TalkTranscriptEntryView(entry: entry, seam: seam)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .frame(maxHeight: 260)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.40))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(seam.opacity(0.18), lineWidth: 1)))
                    .padding(.horizontal, 24)
                    .onChange(of: entries.count) { _, _ in
                        if let last = entries.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
            }

            // ── Text input bar ────────────────────────────────────────────────
            HStack(spacing: 10) {
                TextField("Type a message…", text: self.$textInput, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.white)
                    .tint(seam)
                    .focused(self.$textFieldFocused)
                    .onSubmit { self.submitText() }
                    .submitLabel(.send)

                Button(action: self.submitText) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            self.textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.white.opacity(0.25)
                                : seam)
                }
                .disabled(self.textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(seam.opacity(self.textFieldFocused ? 0.55 : 0.22), lineWidth: 1)))
            .padding(.horizontal, 24)
        }
        .padding(28)
        .onAppear {
            self.pulse = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Talk Mode \(status)")
    }

    private func submitText() {
        let trimmed = self.textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.textInput = ""
        self.textFieldFocused = false
        self.appModel.talkMode.sendTextMessage(trimmed)
    }
}

// MARK: - Transcript entry view

private struct TalkTranscriptEntryView: View {
    let entry: TalkTranscriptEntry
    let seam: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User utterance
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.top, 2)
                Text(self.entry.userText)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .multilineTextAlignment(.leading)
            }

            // Assistant response — rendered with native markdown
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(self.seam.opacity(0.70))
                        .frame(width: 6, height: 6)
                    Text("Response")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(self.seam.opacity(0.80))
                }
                TalkMarkdownText(text: self.entry.assistantText, seam: self.seam)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06)))
        }
    }
}

// MARK: - Inline markdown renderer

/// Renders assistant text with SwiftUI's native AttributedString markdown parser.
/// Handles bold, italic, inline code, and bullets. Tables and complex HTML are shown as plain text.
private struct TalkMarkdownText: View {
    let text: String
    let seam: Color

    var body: some View {
        let attributed = (try? AttributedString(
            markdown: self.text,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(self.text)
        Text(attributed)
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.90))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
