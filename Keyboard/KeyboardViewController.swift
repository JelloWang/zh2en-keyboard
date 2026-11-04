import UIKit

/// 中译英自定义键盘主控制器
/// 布局：上方 = 拼音预览 + 中文候选栏 + 英文翻译区；下方 = QWERTY 键盘
final class KeyboardViewController: UIInputViewController {

    // MARK: - 输入状态
    private var composing = ""        // 正在输入的拼音字母
    private var committed = ""        // 本句已上屏的中文
    private var glosses: [String] = []   // 每个已上屏词的离线英文释义
    private var wordLengths: [Int] = []  // 已上屏每个词的字数（用于回删）
    private var candidates: [Candidate] = []
    private var numberMode = false
    private var shifted = false
    private var translateWork: DispatchWorkItem?

    private let composer = PinyinComposer()
    private let translator = TranslationService()

    // MARK: - UI
    private let pinyinLabel = UILabel()
    private let candidatesScroll = UIScrollView()
    private let candidatesStack = UIStackView()
    private let translationLabel = UILabel()
    private var rowsStack = UIStackView()
    private var shiftButton: UIButton?
    private var heightConstraint: NSLayoutConstraint?

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBanner()
        setupKeyboardRows()
        update()
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        if heightConstraint == nil {
            let c = NSLayoutConstraint(item: view!, attribute: .height, relatedBy: .equal,
                                       toItem: nil, attribute: .notAnAttribute,
                                       multiplier: 0, constant: 312)
            c.priority = UILayoutPriority(999)
            view!.addConstraint(c)
            heightConstraint = c
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        translateWork?.cancel()
    }

