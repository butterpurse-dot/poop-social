import Foundation
import Observation
import Speech

// MARK: - Voice as a text input, on the OS you actually have
//
// Two separate mechanisms, and it is worth being precise about which does what,
// because they are easy to conflate:
//
//   1. **The system keyboard layer.** On iOS 27, "Write with Siri" and "Type to
//      Siri" sit above the keyboard in every app; on every earlier iOS the
//      keyboard's own mic key dictates. Both are *system* features that work in
//      any standard text field. This app needs no code for them — and it must
//      avoid *breaking* them, which means no custom `inputView`, no
//      `inputAccessoryView` covering the field, and a real `TextEditor`. The
//      composer honours all three.
//
//   2. **In-app dictation**, which is what this file adds. It exists because
//      (a) the system layer's polish is only guaranteed on Apple Intelligence
//      hardware, and (b) a spoken sentence is not app-voice text. This takes raw
//      dictated words and runs them through the LLM seam, which polishes them
//      into the tone the rest of the app writes in.
//
// The second is not a replacement for the first. It is the floor under it: it
// works on iOS 17, on any device with a microphone, with no Apple Intelligence
// requirement at all.

/// Drives live dictation: permissions, the recogniser, and the transcript.
///
/// `@Observable` so a view can bind to `transcript` directly. `@MainActor`
/// because it publishes UI state and every mutation happens on the main actor.
@MainActor
@Observable
final class DictationController {

    /// The live transcript. Empty when not listening.
    private(set) var transcript = ""
    /// True while the mic is capturing.
    private(set) var isListening = false
    /// Set when something went wrong, so the UI can say *what* rather than
    /// silently doing nothing.
    private(set) var error: DictationError?

    /// Clarifies *why* — never "an error occurred".
    enum DictationError: Equatable {
        case notAuthorised
        case unavailableOnDevice
        case recogniserFailed(String)

        var message: String {
            switch self {
            case .notAuthorised:
                return "Microphone or speech access is off. Turn it on in Settings to dictate."
            case .unavailableOnDevice:
                return "Dictation isn't available right now. Typing works fine."
            case .recogniserFailed(let detail):
                return detail.isEmpty ? "That didn't come through. Try again." : detail
            }
        }
    }

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recogniser = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    // MARK: - Permission

    /// Ask for both permissions, returning whether we can proceed.
    ///
    /// Both are requested because both are genuinely needed: the mic to hear,
    /// and speech recognition to transcribe. Requesting only one produces a
    /// silent failure, which is the worst outcome.
    func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else {
            error = .notAuthorised
            return false
        }

        let mic = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard mic else {
            error = .notAuthorised
            return false
        }
        return true
    }

    // MARK: - Start / stop

    func start() async {
        guard !isListening else { return }
        error = nil
        transcript = ""

        guard await requestPermission() else { return }
        guard let recogniser, recogniser.isAvailable else {
            error = .unavailableOnDevice
            return
        }

        do {
            try begin(recogniser: recogniser)
            isListening = true
        } catch {
            self.error = .recogniserFailed(error.localizedDescription)
            stop()
        }
    }

    private func begin(recogniser: SFSpeechRecognizer) throws {
        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        // Partial results are the point: the words should appear as they are
        // spoken, not all at once at the end.
        request.shouldReportPartialResults = true

        #if os(iOS)
        // iOS requires the audio session to be configured before the engine
        // starts: without `.record` the input node yields silence and the
        // recogniser returns nothing. macOS has no AVAudioSession — the engine
        // owns input routing there — so this config is iOS-only.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()

        self.audioEngine = engine
        self.request = request

        task = recogniser.recognitionTask(with: request) { [weak self] result, error in
            // Called on an arbitrary queue; hop to the main actor before
            // touching observable state.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil {
                    self.stop()
                }
            }
        }
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()

        audioEngine = nil
        request = nil
        task = nil
        isListening = false

        // Give the ducked audio back rather than leaving the phone quiet.
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    /// Clear the transcript, e.g. when the sheet closes.
    func reset() {
        stop()
        transcript = ""
        error = nil
    }
}

// MARK: - Polishing dictated words into app voice

/// Turns a raw transcript into text that fits the app.
///
/// This is where the LLM seam earns its keep: dictation gives you *words*, and
/// the app's voice is a specific register — internet slang, group-chat deadpan,
/// no emoji. A thin wrapper over `LLM` so the composer does not need to know
/// about tasks or providers.
@MainActor
enum VoiceText {

    /// Result of a polish, including which provider answered so the UI can be
    /// honest about it.
    struct Polished {
        let text: String
        /// The provider's name, or `nil` when the wording was left as spoken.
        let providerName: String?
    }

    /// Polish a dictated transcript for the composer.
    ///
    /// **Never throws and never loses the user's words.** If every provider
    /// fails, the raw transcript is returned unchanged. That matters more than
    /// the polish: a person's speech disappearing because a model was
    /// unreachable would be a far worse outcome than an unpolished post.
    static func polish(_ transcript: String, task: LLMTask) async -> Polished {
        let raw = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return Polished(text: "", providerName: nil) }

        do {
            let result = try await LLM.shared.text(task: task, input: raw)
            guard !result.text.isEmpty else {
                return Polished(text: raw, providerName: nil)
            }
            return Polished(text: result.text, providerName: result.providerName)
        } catch {
            // Total failure — keep what the person actually said.
            return Polished(text: raw, providerName: nil)
        }
    }

    /// Which task suits which composer mode. Kept here so the mapping is not
    /// duplicated at every call site.
    static func task(for mode: ComposerMode) -> LLMTask {
        switch mode {
        case .drop:   return .oneLiner
        case .review: return .reviewPunchUp
        }
    }
}
