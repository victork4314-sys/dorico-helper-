#if os(macOS)
import Combine
import Foundation

@MainActor
final class ControllerKeyboardState: ObservableObject {
    enum Purpose: String {
        case searchCommands
        case typeIntoDorico
        case runJumpBar
        case mapJumpBar

        var title: String {
            switch self {
            case .searchCommands: "Search Dorico commands"
            case .typeIntoDorico: "Type into Dorico"
            case .runJumpBar: "Run a Dorico Jump Bar command"
            case .mapJumpBar: "Create a Jump Bar controller mapping"
            }
        }

        var prompt: String {
            switch self {
            case .searchCommands: "Enter text used to filter the complete command list."
            case .typeIntoDorico: "Enter text for the currently open Dorico field or popover."
            case .runJumpBar: "Enter a Dorico Jump Bar command. The bridge opens Commands mode and runs it."
            case .mapJumpBar: "Enter a Jump Bar command, then choose the Xbox input that should run it."
            }
        }
    }

    @Published var isVisible = false
    @Published var purpose: Purpose = .searchCommands
    @Published var text = ""
    @Published var selectedIndex = 0
    @Published var pageIndex = 0

    let columns = 10

    private let pages: [[String]] = [
        Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init) +
            Array("0123456789").map(String.init) +
            ["#", "♭", "♯", "+", "-", ".", ",", "/", "(", ")", "[", "]", "<", ">", "=", ":", ";", "'", "\"", "_"],
        Array("abcdefghijklmnopqrstuvwxyz").map(String.init) +
            Array("0123456789").map(String.init) +
            ["#", "b", "+", "-", ".", ",", "/", "(", ")", "[", "]", "<", ">", "=", ":", ";", "'", "\"", "_", "@"],
        [
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
            "#", "♭", "♯", "𝄪", "𝄫", "+", "-", "×", "÷", "=",
            ".", ",", ":", ";", "!", "?", "'", "\"", "_", "@",
            "(", ")", "[", "]", "{", "}", "<", ">", "/", "\\",
            "%", "&", "*", "^", "~", "|", "°", "→", "←", "·"
        ]
    ]

    var keys: [String] { pages[pageIndex] }

    var pageName: String {
        switch pageIndex {
        case 0: "Uppercase and music"
        case 1: "Lowercase"
        default: "Symbols"
        }
    }

    var selectedKey: String {
        guard keys.indices.contains(selectedIndex) else { return "" }
        return keys[selectedIndex]
    }

    func open(_ purpose: Purpose, initialText: String = "") {
        self.purpose = purpose
        text = initialText
        selectedIndex = 0
        pageIndex = 0
        isVisible = true
    }

    func close() {
        isVisible = false
        selectedIndex = 0
    }

    func move(horizontal: Int, vertical: Int) {
        let count = keys.count
        guard count > 0 else { return }
        let rows = Int(ceil(Double(count) / Double(columns)))
        let row = selectedIndex / columns
        let column = selectedIndex % columns
        let nextRow = (row + vertical + rows) % rows
        let nextColumn = (column + horizontal + columns) % columns
        var candidate = nextRow * columns + nextColumn
        if candidate >= count {
            candidate = min(count - 1, nextRow * columns + min(column, max(0, count - nextRow * columns - 1)))
        }
        selectedIndex = max(0, min(count - 1, candidate))
    }

    func insertSelectedKey() {
        text.append(selectedKey)
    }

    func insertSpace() {
        text.append(" ")
    }

    @discardableResult
    func deleteOrClose() -> Bool {
        if text.isEmpty {
            close()
            return true
        }
        text.removeLast()
        return false
    }

    func nextPage() {
        pageIndex = (pageIndex + 1) % pages.count
        selectedIndex = min(selectedIndex, max(0, keys.count - 1))
    }
}
#endif
