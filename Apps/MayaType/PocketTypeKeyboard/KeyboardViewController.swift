import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum Layout { case letters, symbols }
    private enum Tone: String { case professional = "Professional", casual = "Casual" }

    private var layout: Layout = .letters
    private var isShifted = true
    private var tone: Tone = .professional
    private var isExpanded = false
    private var deleteTimer: Timer?
    private var lastInsertedText = ""
    private var rootStack: UIStackView?
    private var suggestionButtons: [UIButton] = []

    private let letterRows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]
    private let symbolRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        ["#", "+", "=", ".", ",", "?", "!", "'"]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = palette.background
        rebuildInterface()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopDeleting()
    }

    private var palette: (background: UIColor, panel: UIColor, key: UIColor, action: UIColor, accent: UIColor, text: UIColor) {
        (
            .systemGroupedBackground,
            .secondarySystemGroupedBackground,
            .secondarySystemBackground,
            .tertiarySystemFill,
            .systemTeal,
            .label
        )
    }

    private func rebuildInterface() {
        rootStack?.removeFromSuperview()
        view.backgroundColor = palette.background

        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 6
        root.isLayoutMarginsRelativeArrangement = true
        root.layoutMargins = UIEdgeInsets(top: 7, left: 7, bottom: 7, right: 7)
        root.backgroundColor = palette.background
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        rootStack = root

        let strip = makeCommandStrip()
        root.addArrangedSubview(strip)

        let keys = makeKeyboard()
        root.addArrangedSubview(keys)
    }

    private func makeCommandStrip() -> UIStackView {
        let strip = UIStackView()
        strip.axis = .vertical
        strip.spacing = 6
        strip.isLayoutMarginsRelativeArrangement = true
        strip.layoutMargins = UIEdgeInsets(top: 6, left: 4, bottom: 6, right: 4)
        strip.backgroundColor = palette.panel
        strip.layer.cornerRadius = 20
        strip.layer.cornerCurve = .continuous
        strip.layer.borderWidth = 1
        strip.layer.borderColor = palette.accent.withAlphaComponent(0.14).cgColor

        let status = UIStackView()
        status.axis = .horizontal
        status.spacing = 5
        status.alignment = .center
        status.addArrangedSubview(makeStripButton(title: "MAYA", action: #selector(toggleExpansion)))
        status.addArrangedSubview(makeStripButton(title: tone.rawValue, action: #selector(toggleTone)))
        let state = UILabel()
        state.text = isExpanded ? "MORE TOOLS" : "ON DEVICE"
        state.textColor = palette.accent
        state.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        state.textAlignment = .right
        status.addArrangedSubview(state)
        strip.addArrangedSubview(status)

        let suggestions = UIStackView()
        suggestions.axis = .horizontal
        suggestions.spacing = 5
        suggestions.distribution = .fillEqually
        suggestionButtons.removeAll()
        for (index, suggestion) in suggestionsForCurrentDraft().enumerated() {
            let button = makeSuggestionButton(title: suggestion.label, preview: suggestion.text, action: #selector(insertSuggestion(_:)))
            button.tag = index
            suggestions.addArrangedSubview(button)
            suggestionButtons.append(button)
        }
        strip.addArrangedSubview(suggestions)

        if isExpanded {
            let actions = UIStackView()
            actions.axis = .horizontal
            actions.spacing = 5
            actions.distribution = .fillEqually
            actions.addArrangedSubview(makeStripButton(title: "DEEP DIVE", action: #selector(refreshSuggestions)))
            actions.addArrangedSubview(makeStripButton(title: "REPHRASE", action: #selector(rephraseDraft)))
            actions.addArrangedSubview(makeStripButton(title: "SUMMARY", action: #selector(summarizeDraft)))
            if !lastInsertedText.isEmpty { actions.addArrangedSubview(makeStripButton(title: "UNDO", action: #selector(undoLastInsert))) }
            strip.addArrangedSubview(actions)
        }
        return strip
    }

    private func makeKeyboard() -> UIStackView {
        let keyboard = UIStackView()
        keyboard.axis = .vertical
        keyboard.spacing = 7
        let rows = layout == .letters ? letterRows : symbolRows
        for (index, row) in rows.enumerated() {
            let stack = makeRow()
            if index == 1 {
                stack.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
                stack.isLayoutMarginsRelativeArrangement = true
            }
            if index == 2 {
                stack.addArrangedSubview(makeActionKey(title: layout == .letters ? "⇧" : "#+=", action: layout == .letters ? #selector(toggleShift) : #selector(toggleLayout)))
            }
            for character in row { stack.addArrangedSubview(makeKey(title: displayed(character), action: #selector(insertCharacter(_:)))) }
            if index == 2 { stack.addArrangedSubview(makeDeleteKey()) }
            keyboard.addArrangedSubview(stack)
        }

        let bottom = makeRow()
        bottom.addArrangedSubview(makeActionKey(title: layout == .letters ? "123" : "ABC", action: #selector(toggleLayout)))
        if needsInputModeSwitchKey { bottom.addArrangedSubview(makeActionKey(title: "◎", action: #selector(UIInputViewController.advanceToNextInputMode))) }
        let space = makeKey(title: "space", action: #selector(insertSpace))
        space.widthAnchor.constraint(greaterThanOrEqualToConstant: 125).isActive = true
        space.addGestureRecognizer(UISwipeGestureRecognizer(target: self, action: #selector(acceptTopSuggestion(_:))))
        if let swipe = space.gestureRecognizers?.last as? UISwipeGestureRecognizer { swipe.direction = .up }
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleExpansion))
        doubleTap.numberOfTapsRequired = 2
        space.addGestureRecognizer(doubleTap)
        bottom.addArrangedSubview(space)
        let enter = makeActionKey(title: "return", action: #selector(insertReturn))
        enter.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(rephraseLongPress(_:))))
        bottom.addArrangedSubview(enter)
        keyboard.addArrangedSubview(bottom)
        return keyboard
    }

    private func makeRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 6
        row.distribution = .fillEqually
        return row
    }

    private func makeKey(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        apply(button: button, title: title, background: palette.key)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 46).isActive = true
        return button
    }

    private func makeActionKey(title: String, action: Selector) -> UIButton {
        let button = makeKey(title: title, action: action)
        button.configuration?.baseBackgroundColor = palette.action
        return button
    }

    private func makeStripButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        apply(button: button, title: title, background: palette.action, fontSize: 11)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 29).isActive = true
        return button
    }

    private func makeSuggestionButton(title: String, preview: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title + "\n" + preview
        configuration.baseForegroundColor = palette.text
        configuration.baseBackgroundColor = palette.key
        configuration.cornerStyle = .medium
        configuration.titleAlignment = .leading
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var copy = attributes
            copy.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
            return copy
        }
        button.configuration = configuration
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.separator.withAlphaComponent(0.22).cgColor
        button.layer.cornerRadius = 10
        button.layer.cornerCurve = .continuous
        button.heightAnchor.constraint(equalToConstant: isExpanded ? 48 : 36).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func apply(button: UIButton, title: String, background: UIColor, fontSize: CGFloat = 19) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseForegroundColor = palette.text
        configuration.baseBackgroundColor = background
        configuration.cornerStyle = .large
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var copy = attributes
            copy.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            return copy
        }
        button.configuration = configuration
        button.layer.cornerCurve = .continuous
    }

    private func makeDeleteKey() -> UIButton {
        let button = makeActionKey(title: "⌫", action: #selector(deleteBackward))
        button.addTarget(self, action: #selector(startDeleting), for: .touchDown)
        button.addTarget(self, action: #selector(stopDeleting), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }

    private func displayed(_ character: String) -> String {
        layout == .letters && !isShifted ? character.lowercased() : character
    }

    private func suggestionsForCurrentDraft() -> [(label: String, text: String)] {
        let draft = (textDocumentProxy.documentContextBeforeInput ?? "").lowercased()
        if draft.contains("?") || draft.contains("can you") || draft.contains("could you") {
            return tone == .professional
                ? [("CONFIRM", "Yes, that works for me."), ("CLARIFY", "Could you clarify the details?"), ("ACKNOWLEDGE", "Thank you. I will review this.")]
                : [("YES", "Yes, that works for me."), ("ASK", "Can you share a little more?"), ("THANKS", "Thanks, I appreciate it.")]
        }
        if draft.contains("meeting") || draft.contains("schedule") || draft.contains("calendar") {
            return tone == .professional
                ? [("SCHEDULE", "I am available to schedule a time."), ("CONFIRM", "That time works for me."), ("ALTERNATE", "Could we choose another time?")]
                : [("SCHEDULE", "I can make time for that."), ("YES", "That works for me."), ("ANOTHER TIME", "Can we pick another time?")]
        }
        if draft.count > 80 {
            return tone == .professional
                ? [("POLISH", "Thank you for the update. I will follow up shortly."), ("SUMMARY", "Here is the key point: "), ("ACKNOWLEDGE", "Received. Thank you.")]
                : [("POLISH", "Thanks for the update. I will follow up soon."), ("SUMMARY", "Quick summary: "), ("ACKNOWLEDGE", "Got it, thanks.")]
        }
        return tone == .professional
            ? [("REPLY", "Thank you. I will follow up shortly."), ("CLARIFY", "Could you clarify the details?"), ("ACKNOWLEDGE", "Received. Thank you.")]
            : [("REPLY", "Thanks, I will follow up soon."), ("ASK", "Can you share a little more?"), ("ACKNOWLEDGE", "Got it, thanks.")]
    }

    private func insertPreparedText(_ text: String) {
        textDocumentProxy.insertText(text)
        lastInsertedText = text
        let metricsKey = "mayaTypeAcceptedSuggestions"
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: metricsKey) + 1, forKey: metricsKey)
        rebuildInterface()
    }

    @objc private func insertCharacter(_ sender: UIButton) {
        guard let text = sender.configuration?.title else { return }
        textDocumentProxy.insertText(text)
        lastInsertedText = ""
        if layout == .letters && isShifted { isShifted = false }
        rebuildInterface()
    }

    @objc private func insertSuggestion(_ sender: UIButton) {
        let suggestions = suggestionsForCurrentDraft()
        guard suggestions.indices.contains(sender.tag) else { return }
        insertPreparedText(suggestions[sender.tag].text)
    }

    @objc private func acceptTopSuggestion(_ recognizer: UISwipeGestureRecognizer) {
        guard recognizer.state == .ended, let top = suggestionsForCurrentDraft().first else { return }
        insertPreparedText(top.text)
    }

    @objc private func toggleTone() { tone = tone == .professional ? .casual : .professional; rebuildInterface() }
    @objc private func toggleExpansion() { isExpanded.toggle(); rebuildInterface() }
    @objc private func refreshSuggestions() { rebuildInterface() }
    @objc private func toggleShift() { isShifted.toggle(); rebuildInterface() }
    @objc private func toggleLayout() { layout = layout == .letters ? .symbols : .letters; rebuildInterface() }
    @objc private func insertSpace() { textDocumentProxy.insertText(" "); lastInsertedText = ""; rebuildInterface() }
    @objc private func insertReturn() { textDocumentProxy.insertText("\n"); lastInsertedText = ""; rebuildInterface() }
    @objc private func deleteBackward() { textDocumentProxy.deleteBackward(); lastInsertedText = ""; rebuildInterface() }
    @objc private func startDeleting() {
        stopDeleting()
        deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { [weak self] _ in self?.textDocumentProxy.deleteBackward() }
    }
    @objc private func stopDeleting() { deleteTimer?.invalidate(); deleteTimer = nil }
    @objc private func undoLastInsert() {
        guard !lastInsertedText.isEmpty else { return }
        for _ in lastInsertedText { textDocumentProxy.deleteBackward() }
        lastInsertedText = ""
        rebuildInterface()
    }
    @objc private func rephraseLongPress(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began { rephraseDraft() }
    }
    @objc private func rephraseDraft() {
        let draft = textDocumentProxy.documentContextBeforeInput ?? ""
        guard !draft.isEmpty else { return }
        let replacement = tone == .professional ? "Thank you. " : "Thanks. "
        insertPreparedText(replacement)
    }
    @objc private func summarizeDraft() {
        let draft = textDocumentProxy.documentContextBeforeInput ?? ""
        guard !draft.isEmpty else { return }
        insertPreparedText(tone == .professional ? "Summary: " : "Quick summary: ")
    }
}
