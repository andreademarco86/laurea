import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// First-run Setup Assistant: engine choice and sign-in, examiner details and signature, marking weights.
struct SetupView: View {
    @Environment(AppModel.self) private var model

    enum Step: Int, CaseIterable { case welcome, engine, profile, scheme, done }

    var body: some View {
        let step = Step(rawValue: model.setupStep) ?? .welcome
        VStack(spacing: 0) {
            StepDots(current: step.rawValue, total: Step.allCases.count)
                .padding(.top, 18)
            Group {
                switch step {
                case .welcome: WelcomeStep()
                case .engine: EngineStep()
                case .profile: ProfileStep()
                case .scheme: SchemeStep()
                case .done: DoneStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .id(step)
            Divider()
            HStack {
                if step != .welcome && step != .done {
                    Button("Back") { withAnimation { model.setupStep -= 1 } }
                }
                Spacer()
                if step == .welcome || step == .engine || step == .profile || step == .scheme {
                    if step != .welcome && model.setupCompletedBefore {
                        Button("Close") { model.showSetup = false }
                    }
                    Button(step == .welcome ? "Get Started" : "Continue") {
                        Task {
                            if step == .profile { await model.saveSettings() }
                            if step == .scheme { await model.saveSettings() }
                            withAnimation { model.setupStep += 1 }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(step == .engine && !model.activeEngineReady)
                } else {
                    Button("Start Using Laurea") { model.completeSetup() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .frame(width: 640, height: 600)
        .task { await model.loadSettings(); await model.loadEngines() }
    }
}

private struct StepDots: View {
    let current: Int
    let total: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: i == current ? 22 : 8, height: 8)
                    .animation(.spring(duration: 0.3), value: current)
            }
        }
    }
}

private struct StepHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            Text(title).font(.title.weight(.semibold))
            Text(subtitle).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 480)
        }
        .padding(.top, 22)
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            Text("Welcome to Laurea").font(.system(size: 30, weight: .bold))
            Text("A few quick steps and you're ready to examine: choose your examination engine, add your details and signature, and check the marking weights.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 440)
            Spacer()
        }
        .padding(24)
    }
}

private struct EngineStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 16) {
            StepHeader(icon: "cpu", title: "Choose Your Examination Engine",
                       subtitle: "Laurea works with your own subscription. Sign in to one or both, then choose which one examines. You can switch at any time in Settings.")
            HStack(spacing: 14) {
                ForEach(Engine.allCases) { e in EngineCard(engine: e) }
            }
            .padding(.horizontal, 28)
            if model.activeEngineReady {
                let active = model.activeEngine
                let list = model.models[active.rawValue]?.models ?? []
                if !list.isEmpty {
                    let current = model.currentModel(for: active)
                    Form {
                        Picker("Model", selection: Binding(get: { current?.id ?? "" },
                                                           set: { id in Task { await model.setEngine(active, model: id) } })) {
                            ForEach(list) { m in Text(m.recommended ? "\(m.name) (recommended)" : m.name).tag(m.id) }
                        }
                        if let efforts = current?.efforts, !efforts.isEmpty {
                            Picker("Thoroughness", selection: Binding(
                                get: { efforts.contains(model.settings.effort ?? "") ? model.settings.effort! : (current?.default_effort ?? efforts.last!) },
                                set: { eff in Task { await model.setEngine(active, model: current?.id, effort: eff) } })) {
                                ForEach(efforts, id: \.self) { Text(Engine.effortLabel($0)).tag($0) }
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .scrollDisabled(true)
                    .frame(height: 130)
                    .padding(.horizontal, 12)
                } else if model.loadingModels.contains(active.rawValue) {
                    ProgressView("Loading your models…").controlSize(.small)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct EngineCard: View {
    @Environment(AppModel.self) private var model
    let engine: Engine

    var body: some View {
        let st = model.engines?.providers[engine.rawValue]
        let selected = model.activeEngine == engine
        let account = model.models[engine.rawValue]?.account
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(engine.label).font(.title3.weight(.semibold))
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.5))
            }
            Text("by \(engine.company)").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 2)
            Group {
                if st == nil {
                    Label("Checking…", systemImage: "hourglass")
                } else if st?.installing?.state == "running" {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Installing…") }
                } else if st?.installed != true {
                    VStack(alignment: .leading, spacing: 6) {
                        if st?.installing?.state == "error" {
                            Text("Install failed. Try again.").foregroundStyle(.orange)
                        }
                        Button("Install") { Task { await model.installEngine(engine) } }
                    }
                } else if st?.signed_in != true {
                    Button("Sign In…") { model.signIn(engine) }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Signed in", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        if let email = account?.email {
                            Text([email, account?.plan.map { $0.capitalized }].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .font(.callout)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1))
        .contentShape(.rect)
        .onTapGesture { if st?.signed_in == true { Task { await model.setEngine(engine) } } }
        .animation(.default, value: selected)
    }
}

private struct ProfileStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let s = $model.settings
        VStack(spacing: 4) {
            StepHeader(icon: "person.text.rectangle", title: "About You",
                       subtitle: "These details and your signature appear on every report.")
            Form {
                TextField("Examiner name", text: Binding(get: { s.wrappedValue.examiner_name ?? "" }, set: { s.wrappedValue.examiner_name = $0 }),
                          prompt: Text("Your name, as it should appear on reports"))
                TextField("Institution", text: Binding(get: { s.wrappedValue.institution ?? "" }, set: { s.wrappedValue.institution = $0 }),
                          prompt: Text("Your university or institution"))
                TextField("Default degree", text: Binding(get: { s.wrappedValue.degree_default ?? "" }, set: { s.wrappedValue.degree_default = $0 }),
                          prompt: Text("The degree you examine most often"))
                SignatureField()
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .padding(.horizontal, 12)
        }
    }
}

private struct SchemeStep: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 4) {
            StepHeader(icon: "chart.bar.doc.horizontal", title: "Marking Scheme",
                       subtitle: "Each weight is the criterion's maximum mark; together with the viva they make 100. The defaults suit most programmes.")
            Form {
                MarkingSchemeSection(scheme: Binding(get: { model.settings.marking_scheme ?? Scheme.defaults },
                                                     set: { model.settings.marking_scheme = $0 }))
            }
            .formStyle(.grouped)
            .padding(.horizontal, 12)
        }
    }
}

private struct DoneStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("You're All Set").font(.system(size: 28, weight: .bold))
            Text("Add a dissertation with ⌘N or drop a PDF on the window. You can change any of these choices later in Settings, or run this assistant again from the Laurea menu.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 440)
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Signature

/// Shows the signature and lets the examiner drop or choose an image (saved as PNG).
struct SignatureField: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        LabeledContent("Signature") {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(model.signatureDropping ? Color.accentColor : Color.secondary.opacity(0.3),
                                                                               style: StrokeStyle(lineWidth: model.signatureDropping ? 2 : 1, dash: model.hasSignature ? [] : [4, 3])))
                    if let img = model.signatureImage {
                        Image(nsImage: img).resizable().scaledToFit().padding(6)
                    } else {
                        Text("Drop image").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 150, height: 56)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let u = urls.first else { return false }
                    model.saveSignature(from: u)
                    return true
                } isTargeted: { model.signatureDropping = $0 }
                Button(model.hasSignature ? "Change…" : "Choose…") { model.chooseSignature() }
            }
        }
    }
}
