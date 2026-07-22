import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var host: UIHostingController<FloatingKeyboardView>?
    private lazy var bridge = KeyboardBridge(controller: self)

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 0, height: 292)
        let host = UIHostingController(rootView: FloatingKeyboardView(bridge: bridge))
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        let height = view.heightAnchor.constraint(equalToConstant: 292)
        height.priority = .defaultHigh
        height.isActive = true
        host.didMove(toParent: self)
        self.host = host
    }
}
