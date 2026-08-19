import Observation
import SwiftUI
import UIKit
import FoundationModels

struct RapidFireMacro: Sendable {
    enum Trigger: Sendable {
        case chord([String])
        case roll([String])
    }

    let trigger: Trigger
    let output: String
}

@MainActor
final class RapidFireEngine {
    typealias Emit = (String) -> Void
    typealias Erase = (Int) -> Void

    private struct Stroke {
        let tokenID: UInt8
        let timestamp: TimeInterval
        let replacementUnits: UInt8
    }

    private struct FixedRingBuffer<Element> {
        private var storage: [Element?]
        private var writeIndex = 0
        private(set) var count = 0

        init(capacity: Int) {
            storage = Array(repeating: nil, count: max(1, capacity))
        }

        mutating func append(_ element: Element) {
            storage[writeIndex] = element
            writeIndex = (writeIndex + 1) % storage.count
            count = min(count + 1, storage.count)
        }

        func newest(offset: Int) -> Element? {
            guard offset >= 0, offset < count else { return nil }
            let index = (writeIndex - 1 - offset + storage.count) % storage.count
            return storage[index]
        }

        mutating func removeAll() {
            count = 0
            writeIndex = 0
        }
    }

    private struct CompiledMacro {
        let output: String
        let replacementUnits: Int
    }