    // MARK: - 顶部区域：拼音预览 + 候选栏 + 英文翻译
    private func setupBanner() {
        pinyinLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        pinyinLabel.textColor = .secondaryLabel
        pinyinLabel.text = " "
        pinyinLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let clearButton = UIButton(type: .system)
        clearButton.setTitle("清空", for: .normal)
        clearButton.titleLabel?.font = .systemFont(ofSize: 12)
        clearButton.setTitleColor(.secondaryLabel, for: .normal)
        clearButton.contentEdgeInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        let topRow = UIStackView(arrangedSubviews: [pinyinLabel, clearButton])
        topRow.axis = .horizontal

        candidatesScroll.showsHorizontalScrollIndicator = false
        candidatesScroll.translatesAutoresizingMaskIntoConstraints = false
        candidatesStack.axis = .horizontal
        candidatesStack.spacing = 6
        candidatesStack.translatesAutoresizingMaskIntoConstraints = false
        candidatesScroll.addSubview(candidatesStack)
        NSLayoutConstraint.activate([
            candidatesStack.leadingAnchor.constraint(equalTo: candidatesScroll.contentLayoutGuide.leadingAnchor),
            candidatesStack.trailingAnchor.constraint(equalTo: candidatesScroll.contentLayoutGuide.trailingAnchor),
            candidatesStack.topAnchor.constraint(equalTo: candidatesScroll.contentLayoutGuide.topAnchor),
            candidatesStack.bottomAnchor.constraint(equalTo: candidatesScroll.contentLayoutGuide.bottomAnchor),
            candidatesStack.heightAnchor.constraint(equalTo: candidatesScroll.frameLayoutGuide.heightAnchor),
        ])

        translationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        translationLabel.textColor = .secondaryLabel
        translationLabel.numberOfLines = 2
        translationLabel.text = "英文翻译显示在这里"

        let banner = UIStackView(arrangedSubviews: [topRow, candidatesScroll, translationLabel])
        banner.axis = .vertical
        banner.spacing = 4
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            topRow.heightAnchor.constraint(equalToConstant: 20),
            candidatesScroll.heightAnchor.constraint(equalToConstant: 48),
            translationLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
        ])
    }

    // MARK: - 键盘按键区
    private func setupKeyboardRows() {
        rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 8
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: translationLabel.bottomAnchor, constant: 6),
            rowsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            rowsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            rowsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
        ])
        rebuildRows()
    }

    private func rebuildRows() {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        shiftButton = nil

        if numberMode {
            let r1 = keyRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
                            action: #selector(symbolTapped(_:)))
            let r2 = keyRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
                            action: #selector(symbolTapped(_:)))
            let abc = makeKey("ABC", action: #selector(modeTapped), fillColor: .systemGray4, fontSize: 14)
            let r3 = keyRow([".", ",", "?", "!", "'"],
                            action: #selector(symbolTapped(_:)),
                            prepend: [abc], append: [makeBackspace()])
            rowsStack.addArrangedSubview(r1)
            rowsStack.addArrangedSubview(r2)
            rowsStack.addArrangedSubview(r3)
        } else {
            let r1 = keyRow(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                            action: #selector(letterTapped(_:)))
            let r2 = keyRow(["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                            action: #selector(letterTapped(_:)))
            let shift = makeKey("⇧", action: #selector(shiftTapped), fillColor: .systemGray4, fontSize: 18)
            shiftButton = shift
            let r3 = keyRow(["z", "x", "c", "v", "b", "n", "m"],
                            action: #selector(letterTapped(_:)),
                            prepend: [shift], append: [makeBackspace()])
            let mode = makeKey("?123", action: #selector(modeTapped), fillColor: .systemGray4, fontSize: 14)
            let globe = makeKey("🌐", action: #selector(globeTapped), fillColor: .systemGray4, fontSize: 16)
            let space = makeKey("空格", action: #selector(spaceTapped), fillColor: .systemBackground, fontSize: 16)
            let ret = makeKey("确定", action: #selector(returnTapped), fillColor: .systemGray4, fontSize: 14)
            let r4 = UIStackView(arrangedSubviews: [mode, globe, space, ret])
            r4.axis = .horizontal
            r4.spacing = 6
            r4.distribution = .fillEqually
            r4.heightAnchor.constraint(equalToConstant: 42).isActive = true
            rowsStack.addArrangedSubview(r1)
            rowsStack.addArrangedSubview(r2)
            rowsStack.addArrangedSubview(r3)
            rowsStack.addArrangedSubview(r4)
        }
    }

    private func keyRow(_ letters: [String], action: Selector,
                        prepend: [UIButton] = [], append: [UIButton] = []) -> UIStackView {
        let row = UIStackView(arrangedSubviews: prepend + letters.map { makeKey($0, action: action) } + append)
        row.axis = .horizontal
        row.spacing = 6
        row.distribution = .fillEqually
        row.heightAnchor.constraint(equalToConstant: 42).isActive = true
        return row
    }

    private func makeKey(_ title: String, action: Selector,
                         fillColor: UIColor = .systemBackground, fontSize: CGFloat = 20) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: fontSize)
        b.setTitleColor(.label, for: .normal)
        b.backgroundColor = fillColor
        b.layer.cornerRadius = 6
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOffset = CGSize(width: 0, height: 1)
        b.layer.shadowOpacity = 0.12
        b.layer.shadowRadius = 0
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func makeBackspace() -> UIButton {
        makeKey("⌫", action: #selector(backspaceTapped), fillColor: .systemGray4, fontSize: 18)
    }

    private func makeCandidateButton(_ c: Candidate, tag: Int) -> UIButton {
        let b = UIButton(type: .system)
        b.tag = tag
        let text = NSMutableAttributedString(
            string: c.hanzi,
            attributes: [.font: UIFont.systemFont(ofSize: 16, weight: .medium),
                         .foregroundColor: UIColor.label])
        text.append(NSAttributedString(
            string: "\n" + c.english,
            attributes: [.font: UIFont.systemFont(ofSize: 10),
                         .foregroundColor: UIColor.secondaryLabel]))
        b.setAttributedTitle(text, for: .normal)
        b.titleLabel?.numberOfLines = 2
        b.titleLabel?.textAlignment = .center
        b.contentEdgeInsets = UIEdgeInsets(top: 2, left: 10, bottom: 2, right: 10)
        b.backgroundColor = .secondarySystemBackground
        b.layer.cornerRadius = 6
        b.addTarget(self, action: #selector(candidateTapped(_:)), for: .touchUpInside)
        return b
    }

    // MARK: - 刷新逻辑
    private func update() {
        pinyinLabel.text = composing.isEmpty ? " " : composing
        refreshCandidateButtons()
    }

    private func refreshCandidateButtons() {
        candidatesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !composing.isEmpty else {
            candidates = []
            return
        }
        candidates = composer.candidates(for: composing)
        if candidates.isEmpty {
            // 词库没命中：允许把字母原样上屏
            let b = makeCandidateButton(Candidate(hanzi: composing, english: "insert as-is"), tag: -1)
            candidatesStack.addArrangedSubview(b)
            return
        }
        for (i, c) in candidates.prefix(12).enumerated() {
            candidatesStack.addArrangedSubview(makeCandidateButton(c, tag: i))
        }
    }

    private func refreshTranslation() {
        if glosses.isEmpty {
            translationLabel.text = "英文翻译显示在这里"
            return
        }
        let offline = "EN: " + glosses.joined(separator: " ")
        if !hasFullAccess {
            translationLabel.text = offline + "　（在系统设置开启「允许完全访问」可在线翻译整句）"
            return
        }
        translationLabel.text = offline
        translateWork?.cancel()
        let text = committed
        let work = DispatchWorkItem { [weak self] in
            self?.translator.translate(text) { [weak self] result in
                guard let self = self, let en = result, self.committed == text else { return }
                self.translationLabel.text = "EN: \(en)　（在线）"
            }
        }
        translateWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func commit(_ c: Candidate) {
        textDocumentProxy.insertText(c.hanzi)
        committed += c.hanzi
        glosses.append(c.english)
        wordLengths.append(c.hanzi.count)
        composing = ""
        update()
        refreshTranslation()
    }

    // MARK: - 按键事件
    @objc private func letterTapped(_ sender: UIButton) {
        guard let t = sender.currentTitle else { return }
        if shifted {
            textDocumentProxy.insertText(t.uppercased())
            shifted = false
            updateShiftUI()
        } else {
            composing += t
            update()
        }
    }

    @objc private func shiftTapped() {
        shifted.toggle()
        updateShiftUI()
    }

    private func updateShiftUI() {
        shiftButton?.backgroundColor = shifted ? .systemBlue : .systemGray4
        shiftButton?.setTitleColor(shifted ? .white : .label, for: .normal)
    }

    @objc private func backspaceTapped() {
        if !composing.isEmpty {
            composing.removeLast()
            update()
        } else if let last = wordLengths.last {
            // 先回删已上屏的词，再删宿主 App 里的字符
            for _ in 0..<last { textDocumentProxy.deleteBackward() }
            wordLengths.removeLast()
            glosses.removeLast()
            committed = String(committed.dropLast(last))
            refreshTranslation()
        } else {
            textDocumentProxy.deleteBackward()
        }
    }

    @objc private func spaceTapped() {
        if let top = candidates.first {
            commit(top)
        } else {
            textDocumentProxy.insertText(" ")
        }
    }

    @objc private func returnTapped() { textDocumentProxy.insertText("\n") }

    @objc private func modeTapped() {
        numberMode.toggle()
        rebuildRows()
    }

    @objc private func globeTapped() { advanceToNextInputMode() }

    @objc private func symbolTapped(_ sender: UIButton) {
        textDocumentProxy.insertText(sender.currentTitle ?? "")
    }

    @objc private func candidateTapped(_ sender: UIButton) {
        if sender.tag < 0 {
            textDocumentProxy.insertText(composing)
            committed += composing
            glosses.append("(pinyin)")
            wordLengths.append(composing.count)
            composing = ""
            update()
            refreshTranslation()
            return
        }
        guard sender.tag < candidates.count else { return }
        commit(candidates[sender.tag])
    }

    @objc private func clearTapped() {
        committed = ""
        glosses.removeAll()
        wordLengths.removeAll()
        refreshTranslation()
    }
}
