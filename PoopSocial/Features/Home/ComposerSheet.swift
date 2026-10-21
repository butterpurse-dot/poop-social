import SwiftUI
import SwiftData

@MainActor
struct ComposerSheet: View {

    let request: ComposerRequest

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Bathroom.createdAt, order: .reverse) private var bathrooms: [Bathroom]

    @State private var mode: ComposerMode
    @State private var text = ""
    @State private var emoji = "🚽"
    @State private var joke = ""
    @State private var verdict: Verdict = .neutral
    @State private var pickedBathroom: Bathroom?

    @State private var mood: Mood = .survivable
    @State private var cleanliness = 3.0
    @State private var waitMinutes = 0
    @State private var shareToFeed = true

    @State private var showEmojiPad = false
    @State private var showJokeBank = false
    @State private var blockReason: BlockReason?
    @State private var burst = 0
    /// Dictation is owned by the sheet, not the field, so mode switches and
    /// re-renders don't tear down a live recording.
    @State private var dictation = DictationController()
    @Namespace private var modeNS


    init(request: ComposerRequest) {
        self.request = request
        _mode = State(initialValue: request.mode)
        _pickedBathroom = State(initialValue: request.bathroom)
    }

    private var remaining: Int {
        LocalModerator.maxLength - text.count
    }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.canvas.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    dragHandle
                    modePicker

                    switch mode {
                    case .drop:   dropForm
                    case .review: reviewForm
                    }

                    submitButton
                    noPhotoNotice
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)

            if let reason = blockReason {
                blockBanner(reason)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }
        }
        .overlay(alignment: .center) {
            EmojiBurst(emojis: [emoji, "✨", "💨", "🚽", "💨"], trigger: burst)
                .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: blockReason)
        .onDisappear {
            // Release the mic and the audio session. Leaving a recording tap
            // installed after the sheet closes would keep the input node busy
            // and duck other audio for no reason.
            dictation.reset()
        }
        .onChange(of: dictation.error) { _, newValue in
            guard let newValue else { return }
            app.show(Toast(emoji: "🎙️", title: "Dictation", detail: newValue.message))
        }
    }

    // MARK: Chrome

    private var dragHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.18))
            .frame(width: 38, height: 5)
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(ComposerMode.allCases) { option in
                Button {
                    Haptics.select()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                        mode = option
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.icon).font(.system(size: 11, weight: .bold))
                        Text(option.label).font(.body(13, weight: .bold))
                    }
                    .foregroundStyle(mode == option ? Theme.night : Theme.inkDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if mode == option {
                            Capsule()
                                .fill(Theme.mint)
                                .matchedGeometryEffect(id: "composerMode", in: modeNS)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    private var noPhotoNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Photos and videos are blocked at the engine level. Emoji and words only.")
                .font(.body(11, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.inkFaint)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: Forms

    private var dropForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("What happened")
                        .font(.body(11, weight: .heavy))
                        .foregroundStyle(Theme.inkFaint)
                        .tracking(0.6)
                    Spacer()
                    Text("\(remaining)")
                        .font(.body(11, weight: .bold))
                        .foregroundStyle(remaining < 0 ? Theme.danger : Theme.inkFaint)
                        .contentTransition(.numericText(value: Double(remaining)))
                }

                editor(placeholder: "Post something funny about a bathroom…")

                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            showEmojiPad.toggle()
                            showJokeBank = false
                        }
                    } label: {
                        Label(emoji, systemImage: "face.smiling")
                            .font(.body(13, weight: .bold))
                            .foregroundStyle(showEmojiPad ? Theme.night : Theme.inkDim)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(showEmojiPad ? AnyShapeStyle(Theme.mint) : AnyShapeStyle(Color.white.opacity(0.07))))
                    }
                    .buttonStyle(PressableStyle())

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            showJokeBank.toggle()
                            showEmojiPad = false
                        }
                    } label: {
                        Label("Punchline", systemImage: "wand.and.stars")
                            .font(.body(13, weight: .bold))
                            .foregroundStyle(showJokeBank ? Theme.night : Theme.inkDim)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(showJokeBank ? AnyShapeStyle(Theme.grape) : AnyShapeStyle(Color.white.opacity(0.07))))
                    }
                    .buttonStyle(PressableStyle())

                    Spacer()

                    dictateButton
                }

                if showEmojiPad {
                    EmojiPad(selected: emoji) { picked in emoji = picked }
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                }

                if showJokeBank {
                    jokePicker
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            }

            verdictPicker
            bathroomPicker

            if !joke.isEmpty {
                jokePreview
            }
        }
        .glassCard(padding: 15)
    }

    private var reviewForm: some View {
        VStack(alignment: .leading, spacing: 15) {
            bathroomPicker

            VStack(alignment: .leading, spacing: 10) {
                Text("How was the experience?")
                    .font(.body(11, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
                    .tracking(0.6)

                HStack(spacing: 6) {
                    ForEach(Mood.allCases) { option in
                        Button {
                            Haptics.select()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { mood = option }
                        } label: {
                            VStack(spacing: 4) {
                                Text(option.emoji).font(.system(size: mood == option ? 27 : 21))
                                Text(option.label)
                                    .font(.body(9, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(mood == option ? Theme.mint.opacity(0.18) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(mood == option ? Theme.mint : Color.white.opacity(0.08),
                                                  lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(PressableStyle(scale: 0.9))
                    }
                }

                Text(mood.headline)
                    .font(.body(12, weight: .semibold))
                    .italic()
                    .foregroundStyle(Theme.mint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Cleanliness")
                        .font(.body(11, weight: .heavy))
                        .foregroundStyle(Theme.inkFaint)
                        .tracking(0.6)
                    Spacer()
                    Text("\(Int(cleanliness))/5")
                        .font(.body(12, weight: .bold))
                        .foregroundStyle(Theme.mint)
                        .contentTransition(.numericText(value: cleanliness))
                }
                Slider(value: $cleanliness, in: 1...5, step: 1)
                    .tint(Theme.mint)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Wait")
                    .font(.body(11, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
                    .tracking(0.6)
                Stepper(value: $waitMinutes, in: 0...60, step: 1) {
                    HStack {
                        Image(systemName: "clock").font(.system(size: 12, weight: .bold))
                        Text(Format.wait(waitMinutes))
                            .font(.body(13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }
                }
                .tint(Theme.mint)
            }

            verdictPicker

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Notes (optional)")
                        .font(.body(11, weight: .heavy))
                        .foregroundStyle(Theme.inkFaint)
                        .tracking(0.6)
                    Spacer()
                    dictateButton
                }
                editor(placeholder: "What should the next person know?")
                    .frame(minHeight: 76)
            }

            Toggle(isOn: $shareToFeed) {
                Text("Post to my feed too")
                    .font(.body(13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .toggleStyle(SwitchToggleStyle(tint: Theme.mint))

            if !joke.isEmpty {
                jokePreview
            }
        }
        .glassCard(padding: 15)
    }

    // MARK: Pieces

    /// Dictate instead of type.
    ///
    /// Note what this is *not* replacing: on iOS 27 the keyboard above this very
    /// field already offers Write with Siri and Type to Siri, and on every OS the
    /// keyboard's mic key dictates. Those are system features and need no code.
    /// This button is the floor beneath them — it works on iOS 17, on any device
    /// with a mic, and it runs the words through the LLM seam so they come out in
    /// the app's voice rather than raw.
    ///
    /// The composer deliberately keeps a plain `TextEditor` with no custom
    /// `inputView` or `inputAccessoryView`, which is what allows the system layer
    /// to work in the first place.
    private var dictateButton: some View {
        Button {
            Task { await toggleDictation() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: dictation.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 12, weight: .bold))
                    .symbolEffect(.variableColor.iterative, isActive: dictation.isListening)
                Text(dictation.isListening ? "Listening" : "Dictate")
                    .font(.body(12, weight: .bold))
            }
            .foregroundStyle(dictation.isListening ? Theme.night : Theme.inkDim)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                Capsule().fill(
                    dictation.isListening
                        ? AnyShapeStyle(Theme.mint)
                        : AnyShapeStyle(Color.white.opacity(0.07))
                )
            )
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(dictation.isListening ? "Stop dictating" : "Dictate text")
    }

    private func toggleDictation() async {
        if dictation.isListening {
            dictation.stop()
            await polishDictation()
        } else {
            await dictation.start()
        }
    }

    /// After the mic stops, run the raw words through the LLM seam.
    ///
    /// Never loses what was said: `VoiceText.polish` returns the raw transcript
    /// unchanged if every provider fails, and the result only replaces the field
    /// when it is non-empty.
    private func polishDictation() async {
        let spoken = dictation.transcript
        guard !spoken.isEmpty else { return }

        let polished = await VoiceText.polish(spoken, task: VoiceText.task(for: mode))
        guard !polished.text.isEmpty else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            text = polished.text
        }
        Haptics.success()

        app.show(Toast(
            emoji: "🎙️",
            title: "Polished",
            detail: polished.providerName.map { "Tidied up by \($0)." }
                ?? "Tidied up on device."
        ))
    }

    private func editor(placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(.body(15))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 96)
                .onChange(of: text) { _, newValue in
                    if newValue.count > LocalModerator.maxLength {
                        text = String(newValue.prefix(LocalModerator.maxLength))
                    }
                }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var verdictPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Satisfying?")
                .font(.body(11, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
                .tracking(0.6)
            HStack(spacing: 8) {
                ForEach(Verdict.allCases) { option in
                    Button {
                        Haptics.select()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) { verdict = option }
                    } label: {
                        HStack(spacing: 5) {
                            Text(option.emoji).font(.system(size: 13))
                            Text(option.label)
                                .font(.body(12, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(verdict == option ? Theme.night : Theme.inkDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(
                                verdict == option
                                ? AnyShapeStyle(verdict.tint)
                                : AnyShapeStyle(Color.white.opacity(0.06))
                            )
                        )
                    }
                    .buttonStyle(PressableStyle(scale: 0.93))
                }
            }
        }
    }

    @ViewBuilder
    private var bathroomPicker: some View {
        if !bathrooms.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Where")
                    .font(.body(11, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
                    .tracking(0.6)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            Haptics.tick()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pickedBathroom = nil }
                        } label: {
                            Text("No location")
                                .font(.body(12, weight: .bold))
                                .foregroundStyle(pickedBathroom == nil ? Theme.night : Theme.inkDim)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        pickedBathroom == nil
                                        ? AnyShapeStyle(Theme.mint)
                                        : AnyShapeStyle(Color.white.opacity(0.07))
                                    )
                                )
                        }
                        .buttonStyle(PressableStyle(scale: 0.93))

                        ForEach(bathrooms, id: \.id) { bathroom in
                            Button {
                                Haptics.tick()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    pickedBathroom = bathroom
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: bathroom.kind.icon)
                                        .font(.system(size: 10, weight: .bold))
                                    Text(bathroom.name)
                                        .font(.body(12, weight: .bold))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(pickedBathroom?.id == bathroom.id ? Theme.night : Theme.inkDim)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(
                                        pickedBathroom?.id == bathroom.id
                                        ? AnyShapeStyle(Theme.mint)
                                        : AnyShapeStyle(Color.white.opacity(0.07))
                                    )
                                )
                            }
                            .buttonStyle(PressableStyle(scale: 0.93))
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private var jokePreview: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                joke = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(PressableStyle(scale: 0.88))

            Text(joke)
                .font(.body(13, weight: .semibold))
                .italic()
                .foregroundStyle(Theme.ink.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.grape.opacity(0.10))
        )
    }

    @ViewBuilder
    private var jokePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pick a line")
                    .font(.body(11, weight: .heavy))
                    .foregroundStyle(Theme.inkFaint)
                    .tracking(0.6)
                Spacer()
                Button {
                    Haptics.pop()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        joke = JokeBank.randomAny().text
                    }
                } label: {
                    Label("Shuffle", systemImage: "arrow.clockwise")
                        .font(.body(11, weight: .bold))
                        .foregroundStyle(Theme.grape)
                }
                .buttonStyle(PressableStyle())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(JokeBank.lines(in: LineCategory.allCases.randomElement() ?? .victory)) { line in
                        Button {
                            Haptics.tick()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                joke = line.text
                            }
                        } label: {
                            Text(line.text)
                                .font(.body(12, weight: .semibold))
                                .italic()
                                .foregroundStyle(Theme.inkDim)
                                .lineLimit(2)
                                .frame(width: 180, alignment: .leading)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PressableStyle(scale: 0.96))
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private var submitButton: some View {
        GlowButton(
            title: mode == .review ? "Post review" : "Post drop",
            icon: "sparkles",
            gradient: Theme.hero
        ) {
            submit()
        }
    }

    private func blockBanner(_ reason: BlockReason) -> some View {
        HStack(spacing: 10) {
            Text(reason.emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(reason.title).font(.body(13, weight: .bold)).foregroundStyle(Theme.ink)
                Text(reason.detail).font(.body(11)).foregroundStyle(Theme.inkDim)
            }
            Spacer(minLength: 0)
            Button {
                blockReason = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.danger.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }

    // MARK: Submit

    private func submit() {
        guard let me = store.me() else { return }

        if mode == .review {
            guard let bathroom = pickedBathroom else {
                Haptics.warn()
                app.show(Toast(emoji: "📍", title: "Pick a bathroom",
                               detail: "Reviews need a place."))

                return
            }

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let check = Safety.moderator.validate(text: text)
                guard check.isAllowed else {
                    blockReason = check.reason
                    Haptics.warn()
                    return
                }
            }

            blockReason = nil
            burst += 1
            store.submitReview(
                bathroom: bathroom,
                author: me,
                mood: mood,
                cleanliness: Int(cleanliness),
                waitMinutes: waitMinutes,
                verdict: verdict,
                note: text,
                joke: joke,
                emoji: emoji,
                shareToFeed: shareToFeed
            )
            Haptics.success()
            app.show(Toast(emoji: emoji, title: "Review posted",
                           detail: "\(bathroom.name) · \(mood.label)"))
            dismiss()
            return
        }

        let check = Safety.moderator.validate(text: text)
        guard check.isAllowed else {
            blockReason = check.reason
            Haptics.warn()
            return
        }

        blockReason = nil
        burst += 1

        let created = store.createPost(
            author: me,
            body: text,
            emoji: emoji,
            joke: joke,
            surface: .drop,
            bathroom: pickedBathroom,
            verdict: verdict,
            backdrop: backdrop,
            vibe: vibe
        )

        if created != nil {
            Haptics.success()
            app.show(Toast(
                emoji: emoji,
                title: "Drop posted",
                detail: "Sent to your crew."
            ))
            dismiss()
        } else {
            blockReason = .empty
            Haptics.warn()
        }
    }
}
