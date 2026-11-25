import AppKit
import SwiftUI

/// Conversation for changing (or asking about) the examining standards (the skill). Every change is versioned and can be undone.
struct SkillView: View {
    @Environment(AppModel.self) private var model

    static let suggestions = [
        "Be stricter about reproducibility: penalise missing code or data release in (c) and (d).",
        "Add a house rule: always ask one viva question about ethics and data protection.",
        "How is a PhD thesis marked differently from an MSc dissertation?",
        "What is checked in astronomy and physics theses?",
    ]

    var body: some View {
        @Bindable var model = model
        let chat = model.skillChat
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if (chat?.messages ?? []).isEmpty {
                            Intro()
                        }
                        ForEach(chat?.messages ?? []) { m in
                            MessageView(message: m).id(m.id)
                        }
                        if chat?.running == true || model.skillSending {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text(chat?.status.isEmpty == false ? chat!.status : "Thinking…").foregroundStyle(.secondary)
                            }
                            .padding(.leading, 38)
                            .id("working")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(24)
                    .frame(maxWidth: 780)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: chat?.messages.count) { withAnimation { proxy.scrollTo("bottom") } }
                .onChange(of: chat?.running) { withAnimation { proxy.scrollTo("bottom") } }
                .onAppear { proxy.scrollTo("bottom") }
            }
            Divider()
            Composer()
        }
        .navigationTitle("Examining Standards")
        .navigationSubtitle("How dissertations are examined, in plain words")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    if model.skillHistory.isEmpty { Text("No changes yet") }
                    ForEach(model.skillHistory) { c in
                        Menu("\(c.date)  ·  \(c.message.replacingOccurrences(of: "Skill: ", with: ""))") {
                            Button("Undo This Change") { Task { await model.undoSkillChange(c.commit) } }
                                .disabled(c.undoable == false)
                        }
                    }
                    Divider()
                    Button("Show in Finder") { NSWorkspace.shared.open(model.backend.skillDir) }
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .help("Every change to your standards, with undo")
                Button { Task { await model.newSkillConversation() } } label: {
                    Label("New Conversation", systemImage: "square.and.pencil")
                }
                .help("Start a fresh conversation (your standards keep their changes)")
                .disabled(model.skillBusy)
            }
        }
    }
}

private struct Intro: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 30)).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Teach the Examiner").font(.title2.weight(.semibold))
                    Text("Describe how you want dissertations examined. Every future examination follows your standards.")
                        .foregroundStyle(.secondary)
                }
            }
            Text("Every change is saved as a version you can review and undo from History. Changes that would stop the app working are undone automatically.")
                .font(.callout).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(SkillView.suggestions, id: \.self) { s in
                    Button { Task { await model.sendSkillMessage(s) } } label: {
                        HStack {
                            Image(systemName: "text.bubble").foregroundStyle(.tint)
                            Text(s).multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(.background.secondary, in: .rect(cornerRadius: 9))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.skillBusy)
                }
            }
        }
        .padding(.bottom, 8)
    }
}

private struct MessageView: View {
    @Environment(AppModel.self) private var model
    let message: SkillMessage

    var body: some View {
        switch message.role {
        case "user":
            HStack {
                Spacer(minLength: 80)
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: .rect(cornerRadius: 14))
            }
        case "system":
            Label(message.text, systemImage: "arrow.uturn.backward.circle")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        default:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: message.error == true ? "exclamationmark.triangle.fill" : "graduationcap.fill")
                    .foregroundStyle(message.error == true ? Color.orange : Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(.background.secondary, in: .circle)
                VStack(alignment: .leading, spacing: 10) {
                    if message.text.isEmpty {
                        Text("Working…").foregroundStyle(.secondary)
                    } else {
                        Text(Self.markdown(message.text)).textSelection(.enabled)
                    }
                    if let files = message.files, !files.isEmpty, let commit = message.commit {
                        ChangeCard(files: files, commit: commit, diff: message.diff ?? "")
                    }
                }
                Spacer(minLength: 40)
            }
        }
    }

    static func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
    }
}

private struct ChangeCard: View {
    @Environment(AppModel.self) private var model
    let files: [String]
    let commit: String
    let diff: String
    @SwiftUI.Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Updated \(files.map { ($0 as NSString).lastPathComponent }.joined(separator: ", "))", systemImage: "checkmark.seal.fill")
                    .font(.callout).foregroundStyle(.green)
                Spacer()
                Button("Undo") { Task { await model.undoSkillChange(commit) } }
                    .controlSize(.small)
                    .help("Put your standards back the way they were before this change")
            }
            DisclosureGroup("Show changes") {
                ScrollView([.vertical, .horizontal]) {
                    Text(Self.colored(diff))
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 260)
                .background(.background, in: .rect(cornerRadius: 6))
            }
            .font(.callout)
        }
        .padding(12)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }

    static func colored(_ diff: String) -> AttributedString {
        var out = AttributedString()
        for raw in diff.split(separator: "\n", omittingEmptySubsequences: false).prefix(600) {
            let line = String(raw)
            if line.hasPrefix("diff --git") || line.hasPrefix("index ") || line.hasPrefix("--- ") || line.hasPrefix("+++ ") {
                if line.hasPrefix("+++ ") {
                    var a = AttributedString("\n" + line.replacingOccurrences(of: "+++ b/", with: "") + "\n")
                    a.font = .system(size: 11, weight: .bold, design: .monospaced)
                    out += a
                }
                continue
            }
            var a = AttributedString(line + "\n")
            if line.hasPrefix("+") { a.foregroundColor = .green }
            else if line.hasPrefix("-") { a.foregroundColor = .red }
            else if line.hasPrefix("@@") { a.foregroundColor = .secondary }
            out += a
        }
        return out
    }
}

private struct Composer: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message", text: $model.skillInput,
                      prompt: Text("Describe a change, or ask how dissertations are examined…"), axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(.background, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
                .disabled(model.skillBusy)
            if model.skillChat?.running == true {
                Button { Task { await model.stopSkill() } } label: {
                    Image(systemName: "stop.circle.fill").font(.system(size: 26))
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Stop (nothing is changed)")
            } else {
                Button { Task { await model.sendSkillMessage() } } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 26))
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.skillInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.skillInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.skillBusy)
                .help("Send (⌘↩)")
            }
        }
        .padding(14)
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }
}
