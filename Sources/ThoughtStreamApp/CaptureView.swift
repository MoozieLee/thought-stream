import AppKit
import ThoughtStreamCore

@MainActor
final class CaptureView: NSVisualEffectView {
    let textView = CaptureTextView()
    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onTextChange: ((String) -> Void)?

    private let compactPanelHeight: CGFloat = 78
    private let fieldHeight: CGFloat = 30
    private let cornerRadius: CGFloat = 28
    private let dragThreshold: CGFloat = 3
    private let resultsTopSpacing: CGFloat = 14
    private let resultsBottomSpacing: CGFloat = 18
    private let resultsSpacing: CGFloat = 8
    private let searchIconView: PassthroughImageView = {
        let imageView = PassthroughImageView()
        imageView.image = NSImage(
            systemSymbolName: "sparkles",
            accessibilityDescription: "Thought"
        )?.withSymbolConfiguration(.init(pointSize: 20, weight: .regular))
        imageView.contentTintColor = NSColor.secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        return imageView
    }()

    private let placeholderLabel: PassthroughTextField = {
        let label = PassthroughTextField(labelWithString: "Capture a thought")
        label.textColor = NSColor.secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 22, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let autocompleteGhostLabel: PassthroughTextField = {
        let label = PassthroughTextField(labelWithString: "")
        label.textColor = NSColor.tertiaryLabelColor
        label.font = NSFont.systemFont(ofSize: 22, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private let clearButton: NSButton = {
        let button = NSButton()
        button.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "Clear"
        )?.withSymbolConfiguration(.init(pointSize: 15, weight: .regular))
        button.isBordered = false
        button.contentTintColor = NSColor.tertiaryLabelColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.alphaValue = 0
        button.isHidden = true
        button.setButtonType(.momentaryChange)
        return button
    }()

    private let dividerView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let resultsContainer: NSView = {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let resultsStackView: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let emptyStateLabel: NSTextField = {
        let label = NSTextField(labelWithString: "No notes yet")
        label.textColor = NSColor.secondaryLabelColor
        label.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private var heightConstraint: NSLayoutConstraint?
    private var resultsContainerHeightConstraint: NSLayoutConstraint?
    private var showingResults = false
    private var autocompleteSuggestion: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 0
        layer?.backgroundColor = NSColor.clear.cgColor

        textView.captureDelegate = self
        textView.onEditingStateChange = { [weak self] in
            self?.updateChrome()
        }
        textView.onBackgroundMouseDown = { [weak self] event in
            self?.handlePotentialWindowDrag(with: event, focusAfterClick: true)
        }
        textView.onAutocompleteRequest = { [weak self] in
            self?.applyAutocompleteSuggestionIfNeeded() ?? false
        }
        textView.delegate = self
        textView.font = NSFont.systemFont(ofSize: 22, weight: .regular)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: 120)
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true

        let inputScrollView = NSScrollView()
        inputScrollView.drawsBackground = false
        inputScrollView.hasVerticalScroller = false
        inputScrollView.hasHorizontalScroller = false
        inputScrollView.borderType = .noBorder
        inputScrollView.documentView = textView
        inputScrollView.translatesAutoresizingMaskIntoConstraints = false

        let textContainer = NSView()
        textContainer.translatesAutoresizingMaskIntoConstraints = false
        textContainer.addSubview(autocompleteGhostLabel)
        textContainer.addSubview(inputScrollView)
        textContainer.addSubview(placeholderLabel)

        resultsContainer.addSubview(resultsStackView)
        resultsContainer.addSubview(emptyStateLabel)
        resultsStackView.spacing = resultsSpacing

        clearButton.target = self
        clearButton.action = #selector(clearText)

        addSubview(searchIconView)
        addSubview(textContainer)
        addSubview(dividerView)
        addSubview(resultsContainer)
        addSubview(clearButton)

        let heightConstraint = heightAnchor.constraint(equalToConstant: compactPanelHeight)
        self.heightConstraint = heightConstraint
        let resultsHeightConstraint = resultsContainer.heightAnchor.constraint(equalToConstant: 0)
        self.resultsContainerHeightConstraint = resultsHeightConstraint

        NSLayoutConstraint.activate([
            heightConstraint,

            searchIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            searchIconView.topAnchor.constraint(equalTo: topAnchor, constant: 27),
            searchIconView.widthAnchor.constraint(equalToConstant: 24),
            searchIconView.heightAnchor.constraint(equalToConstant: 24),

            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            clearButton.topAnchor.constraint(equalTo: topAnchor, constant: 29),
            clearButton.widthAnchor.constraint(equalToConstant: 20),
            clearButton.heightAnchor.constraint(equalToConstant: 20),

            textContainer.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 18),
            textContainer.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -14),
            textContainer.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            textContainer.heightAnchor.constraint(equalToConstant: fieldHeight),

            inputScrollView.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            inputScrollView.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            inputScrollView.topAnchor.constraint(equalTo: textContainer.topAnchor),
            inputScrollView.heightAnchor.constraint(equalToConstant: fieldHeight),

            autocompleteGhostLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            autocompleteGhostLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            autocompleteGhostLabel.centerYAnchor.constraint(equalTo: textContainer.centerYAnchor),

            placeholderLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: textContainer.trailingAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: textContainer.centerYAnchor),

            dividerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            dividerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            dividerView.topAnchor.constraint(equalTo: topAnchor, constant: compactPanelHeight),
            dividerView.heightAnchor.constraint(equalToConstant: 1),

            resultsContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            resultsContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            resultsContainer.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: resultsTopSpacing),
            resultsHeightConstraint,

            resultsStackView.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor),
            resultsStackView.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor),
            resultsStackView.topAnchor.constraint(equalTo: resultsContainer.topAnchor),

            emptyStateLabel.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: resultsContainer.centerYAnchor)
        ])

        updateChrome()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        guard let layer else { return }
        let mask = CAShapeLayer()
        mask.path = CGPath(
            roundedRect: bounds,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        layer.mask = mask
        layer.backgroundColor = NSColor.clear.cgColor
    }

    func reset() {
        textView.string = ""
        autocompleteSuggestion = nil
        hideResults()
        updateChrome()
    }

    @objc private func clearText() {
        textView.string = ""
        autocompleteSuggestion = nil
        hideResults()
        updateChrome()
        focusTextInput()
        onTextChange?(textView.string)
    }

    func clearInput(keepResults: Bool) {
        textView.string = ""
        autocompleteSuggestion = nil
        if !keepResults {
            hideResults()
        }
        updateChrome()
        focusTextInput()
        onTextChange?(textView.string)
    }

    func showTailResults(_ thoughts: [Thought]) {
        clearResultRows()

        let visibleThoughts = thoughts
        for (index, thought) in visibleThoughts.enumerated() {
            let rowView = TailResultRowView(thought: thought, highlighted: index == 0)
            resultsStackView.addArrangedSubview(rowView)
        }

        let resultsHeight: CGFloat
        if visibleThoughts.isEmpty {
            resultsHeight = 84
        } else {
            layoutSubtreeIfNeeded()
            resultsHeight = resultsStackView.fittingSize.height
        }

        showingResults = true
        dividerView.isHidden = false
        resultsContainer.isHidden = false
        resultsStackView.isHidden = visibleThoughts.isEmpty
        emptyStateLabel.isHidden = !visibleThoughts.isEmpty
        resultsContainerHeightConstraint?.constant = resultsHeight
        heightConstraint?.constant = compactPanelHeight + 1 + resultsTopSpacing + resultsHeight + resultsBottomSpacing
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    func hideResults() {
        guard showingResults else { return }
        clearResultRows()
        showingResults = false
        dividerView.isHidden = true
        resultsContainer.isHidden = true
        resultsStackView.isHidden = true
        emptyStateLabel.isHidden = true
        resultsContainerHeightConstraint?.constant = 0
        heightConstraint?.constant = compactPanelHeight
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    var isShowingResults: Bool {
        showingResults
    }

    var preferredPanelHeight: CGFloat {
        heightConstraint?.constant ?? compactPanelHeight
    }

    func setAutocompleteSuggestion(_ suggestion: String?) {
        autocompleteSuggestion = suggestion
        updateChrome()
    }

    @discardableResult
    func applyAutocompleteSuggestionIfNeeded() -> Bool {
        guard let suggestion = autocompleteSuggestion else { return false }
        textView.string = suggestion
        textView.setSelectedRange(NSRange(location: suggestion.utf16.count, length: 0))
        updateChrome()
        onTextChange?(suggestion)
        return true
    }

    private func clearResultRows() {
        resultsStackView.arrangedSubviews.forEach { view in
            resultsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func updateChrome() {
        let hasCommittedText = !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMarkedText = textView.hasMarkedText()
        let shouldHidePlaceholder = hasCommittedText || hasMarkedText
        let currentText = textView.string
        let shouldShowAutocomplete = {
            guard
                let suggestion = autocompleteSuggestion,
                !suggestion.isEmpty,
                suggestion != currentText,
                suggestion.hasPrefix(currentText),
                !hasMarkedText
            else {
                return false
            }
            return true
        }()

        placeholderLabel.isHidden = shouldHidePlaceholder
        clearButton.isHidden = !hasCommittedText
        clearButton.alphaValue = hasCommittedText ? 1 : 0
        autocompleteGhostLabel.isHidden = !shouldShowAutocomplete
        autocompleteGhostLabel.stringValue = shouldShowAutocomplete ? (autocompleteSuggestion ?? "") : ""
        needsLayout = true
    }

    private func focusTextInput() {
        window?.makeFirstResponder(textView)
        let end = textView.string.utf16.count
        textView.setSelectedRange(NSRange(location: end, length: 0))
    }

    override func mouseDown(with event: NSEvent) {
        handlePotentialWindowDrag(with: event, focusAfterClick: true)
    }

    private func handlePotentialWindowDrag(with event: NSEvent, focusAfterClick: Bool) {
        guard let window else { return }

        let initialMouseLocation = window.convertPoint(toScreen: event.locationInWindow)
        let initialOrigin = window.frame.origin
        var didDrag = false

        while let nextEvent = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            switch nextEvent.type {
            case .leftMouseDragged:
                let currentMouseLocation = window.convertPoint(toScreen: nextEvent.locationInWindow)
                let deltaX = currentMouseLocation.x - initialMouseLocation.x
                let deltaY = currentMouseLocation.y - initialMouseLocation.y
                let distance = hypot(deltaX, deltaY)

                if distance >= dragThreshold {
                    didDrag = true
                    window.setFrameOrigin(NSPoint(x: initialOrigin.x + deltaX, y: initialOrigin.y + deltaY))
                }
            case .leftMouseUp:
                if !didDrag, focusAfterClick {
                    focusTextInput()
                }
                return
            default:
                break
            }
        }
    }
}

extension CaptureView: CaptureTextViewDelegate, NSTextViewDelegate {
    func captureTextViewDidSubmit(_ textView: CaptureTextView) {
        onSubmit?(textView.string)
    }

    func captureTextViewDidCancel(_ textView: CaptureTextView) {
        onCancel?()
    }

    func textDidChange(_ notification: Notification) {
        updateChrome()
        onTextChange?(textView.string)
    }
}

@MainActor
protocol CaptureTextViewDelegate: AnyObject {
    func captureTextViewDidSubmit(_ textView: CaptureTextView)
    func captureTextViewDidCancel(_ textView: CaptureTextView)
}

@MainActor
final class CaptureTextView: NSTextView {
    weak var captureDelegate: CaptureTextViewDelegate?
    var onEditingStateChange: (() -> Void)?
    var onBackgroundMouseDown: ((NSEvent) -> Void)?
    var onAutocompleteRequest: (() -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticTextCompletionEnabled = false
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        onEditingStateChange?()
    }

    override func unmarkText() {
        super.unmarkText()
        onEditingStateChange?()
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 36:
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)
            } else {
                captureDelegate?.captureTextViewDidSubmit(self)
            }
        case 48:
            if onAutocompleteRequest?() == true {
                return
            }
            super.keyDown(with: event)
        case 53:
            captureDelegate?.captureTextViewDidCancel(self)
        default:
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if isPointOverExistingText(location) {
            super.mouseDown(with: event)
        } else {
            onBackgroundMouseDown?(event)
        }
    }

    private func isPointOverExistingText(_ point: NSPoint) -> Bool {
        guard
            let textContainer,
            let layoutManager,
            layoutManager.numberOfGlyphs > 0
        else {
            return false
        }

        let containerPoint = NSPoint(
            x: point.x - textContainerInset.width,
            y: point.y - textContainerInset.height
        )

        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        guard glyphIndex < layoutManager.numberOfGlyphs else {
            return false
        }

        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )

        guard glyphRect.contains(containerPoint) else {
            return false
        }

        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex < string.utf16.count else {
            return false
        }

        let nsString = string as NSString
        let characterRange = nsString.rangeOfComposedCharacterSequence(at: characterIndex)
        let fragment = nsString.substring(with: characterRange)
        return !fragment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
final class PassthroughImageView: NSImageView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

@MainActor
final class PassthroughTextField: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

@MainActor
final class TailResultRowView: NSView {
    init(thought: Thought, highlighted: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 48))
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = (
            highlighted
                ? NSColor.controlBackgroundColor.withAlphaComponent(0.92)
                : NSColor.clear
        ).cgColor

        let titleLabel = NSTextField(labelWithString: thought.content)
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let metaLabel = NSTextField(labelWithString: Self.metaFormatter.string(from: thought.createdAt))
        metaLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        metaLabel.textColor = .secondaryLabelColor
        metaLabel.alignment = .right
        metaLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        metaLabel.setContentHuggingPriority(.required, for: .horizontal)
        metaLabel.lineBreakMode = .byTruncatingTail
        metaLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(metaLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 48),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            metaLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 14),
            metaLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            metaLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let metaFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
