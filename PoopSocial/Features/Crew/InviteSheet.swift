import SwiftUI

/// Add a friend by phone number or email address.
///
/// The flow is deliberately two-step — **enter**, then **consent** — because the
/// user is about to hand over a piece of someone else's personal data, and that
/// deserves an explicit, plain-English "here is exactly what happens" moment
/// before anything is written.
///
/// What the consent screen says is literally true, and each claim maps to
/// something enforced in code rather than policy:
///
/// * "we never store the number or address" → `Invite` has no field for it, and
///   `Store.invite(raw:)` hashes before inserting.
/// * "one-way, salted" → `ContactHasher`, proven by `ContactHasherTests`.
/// * "no contact book upload" → nothing here reads the address book at all.
@MainActor
struct InviteSheet: View {

    @Environment(AppModel.self) private var app
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var input = ""
    @State private var consent = false
    @State private var didInvite = false
    @FocusState private var focused: Bool

    /// Live validation, so the button state always matches reality instead of
    /// failing after a tap.
    private var parsed: (kind: ContactKind, hash: String)? {
        ContactHasher.hash(raw: input, salt: ContactHasher.salt())
    }

    private var alreadyInvited: Bool {
        !input.isEmpty && store.hasInvited(raw: input)
    }

    private var canSend: Bool {
        parsed != nil && consent && !alreadyInvited
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                BubbleBackdrop(tint: Theme.mint, secondary: Theme.sky)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        intro
                        entryField
                        if parsed != nil {
                            consentCard
                            previewCard
                        }
                        sendButton
                        footer
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .hidesNavigationBar()
            .safeAreaInset(edge: .top) { topBar }
            .onAppear { focused = true }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.glass))
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            Spacer()
            Text("Add a friend")
                .font(.body(15, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 8)
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Know their number or email?")
                .font(.display(22, weight: .black))
                .foregroundStyle(Theme.ink)
            Text("Send an invite straight to them. No address book, no contact upload.")
                .font(.body(12))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    // MARK: Entry

    private var entryField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NUMBER OR EMAIL")
                .font(.body(10, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
                .tracking(0.6)

            HStack(spacing: 9) {
                Image(systemName: parsed?.kind.icon ?? "at")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.mint)
                TextField("+1 415 555 0100 or maya@example.com", text: $input)
                    .font(.body(15, weight: .medium))
                    .emailKeyboard()
                    .noAutocapitalization()
                    .autocorrectionDisabled()
                    .focused($focused)
                if !input.isEmpty {
                    Button { input = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 13)
            .glassCard(padding: 0)

            if alreadyInvited {
                Label("You've already invited this contact.", systemImage: "checkmark.circle.fill")
                    .font(.body(11, weight: .semibold))
                    .foregroundStyle(Theme.lime)
            } else if !input.isEmpty && parsed == nil {
                Label("That doesn't look like a number or an email yet.", systemImage: "exclamationmark.triangle.fill")
                    .font(.body(11, weight: .semibold))
                    .foregroundStyle(Theme.tangerine)
            }
        }
    }

    // MARK: Consent — the point of the screen

    private var consentCard: some View {
        Button {
            Haptics.tick()
            consent.toggle()
        } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: consent ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(consent ? Theme.mint : Theme.inkFaint)

                VStack(alignment: .leading, spacing: 5) {
                    Text("I understand what happens next")
                        .font(.body(13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Your app will only store a one-way, salted code made from this contact. The number or address itself is never saved, never uploaded, and cannot be turned back into the original. Nobody — including us — can read it.")
                        .font(.body(11))
                        .foregroundStyle(Theme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(13)
            .glassCard(padding: 0)
        }
        .buttonStyle(PressableStyle(scale: 0.99))
    }

    // MARK: Preview — show the actual hash, so the claim is verifiable

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("WHAT ACTUALLY GETS SAVED")
                .font(.body(10, weight: .heavy))
                .foregroundStyle(Theme.inkFaint)
                .tracking(0.6)

            Text(parsed?.hash ?? "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.sky)
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Text("That's it. Compare it to your contact — you won't find them in there.")
                .font(.body(10))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(13)
        .glassCard(padding: 0)
    }

    // MARK: Send

    private var sendButton: some View {
        GlowButton(
            title: didInvite ? "Invite sent" : "Send invite",
            icon: didInvite ? "checkmark" : "paperplane.fill",
            gradient: Theme.hero,
            enabled: didInvite || canSend
        ) {
            send()
        }
    }

    private var footer: some View {
        Text("They'll show up in your crew the moment they join with that number or email.")
            .font(.body(11))
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
    }

    // MARK: Actions

    private func send() {
        guard canSend else { return }
        guard let invite = store.invite(raw: input) else { return }

        Haptics.success()
        didInvite = true
        app.show(Toast(
            emoji: invite.kind == .phone ? "📱" : "✉️",
            title: "Invite sent",
            detail: "Only a one-way code was stored."
        ))

        // Brief confirmation, then close — long enough to read, short enough
        // not to feel stuck.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { dismiss() }
    }
}