    private static let supportedTokens: [String] = {
        let letters = (65...90).compactMap { UnicodeScalar($0).map(String.init) }
        let digits = (0...9).map(String.init)
        let symbols = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\"", "#", "+", "=", ".", ",", "?", "!", "'", "SPACE"]
        return letters + digits + symbols
    }()

    private let tokenIDs: [String: UInt8]
    private var chordMacros: [UInt64: CompiledMacro] = [:]
    private var rollMacros: [UInt64: CompiledMacro] = [:]
    private var activeMask: UInt64 = 0
    private var activeStartedAt = Array(repeating: TimeInterval.zero, count: 64)
    private var firedChordMask: UInt64 = 0
    private var history = FixedRingBuffer<Stroke>(capacity: 8)
    private var maxRollLength = 0

    private let chordWindow: TimeInterval
    private let rollWindow: TimeInterval
    private let emit: Emit
    private let erase: Erase

    init(
        macros: [RapidFireMacro] = [],
        chordWindow: TimeInterval = 0.060,
        rollWindow: TimeInterval = 0.220,
        emit: @escaping Emit,
        erase: @escaping Erase
    ) {
        precondition(Self.supportedTokens.count <= 63, "Rapid Fire token table must fit in a UInt64 bitmask")
        tokenIDs = Dictionary(uniqueKeysWithValues: Self.supportedTokens.enumerated().map { ($1, UInt8($0)) })
        self.chordWindow = chordWindow
        self.rollWindow = rollWindow
        self.emit = emit
        self.erase = erase
        compile(macros)
    }

    func reconfigure(macros: [RapidFireMacro]) {
        chordMacros.removeAll(keepingCapacity: true)
        rollMacros.removeAll(keepingCapacity: true)
        maxRollLength = 0
        compile(macros)
        resetTransientState()
    }

    func keyDown(token: String, output: String, timestamp: TimeInterval) {
        guard let tokenID = tokenIDs[token] else {
            emit(output)
            return
        }

        let replacementUnits = UInt8(clamping: max(1, output.count))
        let bit = UInt64(1) << UInt64(tokenID)
        activeMask |= bit
        activeStartedAt[Int(tokenID)] = timestamp

        emit(output)
        history.append(Stroke(tokenID: tokenID, timestamp: timestamp, replacementUnits: replacementUnits))

        if resolveChord(at: timestamp) {
            history.removeAll()
            return
        }
        resolveRoll(at: timestamp)
    }

    func keyUp(token: String, timestamp: TimeInterval) {
        guard let tokenID = tokenIDs[token] else { return }
        let bit = UInt64(1) << UInt64(tokenID)
        activeMask &= ~bit
        activeStartedAt[Int(tokenID)] = 0
        if activeMask != firedChordMask { firedChordMask = 0 }
        expireRollHistory(at: timestamp)
    }

    func cancel(token: String, timestamp: TimeInterval) {
        keyUp(token: token, timestamp: timestamp)
    }

    func resetTransientState() {
        activeMask = 0
        firedChordMask = 0
        activeStartedAt = Array(repeating: .zero, count: 64)
        history.removeAll()
    }

    private func compile(_ macros: [RapidFireMacro]) {
        for macro in macros {
            switch macro.trigger {
            case .chord(let tokens):
                guard let signature = chordSignature(tokens), !tokens.isEmpty else { continue }
                chordMacros[signature] = CompiledMacro(output: macro.output, replacementUnits: tokens.count)
            case .roll(let tokens):
                guard let signature = rollSignature(tokens), tokens.count >= 2 else { continue }
                rollMacros[signature] = CompiledMacro(output: macro.output, replacementUnits: tokens.count)
                maxRollLength = max(maxRollLength, tokens.count)
            }
        }
    }

    private func resolveChord(at timestamp: TimeInterval) -> Bool {
        guard activeMask != 0,
              activeMask != firedChordMask,
              let macro = chordMacros[activeMask],
              chordIsWithinWindow(at: timestamp)
        else { return false }

        erase(macro.replacementUnits)
        emit(macro.output)
        firedChordMask = activeMask
        return true
    }

    private func resolveRoll(at timestamp: TimeInterval) {
        guard maxRollLength >= 2 else { return }
        expireRollHistory(at: timestamp)
        let upperBound = min(maxRollLength, history.count)
        guard upperBound >= 2 else { return }

        for length in stride(from: upperBound, through: 2, by: -1) {
            guard let signature = recentRollSignature(length: length),
                  let macro = rollMacros[signature],
                  let oldest = history.newest(offset: length - 1),
                  timestamp - oldest.timestamp <= rollWindow
            else { continue }

            var replacementUnits = 0
            for offset in 0..<length {
                replacementUnits += Int(history.newest(offset: offset)?.replacementUnits ?? 0)
            }
            erase(replacementUnits > 0 ? replacementUnits : macro.replacementUnits)
            emit(macro.output)
            history.removeAll()
            return
        }
    }

    private func expireRollHistory(at timestamp: TimeInterval) {
        guard let newest = history.newest(offset: 0), timestamp - newest.timestamp > rollWindow else { return }
        history.removeAll()
    }

    private func chordIsWithinWindow(at timestamp: TimeInterval) -> Bool {
        var mask = activeMask
        var earliest = timestamp
        while mask != 0 {
            let index = mask.trailingZeroBitCount
            earliest = min(earliest, activeStartedAt[index])
            mask &= mask - 1
        }
        return timestamp - earliest <= chordWindow
    }

    private func chordSignature(_ tokens: [String]) -> UInt64? {
        var signature: UInt64 = 0
        for token in tokens {
            guard let tokenID = tokenIDs[token] else { return nil }
            signature |= UInt64(1) << UInt64(tokenID)
        }
        return signature
    }

    private func rollSignature(_ tokens: [String]) -> UInt64? {
        guard tokens.count <= 8 else { return nil }
        var signature = UInt64(tokens.count) << 56
        for (index, token) in tokens.enumerated() {
            guard let tokenID = tokenIDs[token] else { return nil }
            signature |= UInt64(tokenID + 1) << UInt64(index * 7)
        }
        return signature
    }

    private func recentRollSignature(length: Int) -> UInt64? {
        guard length <= 8 else { return nil }
        var signature = UInt64(length) << 56
        for index in 0..<length {
            guard let stroke = history.newest(offset: length - 1 - index) else { return nil }
            signature |= UInt64(stroke.tokenID + 1) << UInt64(index * 7)
        }
        return signature
    }

    #if DEBUG
    static func debugSelfCheck() -> Bool {
        var text = ""
        let engine = RapidFireEngine(
            macros: [
                RapidFireMacro(trigger: .chord(["Q", "P"]), output: "C"),
                RapidFireMacro(trigger: .roll(["C", "A", "R"]), output: "CARINA")
            ],
            emit: { text.append(contentsOf: $0) },
            erase: { count in
                for _ in 0..<count where !text.isEmpty { text.removeLast() }
            }
        )

        engine.keyDown(token: "Q", output: "q", timestamp: 1.000)
        engine.keyDown(token: "P", output: "p", timestamp: 1.030)
        guard text == "C" else { return false }
        engine.keyUp(token: "Q", timestamp: 1.040)
        engine.keyUp(token: "P", timestamp: 1.050)

        text = ""
        engine.keyDown(token: "C", output: "c", timestamp: 2.000)
        engine.keyUp(token: "C", timestamp: 2.010)
        engine.keyDown(token: "A", output: "a", timestamp: 2.040)
        engine.keyUp(token: "A", timestamp: 2.050)
        engine.keyDown(token: "R", output: "r", timestamp: 2.080)
        guard text == "CARINA" else { return false }

        text = ""
        engine.resetTransientState()
        engine.keyDown(token: "X", output: "x", timestamp: 3.000)
        return text == "x"
    }
    #endif
}

