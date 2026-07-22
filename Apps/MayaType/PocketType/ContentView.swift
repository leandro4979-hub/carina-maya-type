import SwiftUI
import AVFAudio
import Speech

struct ContentView: View {
    @State private var showingVoice = false
    @State private var showingSetup = false

    private let accent = Color.teal

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "wand.and.sparkles")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(accent)
                        Text("Make every message easier")
                            .font(.largeTitle.bold())
                        Text("Fast, calm writing support with useful replies ready when you need them.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Label("MAYA is ready", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text("Open MAYA TYPE from the keyboard globe in any app, then tap a suggestion or keep typing normally.")
                            .foregroundStyle(.secondary)
                        Button { showingVoice = true } label: {
                            Label("Talk to MAYA", systemImage: "mic.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .suiteCard(accent: accent)

                    HStack(spacing: 0) {
                        feature("Private", icon: "lock.fill")
                        Divider().frame(height: 34)
                        feature("Quick", icon: "bolt.fill")
                        Divider().frame(height: 34)
                        feature("You choose", icon: "hand.tap.fill")
                    }
                    .suiteCard(accent: accent)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Turn on the keyboard", systemImage: "keyboard")
                            .font(.headline)
                        Button(showingSetup ? "Hide steps" : "Show easy steps") {
                            withAnimation(.snappy) { showingSetup.toggle() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        if showingSetup {
                            setupStep(1, "Open Settings")
                            setupStep(2, "Tap General, then Keyboard")
                            setupStep(3, "Tap Keyboards, then Add New Keyboard")
                            setupStep(4, "Choose MAYA TYPE")
                            Text("Keep Full Access off.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(accent)
                        }
                    }
                    .suiteCard(accent: accent)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("MAYA TYPE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingVoice = true } label: {
                        Label("Talk to MAYA", systemImage: "waveform")
                    }
                }
            }
        }
        .tint(accent)
        .sheet(isPresented: $showingVoice) { VoiceMayaView() }
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassEffect(.regular.tint(accent.opacity(0.08)), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        } else {
            self
                .frame(maxWidth: .infinity, alignment: .leading)
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

private struct VoiceMayaView: View {
    @StateObject private var voice = VoiceMayaController()

    var body: some View {
        VStack(spacing: 22) {
            Capsule().fill(.secondary.opacity(0.3)).frame(width: 42, height: 5).padding(.top, 10)
            Image(systemName: voice.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                .font(.system(size: 90))
                .foregroundStyle(voice.isListening ? .teal : .secondary)
            Text(voice.isListening ? "MAYA is listening" : "Talk to MAYA")
                .font(.title2.weight(.bold))
            Text(voice.transcript.isEmpty ? "Hold Talk, say what you need, then release." : voice.transcript)
                .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                .padding(18)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
            if !voice.response.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Label("MAYA", systemImage: "sparkles")
                        .font(.caption.weight(.bold)).foregroundStyle(.teal)
                    Text(voice.response)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
            }
            Button(action: voice.toggleListening) {
                Label(voice.isListening ? "Release / Finish" : "Hold to Talk", systemImage: voice.isListening ? "stop.fill" : "mic.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(18)
                    .foregroundStyle(.white).background(voice.isListening ? .red : .teal, in: Capsule())
            }
            Text("Speech recognition is provided by Apple and may use Apple speech services. MAYA never sends a message or makes a call for you.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }
}

private final class VoiceMayaController: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var response = ""
    @Published var isListening = false

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

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
        stop(clearResponse: false)
        transcript = ""
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
        } catch { response = "I could not start the microphone." }
    }

    private func stop(clearResponse: Bool = false) {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        if !transcript.isEmpty { respond() }
        if clearResponse { response = "" }
    }

    private func respond() {
        let text = transcript.lowercased()
        if text.contains("help") || text.contains("what can") { response = "I can help you prepare a reply, make a clearer version, or turn your idea into a short next step. Nothing sends until you choose to send it." }
        else if text.contains("message") || text.contains("reply") { response = "I heard your request. Open any message field and use MAYA TYPE to choose an editable reply draft." }
        else { response = "I heard: “\(transcript)”. I’m ready to help you turn that into a clear next move." }
    }
}
