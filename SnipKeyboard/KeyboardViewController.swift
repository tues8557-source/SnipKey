//
//  KeyboardViewController.swift
//  SnipKeyboard
//
//  Clipboard-first controller for the personal SnipKey fork.
//

import SwiftData
import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<AnyView>?
    private var modelContainer: ModelContainer?
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        installClipboardKeyboard()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: any UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate { [weak self] _ in
            self?.updatePreferredHeight(for: size)
        }
    }

    private func installClipboardKeyboard() {
        let container = SnipKeyDataManager().makeSharedContainer()
        modelContainer = container

        let keyboard = KeyboardView(
            insertText: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            advanceToNextInputMode: { [weak self] in
                self?.advanceToNextInputMode()
            },
            deleteBackward: { [weak self] command in
                self?.deleteBackward(command)
            },
            moveCursor: { [weak self] command in
                self?.moveCursor(command)
            },
            insertReturn: { [weak self] in
                self?.textDocumentProxy.insertText("\n")
            }
        )
        .modelContainer(container)

        let host = UIHostingController(rootView: AnyView(keyboard))
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear

        addChild(host)
        view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        host.didMove(toParent: self)
        hostingController = host

        let initialHeight = preferredKeyboardHeight(for: view.bounds.size)
        let constraint = view.heightAnchor.constraint(equalToConstant: initialHeight)
        constraint.priority = .defaultHigh
        constraint.isActive = true
        heightConstraint = constraint
    }

    private func updatePreferredHeight(for size: CGSize) {
        heightConstraint?.constant = preferredKeyboardHeight(for: size)
        view.setNeedsLayout()
    }

    private func preferredKeyboardHeight(for size: CGSize) -> CGFloat {
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let isLandscape = size.width > size.height && size.height > 0

        if isPad {
            return isLandscape ? 330 : 370
        }

        return isLandscape ? 250 : 340
    }

    private func moveCursor(_ command: CursorMoveCommand) {
        switch command {
        case .character(let offset):
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        case .word(let direction):
            textDocumentProxy.adjustTextPosition(byCharacterOffset: wordOffset(direction: direction))
        case .line(let direction):
            textDocumentProxy.adjustTextPosition(byCharacterOffset: lineOffset(direction: direction))
        }
    }

    private func deleteBackward(_ command: DeleteCommand) {
        let count: Int
        switch command {
        case .character(let value):
            count = max(1, value)
        case .word:
            count = backwardWordDeleteCount()
        case .line:
            count = backwardLineDeleteCount()
        }

        for _ in 0..<count {
            textDocumentProxy.deleteBackward()
        }
    }

    private func wordOffset(direction: Int) -> Int {
        if direction < 0 {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            return -backwardWordDeleteCount(in: before)
        }

        let after = textDocumentProxy.documentContextAfterInput ?? ""
        guard !after.isEmpty else { return 0 }

        let characters = Array(after)
        var index = 0
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
        while index < characters.count, !characters[index].isWhitespace {
            index += 1
        }
        return max(1, index)
    }

    private func lineOffset(direction: Int) -> Int {
        if direction < 0 {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            guard !before.isEmpty else { return 0 }
            if let lastNewline = before.lastIndex(of: "\n") {
                let lineStart = before.index(after: lastNewline)
                return -before.distance(from: lineStart, to: before.endIndex)
            }
            return -before.count
        }

        let after = textDocumentProxy.documentContextAfterInput ?? ""
        guard !after.isEmpty else { return 0 }
        if let nextNewline = after.firstIndex(of: "\n") {
            return after.distance(from: after.startIndex, to: nextNewline)
        }
        return after.count
    }

    private func backwardWordDeleteCount() -> Int {
        backwardWordDeleteCount(in: textDocumentProxy.documentContextBeforeInput ?? "")
    }

    private func backwardWordDeleteCount(in text: String) -> Int {
        guard !text.isEmpty else { return 1 }

        let characters = Array(text)
        var index = characters.count
        while index > 0, characters[index - 1].isWhitespace {
            index -= 1
        }
        while index > 0, !characters[index - 1].isWhitespace {
            index -= 1
        }

        return max(1, characters.count - index)
    }

    private func backwardLineDeleteCount() -> Int {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard !before.isEmpty else { return 1 }
        if let lastNewline = before.lastIndex(of: "\n") {
            let lineStart = before.index(after: lastNewline)
            return max(1, before.distance(from: lineStart, to: before.endIndex))
        }
        return max(1, before.count)
    }
}
