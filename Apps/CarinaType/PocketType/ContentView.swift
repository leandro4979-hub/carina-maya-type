import SwiftUI
import AVFAudio
import Speech

struct ContentView: View {
    @State private var showingVoice = false
    @State private var showingSetup = false

    private let accent = Color.indigo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    statusCard
                    privacyRow
                    setupCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("CARINA TYPE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingVoice = true } label: {
                        Label("Talk to CARINA", systemImage: "waveform")
                    }
                    .tint(accent)
                }
            }
        }
        .tint(accent)
        .sheet(isPresented: $showingVoice) { VoiceCarinaView() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            Text("Write with clarity")
                .font(.largeTitle.bold())
            Text("Private, on-device help for replies, rewrites, and the next words you want to say.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Ready to type", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text("Open CARINA TYPE from the keyboard globe in any app. Suggestions stay editable and nothing is sent until you tap Send.")
                .foregroundStyle(.secondary)
            Button { showingVoice = true } label: {
                Label("Talk to CARINA", systemImage: "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .suiteCard(accent: accent)
    }

    private var privacyRow: some View {
        HStack(spacing: 0) {
            feature("Private", icon: "lock.fill")
            Divider().frame(height: 34)
            feature("On device", icon: "iphone")
            Divider().frame(height: 34)
            feature("You send", icon: "hand.tap.fill")
        }
        .suiteCard(accent: accent)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Turn on the keyboard", systemImage: "keyboard")
                .font(.headline)
            Button(showingSetup ? "Hide steps" : "Show easy steps") {
                withAnimation(.snappy) { showingSetup.toggle() }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            if showingSetup {
                VStack(alignment: .leading, spacing: 10) {
                    setupStep(1, "Open Settings")
                    setupStep(2, "Tap General, then Keyboard")
                    setupStep(3, "Tap Keyboards, then Add New Keyboard")
                    setupStep(4, "Choose CARINA TYPE")
                    Text("Keep Full Access off.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .suiteCard(accent: accent)
    }

    private func feature(_ title: String, icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).foregroundStyle(accent)
            Text(title).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func setupStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(accent, in: Circle())
            Text(text).font(.body.weight(.medium))
        }
    }
}

private extension View {
    @ViewBuilder
    func suiteCard(accent: Color) -> some View {
        if #available(iOS 26.0, *) {
            self
                .padding(18)
                .glassEffect(.regular.tint(accent.opacity(0.08)), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            self
                .padding(18)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(accent.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

#Preview { ContentView() }

private struct VoiceCarinaView: View {
    @StateObject private var voice = VoiceCarinaController()

    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(.secondary.opacity(0.3)).frame(width: 42, height: 5).padding(.top, 10)
            Image(systemName: voice.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                .font(.system(size: 90))
                .foregroundStyle(voice.isListening ? .blue : .secondary)
            Text(voice.isListening ? "CARINA is listening" : "Talk to CARINA")
                .font(.title2.weight(.bold))
            Text(voice.transcript.isEmpty ? "Hold Talk, say what you need, then release." : voice.transcript)
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                .padding(18)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
            if !voice.response.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Label("CARINA", systemImage: "sparkles")
                        .font(.caption.weight(.bold)).foregroundStyle(.blue)
                    Text(voice.response)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
            }
            Button(action: voice.toggleListening) {
                Label(voice.isListening ? "Release / Finish" : "Hold to Talk", systemImage: voice.isListening ? "stop.fill" : "mic.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(18)
                    .foregroundStyle(.white).background(voice.isListening ? .red : .blue, in: Capsule())
            }
            Text("Speech recognition is provided by Apple and may use Apple speech services. CARINA never sends a message or makes a call for you.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }
}

private final class VoiceCarinaController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var transcript = ""
    @Published var response = ""
    @Published var isListening = false
    @Published var status = "Ready"

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let speaker = AVSpeechSynthesizer()
    private var hasResponded = false

    override init() {
        super.init()
        speaker.delegate = self
    }

    func toggleListening() { isListening ? stop() : requestPermissionAndStart() }

    private func requestPermissionAndStart() {
        AVAudioApplication.requestRecordPermission { [weak self] microphoneGranted in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    guard microphoneGranted, status == .authorized else {
                        self?.response = "Microphone and Speech Recognition permission are needed before I can listen."
                        return
                    }
                    self?.start()
                }
            }
        }
    }

    private func start() {
        guard let recognizer, recognizer.isAvailable else { response = "Speech recognition is not available right now."; return }
        stopListeningWithoutReply()
        speaker.stopSpeaking(at: .immediate)
        transcript = ""
        response = ""
        hasResponded = false
        status = "Listening"
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true { self?.stop() }
                }
            }
        } catch { response = "I could not start the microphone. Check that no other app is using it."; status = "Microphone unavailable" }
    }

    private func stop(clearResponse: Bool = false) {
        stopListeningWithoutReply()
        if !transcript.isEmpty && !hasResponded { respond() }
        if clearResponse { response = "" }
    }

    private func stopListeningWithoutReply() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
    }

    private func respond() {
        hasResponded = true
        status = "CARINA is thinking"
        let text = transcript.lowercased()
        if text.contains("help") || text.contains("what can") {
            response = "I can help you prepare a reply, clarify a high-stakes message, summarize your thought, or turn it into a focused next step. I never send anything for you."
        } else if text.contains("message") || text.contains("reply") {
            response = "I heard you. Open the message field, choose CARINA TYPE, and tap Reply or Rephrase. I will prepare text for you to review before you send it."
        } else if text.contains("forex") || text.contains("trade") || text.contains("buy") || text.contains("sell") {
            response = "I can help organize your trade thesis, risk limits, and questions to verify. I will not place trades or tell you to buy or sell."
        } else if text.contains("important") || text.contains("contract") || text.contains("payment") || text.contains("deadline") {
            response = "This sounds important. Let’s slow down: what outcome do you want, what must stay flexible, and what commitment are you comfortable making?"
        } else {
            response = "I heard: “\(transcript)”. My first take is to make the goal, the next step, and any deadline explicit. Tell me which part you want to shape."
        }
        speak(response)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speaker.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) { DispatchQueue.main.async { self.status = "CARINA is speaking" } }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { DispatchQueue.main.async { self.status = "Ready" } }
}
