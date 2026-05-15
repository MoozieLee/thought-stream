import AppKit
import ThoughtStreamCore

struct CaptureResultRow: Sendable {
    let title: String
    let detail: String
    let highlightsTags: Bool
}

@MainActor
final class CaptureView: NSVisualEffectView {
    let textView = CaptureTextView()
    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onTextChange: ((String) -> Void)?
    var onRequestMoreTailResults: (() -> Bool)?

    private let compactPanelHeight: CGFloat = 78
    private let fieldHeight: CGFloat = 30
    private let cornerRadius: CGFloat = 28
    private let dragThreshold: CGFloat = 3
    private let resultsTopSpacing: CGFloat = 14
    private let resultsBottomSpacing: CGFloat = 18
    private let resultsSpacing: CGFloat = 8
    private let visibleTailRowCount: Int = 6
    private let baseTextColor = NSColor.labelColor
    private let tagTextColor = NSColor.controlAccentColor.blended(withFraction: 0.3, of: .labelColor) ?? .labelColor
    private let slashCommandTextColor = NSColor.systemOrange.blended(withFraction: 0.15, of: .labelColor) ?? .systemOrange
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
    private var isApplyingTagHighlighting = false
    private var selectedResultIndex: Int?
    private var resultRows: [CaptureResultRow] = []
    private var resultsHaveMore = false
    private var visibleResultStartIndex = 0

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
        textView.onResultSelectionMove = { [weak self] delta in
            self?.moveResultSelection(by: delta) ?? false
        }
        textView.delegate = self
        textView.font = NSFont.systemFont(ofSize: 22, weight: .regular)
        textView.textColor = baseTextColor
        textView.insertionPointColor = baseTextColor
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
        applySyntaxHighlighting()
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
        resultRows = []
        resultsHaveMore = false
        selectedResultIndex = nil
        visibleResultStartIndex = 0
        hideResults()
        applySyntaxHighlighting()
        updateChrome()
    }

    @objc private func clearText() {
        textView.string = ""
        autocompleteSuggestion = nil
        hideResults()
        applySyntaxHighlighting()
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
        applySyntaxHighlighting()
        updateChrome()
        focusTextInput()
        onTextChange?(textView.string)
    }

    func showResultRows(_ rows: [CaptureResultRow], hasMore: Bool, emptyStateText: String) {
        resultRows = rows
        resultsHaveMore = hasMore
        selectedResultIndex = rows.isEmpty ? nil : 0
        visibleResultStartIndex = 0
        renderResults(emptyStateText: emptyStateText)
    }

    func appendResultRows(_ rows: [CaptureResultRow], hasMore: Bool, emptyStateText: String) {
        if !rows.isEmpty {
            resultRows.append(contentsOf: rows)
        }
        resultsHaveMore = hasMore
        renderResults(emptyStateText: emptyStateText)
    }

    func hideResults() {
        guard showingResults else { return }
        clearResultRows()
        showingResults = false
        resultRows = []
        resultsHaveMore = false
        selectedResultIndex = nil
        visibleResultStartIndex = 0
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

    private func renderResults(emptyStateText: String) {
        clearResultRows()
        emptyStateLabel.stringValue = emptyStateText

        let visibleRows: ArraySlice<CaptureResultRow>
        if resultRows.isEmpty {
            visibleRows = []
        } else {
            let safeStart = min(visibleResultStartIndex, max(0, resultRows.count - 1))
            let end = min(safeStart + visibleTailRowCount, resultRows.count)
            visibleRows = resultRows[safeStart..<end]
        }

        for (offset, row) in visibleRows.enumerated() {
            let absoluteIndex = visibleRows.startIndex + offset
            let rowView = TailResultRowView(
                row: row,
                highlighted: absoluteIndex == selectedResultIndex
            )
            resultsStackView.addArrangedSubview(rowView)
        }

        let resultsHeight: CGFloat
        if visibleRows.isEmpty {
            resultsHeight = 84
        } else {
            let visibleCount = CGFloat(visibleRows.count)
            resultsHeight = visibleCount * 48 + max(0, visibleCount - 1) * resultsSpacing
        }

        showingResults = true
        dividerView.isHidden = false
        resultsContainer.isHidden = false
        resultsStackView.isHidden = visibleRows.isEmpty
        emptyStateLabel.isHidden = !visibleRows.isEmpty
        resultsContainerHeightConstraint?.constant = resultsHeight
        heightConstraint?.constant = compactPanelHeight + 1 + resultsTopSpacing + resultsHeight + resultsBottomSpacing
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func moveResultSelection(by delta: Int) -> Bool {
        guard showingResults else { return false }
        let hasInput = !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard !hasInput else { return false }
        guard !resultRows.isEmpty else { return false }

        let current = selectedResultIndex ?? 0
        var next = current + delta

        if delta > 0, next >= resultRows.count, resultsHaveMore {
            let loadedMore = onRequestMoreTailResults?() ?? false
            if loadedMore {
                next = current + delta
            }
        }

        next = min(max(next, 0), resultRows.count - 1)
        guard next != current || selectedResultIndex == nil else { return true }

        selectedResultIndex = next
        if next < visibleResultStartIndex {
            visibleResultStartIndex = next
        } else if next >= visibleResultStartIndex + visibleTailRowCount {
            visibleResultStartIndex = next - visibleTailRowCount + 1
        }
        renderResults(emptyStateText: emptyStateLabel.stringValue)
        return true
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

    private func applySyntaxHighlighting() {
        guard !isApplyingTagHighlighting else { return }
        guard let textStorage = textView.textStorage else { return }

        isApplyingTagHighlighting = true
        defer { isApplyingTagHighlighting = false }

        let selectedRange = textView.selectedRange()
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: textView.font ?? NSFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: baseTextColor,
            .backgroundColor: NSColor.clear
        ]

        textStorage.beginEditing()
        textStorage.setAttributes(baseAttributes, range: fullRange)
        for range in slashCommandHighlightRanges(in: textView.string) {
            textStorage.addAttributes(
                [.foregroundColor: slashCommandTextColor],
                range: range
            )
        }
        for range in tagHighlightRanges(in: textView.string, selectedRange: selectedRange) {
            textStorage.addAttributes(
                [.foregroundColor: tagTextColor],
                range: range
            )
        }
        textStorage.endEditing()

        textView.typingAttributes = baseAttributes
        textView.setSelectedRange(selectedRange)
    }

    private func slashCommandHighlightRanges(in text: String) -> [NSRange] {
        let trimmedLeading = text.drop(while: \.isWhitespace)
        guard trimmedLeading.first == "/" else { return [] }

        let knownCommands = ["/tail", "/search", "/today", "/tag", "/help", "/exit"]
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard let regex = try? NSRegularExpression(pattern: #"^\s*(/\S+)"#) else { return [] }
        guard let match = regex.firstMatch(in: text, range: fullRange), match.numberOfRanges > 1 else {
            return []
        }

        let commandRange = match.range(at: 1)
        guard commandRange.location != NSNotFound else { return [] }
        let command = nsText.substring(with: commandRange)
        let isKnownOrPrefix = knownCommands.contains(where: { $0 == command || $0.hasPrefix(command) })
        return isKnownOrPrefix ? [commandRange] : []
    }

    private func tagHighlightRanges(in text: String, selectedRange: NSRange) -> [NSRange] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let pattern = #"(?:(?<=^)|(?<=\s))(#(?:[\p{L}\p{N}_-]+))(?=$|[\s,.;:!?，。；：！？])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: fullRange).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { return nil }
            let intersectsSelection = NSIntersectionRange(range, selectedRange).length > 0
            let caretInside = selectedRange.length == 0 &&
                selectedRange.location >= range.location &&
                selectedRange.location <= range.location + range.length
            return (intersectsSelection || caretInside) ? nil : range
        }
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
        if !textView.hasMarkedText() {
            applySyntaxHighlighting()
        }
        updateChrome()
        onTextChange?(textView.string)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        if !textView.hasMarkedText() {
            applySyntaxHighlighting()
        }
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
    var onResultSelectionMove: ((Int) -> Bool)?

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
        case 125:
            if onResultSelectionMove?(1) == true {
                return
            }
            super.keyDown(with: event)
        case 126:
            if onResultSelectionMove?(-1) == true {
                return
            }
            super.keyDown(with: event)
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
    init(row: CaptureResultRow, highlighted: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: 0, height: 48))
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.cornerCurve = .continuous
        setHighlighted(highlighted)

        let titleLabel = NSTextField(
            labelWithAttributedString: row.highlightsTags ? Self.makeAttributedTitle(row.title) : NSAttributedString(
                string: row.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 18, weight: .medium),
                    .foregroundColor: NSColor.labelColor
                ]
            )
        )
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let metaLabel = NSTextField(labelWithString: row.detail)
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

    func setHighlighted(_ highlighted: Bool) {
        layer?.backgroundColor = (
            highlighted
                ? NSColor.controlBackgroundColor.withAlphaComponent(0.92)
                : NSColor.clear
        ).cgColor
    }

    private static func makeAttributedTitle(_ content: String) -> NSAttributedString {
        let baseFont = NSFont.systemFont(ofSize: 18, weight: .medium)
        let baseColor = NSColor.labelColor
        let tagColor = NSColor.controlAccentColor.blended(withFraction: 0.3, of: .labelColor) ?? .labelColor
        let attributed = NSMutableAttributedString(
            string: content,
            attributes: [
                .font: baseFont,
                .foregroundColor: baseColor
            ]
        )

        let nsContent = content as NSString
        let range = NSRange(location: 0, length: nsContent.length)
        let pattern = #"(?:(?<=^)|(?<=\s))(#(?:[\p{L}\p{N}_-]+))(?=$|[\s,.;:!?，。；：！？])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return attributed
        }

        for match in regex.matches(in: content, range: range) {
            guard match.numberOfRanges > 1 else { continue }
            let tagRange = match.range(at: 1)
            guard tagRange.location != NSNotFound else { continue }
            attributed.addAttribute(.foregroundColor, value: tagColor, range: tagRange)
        }

        return attributed
    }
}
