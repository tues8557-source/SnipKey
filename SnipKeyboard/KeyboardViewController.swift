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
            deleteBackward: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            },
            moveCursor: { [weak self] offset in
                self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
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
}