struct RapidFireKeyControl: UIViewRepresentable {
    let title: String
    let token: String
    let output: String
    let onDown: (String, String, TimeInterval) -> Void
    let onUp: (String, TimeInterval) -> Void
    let onCancel: (String, TimeInterval) -> Void

    func makeUIView(context: Context) -> TouchKeyView {
        let view = TouchKeyView()
        view.isExclusiveTouch = false
        view.isMultipleTouchEnabled = true
        update(view)
        return view
    }

    func updateUIView(_ uiView: TouchKeyView, context: Context) { update(uiView) }

    private func update(_ view: TouchKeyView) {
        view.title = title
        view.accessibilityLabel = title == "space" ? "space" : title
        view.onDown = { timestamp in onDown(token, output, timestamp) }
        view.onUp = { timestamp in onUp(token, timestamp) }
        view.onCancel = { timestamp in onCancel(token, timestamp) }
    }

    final class TouchKeyView: UIControl {
        var onDown: ((TimeInterval) -> Void)?
        var onUp: ((TimeInterval) -> Void)?
        var onCancel: ((TimeInterval) -> Void)?
        var title: String = "" { didSet { label.text = title } }
        private let label = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isAccessibilityElement = true
            accessibilityTraits = .keyboardKey
            layer.cornerRadius = 9
            layer.borderWidth = 1 / UIScreen.main.scale
            layer.borderColor = UIColor.label.withAlphaComponent(0.06).cgColor
            backgroundColor = .secondarySystemBackground
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.08
            layer.shadowRadius = 1
            layer.shadowOffset = CGSize(width: 0, height: 1)

            label.translatesAutoresizingMaskIntoConstraints = false
            label.textAlignment = .center
            label.adjustsFontForContentSizeCategory = true
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
                label.topAnchor.constraint(equalTo: topAnchor),
                label.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            label.font = .systemFont(ofSize: title.count == 1 ? 24 : 16, weight: .medium)
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard isEnabled, let touch = touches.first else { return }
            setPressed(true)
            onDown?(touch.timestamp)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            setPressed(false)
            onUp?(touch.timestamp)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            setPressed(false)
            onCancel?(touch.timestamp)
        }

