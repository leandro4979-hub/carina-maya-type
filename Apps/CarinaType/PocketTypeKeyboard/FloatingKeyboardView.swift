import Observation
import SwiftUI
import UIKit
import FoundationModels

enum KeyboardMode { case normal, alignmentSoft, alignmentHard }
enum AIAction { case reply, shorten, friendly, formal, compassionate, confident, translate }

@MainActor @Observable final class KeyboardBridge {
    weak var controller: UIInputViewController?
    var mode: KeyboardMode = .normal
    var aiEnabled = true
    var isSymbols = false
    var isShifted = true
    var lastInserted = ""
    var isGenerating = false
    var aiStatus = ""

    init(controller: UIInputViewController) { self.controller = controller }

    var draft: String { controller?.textDocumentProxy.documentContextBeforeInput ?? "" }
    var stakes: StakesLevel {
        let text = draft.lowercased()
        if ["contract", "payment", "wire", "investment", "forex", "lawsuit", "salary", "deadline", "agree to"].contains(where: text.contains) { return .high }
        if ["meeting", "proposal", "budget", "schedule"].contains(where: text.contains) { return .medium }
        return .low
    }
    func insert(_ text: String) { controller?.textDocumentProxy.insertText(text); lastInserted = text; haptic(.light) }
    func key(_ text: String) { guard mode != .alignmentHard else { return }; insert(text); if isShifted && !isSymbols { isShifted = false } }
    func delete() { guard mode != .alignmentHard else { return }; controller?.textDocumentProxy.deleteBackward(); lastInserted = ""; haptic(.medium) }
    func applyAlignment() { insert("I want to be clear, deliberate, and aligned on the next step. "); mode = .normal }
    func toggleAI() { aiEnabled.toggle(); haptic(aiEnabled ? .heavy : .rigid) }
    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { let generator = UIImpactFeedbackGenerator(style: style); generator.prepare(); generator.impactOccurred(intensity: 0.9) }

    func generate(_ action: AIAction) {
        guard aiEnabled, !isGenerating else { return }
        let context = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !context.isEmpty else { aiStatus = "Type or paste text first."; return }
        isGenerating = true
        aiStatus = "CARINA is writing…"
        Task {
            defer { isGenerating = false }
            do {
                guard #available(iOS 26.0, *) else { throw LocalGenerationError.unsupported }
                let generated = try await OnDeviceCARINA.generate(action: action, context: context)
                insert(generated)
                aiStatus = "Inserted. Review before sending."
            } catch {
                aiStatus = "Apple Intelligence is unavailable. Turn it on in Settings and try again."
            }
        }
    }

    private enum LocalGenerationError: Error { case unsupported }
}

enum StakesLevel { case low, medium, high }

@available(iOS 26.0, *)
private enum OnDeviceCARINA {
    static func generate(action: AIAction, context: String) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else { throw GenerationFailure.unavailable }
        let instruction = "You are CARINA, a concise writing assistant. Return only the requested text. Never claim you sent anything."
        let request: String
        switch action {
        case .reply: request = "Write a short, thoughtful reply to this text: \(context)"
        case .shorten: request = "Rewrite this in fewer words while preserving its meaning: \(context)"
        case .friendly: request = "Rewrite this with a warm, friendly tone: \(context)"
        case .formal: request = "Rewrite this in a clear, professional formal tone: \(context)"
        case .compassionate: request = "Rewrite this with empathy and compassion: \(context)"
        case .confident: request = "Rewrite this with calm, confident clarity: \(context)"
        case .translate: request = "Translate this into natural Spanish. Return only the translation: \(context)"
        }
        let session = LanguageModelSession(model: model, instructions: instruction)
        let response = try await session.respond(to: request)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum GenerationFailure: Error { case unavailable }
}

struct FloatingKeyboardView: View {
    @Bindable var bridge: KeyboardBridge
    private let accent = Color.indigo
    private let letters = [["Q","W","E","R","T","Y","U","I","O","P"], ["A","S","D","F","G","H","J","K","L"], ["Z","X","C","V","B","N","M"]]
    private let symbols = [["1","2","3","4","5","6","7","8","9","0"], ["-","/",":",";","(",")","$","&","@","\""], ["#","+","=",".",",","?","!","'"]]

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            LinearGradient(
                colors: [accent.opacity(0.13), .clear, accent.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            VStack(spacing: 6) {
                if bridge.mode != .normal { alignmentCard }
                commandStrip
                keyBed
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .animation(.spring(duration: 0.24, bounce: 0.16), value: bridge.mode)
    }

    private var alignmentCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(bridge.mode == .alignmentHard ? "Cognitive Alignment Active" : "Pause. Let’s review this together.").font(.caption.weight(.bold))
                Text(bridge.stakes == .high ? "This draft includes high-stakes language. Review intent before committing." : "A deliberate review may make this clearer.").font(.caption2)
            }
            Spacer()
            Button("Skip") { bridge.mode = .normal }.buttonStyle(.borderless).font(.caption)
            Button("Align") { bridge.applyAlignment() }.buttonStyle(.borderedProminent).font(.caption)
        }
        .padding(11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .tint(accent)
    }