        private func setPressed(_ pressed: Bool) {
            alpha = pressed ? 0.72 : 1
            transform = pressed ? CGAffineTransform(scaleX: 0.985, y: 0.985) : .identity
        }
    }
}

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

    @ObservationIgnored private lazy var rapidFire = RapidFireEngine(
        emit: { [weak self] text in
            self?.controller?.textDocumentProxy.insertText(text)
            self?.lastInserted = text
        },
        erase: { [weak self] count in
            guard let proxy = self?.controller?.textDocumentProxy else { return }
            for _ in 0..<count { proxy.deleteBackward() }
        }
    )

    init(controller: UIInputViewController) {
        self.controller = controller
        #if DEBUG
        assert(RapidFireEngine.debugSelfCheck(), "Rapid Fire self-check failed")
        #endif
    }

    var draft: String { controller?.textDocumentProxy.documentContextBeforeInput ?? "" }
    var stakes: StakesLevel {
        let text = draft.lowercased()
        if ["contract", "payment", "wire", "investment", "forex", "lawsuit", "salary", "deadline", "agree to"].contains(where: text.contains) { return .high }
        if ["meeting", "proposal", "budget", "schedule"].contains(where: text.contains) { return .medium }
        return .low
    }

    func insert(_ text: String) { controller?.textDocumentProxy.insertText(text); lastInserted = text; haptic(.light) }
    func key(_ text: String) { guard mode != .alignmentHard else { return }; insert(text); if isShifted && !isSymbols { isShifted = false } }
    func delete() { guard mode != .alignmentHard else { return }; controller?.textDocumentProxy.deleteBackward(); lastInserted = ""; rapidFire.resetTransientState(); haptic(.medium) }
    func applyAlignment() { insert("I want to be clear, deliberate, and aligned on the next step. "); mode = .normal }
    func toggleAI() { aiEnabled.toggle(); haptic(aiEnabled ? .heavy : .rigid) }
    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) { let generator = UIImpactFeedbackGenerator(style: style); generator.prepare(); generator.impactOccurred(intensity: 0.9) }

    func rapidFireDown(token: String, output: String, timestamp: TimeInterval) {
        guard mode != .alignmentHard else { return }
        rapidFire.keyDown(token: token, output: output, timestamp: timestamp)
        if isShifted && !isSymbols { isShifted = false }
        haptic(.light)
    }

    func rapidFireUp(token: String, timestamp: TimeInterval) {
        rapidFire.keyUp(token: token, timestamp: timestamp)
    }

    func rapidFireCancel(token: String, timestamp: TimeInterval) {
        rapidFire.cancel(token: token, timestamp: timestamp)
    }

    func configureRapidFire(macros: [RapidFireMacro]) {
        rapidFire.reconfigure(macros: macros)
    }

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
            LinearGradient(colors: [accent.opacity(0.13), .clear, accent.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
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
                Image(systemName: "sparkles")
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
                    ForEach(row, id: \.self) { token in rapidFireKey(display(token), token: token, output: display(token)) }
                    if index == 2 { systemKey("delete.left") { bridge.delete() } }
                }.frame(height: 43).padding(.horizontal, index == 1 ? 17 : 0)
            }
            HStack(spacing: 6) {
                systemKey(bridge.isSymbols ? "ABC" : "123") { bridge.isSymbols.toggle() }
                if bridge.controller?.needsInputModeSwitchKey == true { systemKey("face.smiling") { bridge.controller?.advanceToNextInputMode() } }
                rapidFireKey("space", token: "SPACE", output: " ").frame(maxWidth: .infinity)
                systemKey("return") { bridge.key("\n") }
                systemKey("mic.fill") { bridge.haptic(.light) }
                Button { bridge.toggleAI() } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(minWidth: 42, minHeight: 45)
                        .foregroundStyle(bridge.aiEnabled ? .white : .secondary)
                        .background(bridge.aiEnabled ? accent : Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }.buttonStyle(.plain)
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
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).lineLimit(1).foregroundStyle(accent)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func rapidFireKey(_ title: String, token: String, output: String) -> some View {
        RapidFireKeyControl(
            title: title,
            token: token,
            output: output,
            onDown: bridge.rapidFireDown,
            onUp: bridge.rapidFireUp,
            onCancel: bridge.rapidFireCancel
        )
        .frame(maxWidth: .infinity)
        .frame(height: 43)
    }

    private func systemKey(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 43, height: 43)
                .foregroundStyle(.primary)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }.buttonStyle(.plain)
    }

    private func display(_ letter: String) -> String { bridge.isSymbols || bridge.isShifted ? letter : letter.lowercased() }
}