    private var commandStrip: some View {
        HStack(spacing: 7) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    if bridge.aiEnabled {
                        pill("Reply", "arrowshape.turn.up.left") { bridge.generate(.reply) }
                        pill("Translate", "character.bubble") { bridge.generate(.translate) }
                        pill("Shorten", "arrow.down.right.and.arrow.up.left") { bridge.generate(.shorten) }
                        pill("Friendly", "face.smiling") { bridge.generate(.friendly) }
                        pill("Formal", "briefcase") { bridge.generate(.formal) }
                        pill("Compassionate", "heart") { bridge.generate(.compassionate) }
                        pill("Confident", "bolt") { bridge.generate(.confident) }
                    }
                }.padding(.horizontal, 2)
            }
            Button { bridge.toggleAI() } label: {
                Image(systemName: bridge.aiEnabled ? "sparkles" : "sparkles")
                    .font(.headline).frame(width: 38, height: 38)
                    .foregroundStyle(bridge.aiEnabled ? .white : .secondary)
                    .background(bridge.aiEnabled ? accent : Color(uiColor: .tertiarySystemFill), in: Circle())
            }.accessibilityLabel(bridge.aiEnabled ? "Generated AI on" : "Generated AI off")
        }
        .padding(6)
        .background(.regularMaterial, in: Capsule())
        .overlay { Capsule().stroke(accent.opacity(0.14), lineWidth: 1) }
        .overlay(alignment: .bottom) {
            if !bridge.aiStatus.isEmpty {
                Text(bridge.aiStatus)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accent, in: Capsule())
                    .offset(y: 20)
            }
        }
    }

    private var keyBed: some View {
        VStack(spacing: 7) {
            HStack(spacing: 0) { Text("I"); Divider(); Text("the"); Divider(); Text("to") }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(height: 25)
                .padding(.horizontal, 24)
                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
            ForEach(Array((bridge.isSymbols ? symbols : letters).enumerated()), id: \.offset) { index, row in
                HStack(spacing: 6) {
                    if index == 2 { systemKey(bridge.isSymbols ? "#+=" : "shift") { bridge.isShifted.toggle() } }
                    ForEach(row, id: \.self) { letter in keyButton(display(letter)) { bridge.key(display(letter)) } }
                    if index == 2 { systemKey("delete.left") { bridge.delete() } }
                }.frame(height: 43).padding(.horizontal, index == 1 ? 17 : 0)
            }
            HStack(spacing: 6) {
                systemKey(bridge.isSymbols ? "ABC" : "123") { bridge.isSymbols.toggle() }
                if bridge.controller?.needsInputModeSwitchKey == true { systemKey("face.smiling") { bridge.controller?.advanceToNextInputMode() } }
                keyButton("space") { bridge.key(" ") }.frame(maxWidth: .infinity)
                systemKey("return") { bridge.key("\n") }
                systemKey("mic.fill") { bridge.haptic(.light) }
                Button { bridge.toggleAI() } label: { Image(systemName: "sparkles").font(.system(size: 17, weight: .semibold)).frame(minWidth: 42, minHeight: 45).foregroundStyle(bridge.aiEnabled ? .white : .secondary).background(bridge.aiEnabled ? accent : Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous)) }.buttonStyle(.plain)
            }.frame(height: 43)
        }
        .padding(6)
        .frame(height: 228, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(accent.opacity(0.12), lineWidth: 1) }
        .opacity(bridge.mode == .alignmentHard ? 0.42 : 1)
        .allowsHitTesting(bridge.mode != .alignmentHard)
    }

    private func pill(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.caption.weight(.semibold)).lineLimit(1).foregroundStyle(accent).padding(.horizontal, 10).padding(.vertical, 8).background(Color(uiColor: .secondarySystemBackground), in: Capsule()) }
        .buttonStyle(.plain)
    }
    private func keyButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: title.count == 1 ? 24 : 16, weight: .medium)).frame(maxWidth: .infinity).frame(height: 43).foregroundStyle(.primary).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 9, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(.primary.opacity(0.06), lineWidth: 1)).shadow(color: .black.opacity(0.08), radius: 1, y: 1) }.buttonStyle(.plain)
    }
    private func systemKey(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).frame(width: 43, height: 43).foregroundStyle(.primary).background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous)) }.buttonStyle(.plain)
    }
    private func display(_ letter: String) -> String { bridge.isSymbols || bridge.isShifted ? letter : letter.lowercased() }
}
