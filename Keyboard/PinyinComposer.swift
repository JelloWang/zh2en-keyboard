import Foundation

/// 词库条目（pinyin_dict.json 的结构）
/// h = 汉字词，p = 每个字的无调拼音，e = 英文释义
struct DictEntry: Codable {
    let h: String
    let p: [String]
    let e: String
}

struct Candidate {
    let hanzi: String
    let english: String
}

/// 拼音组词引擎：
/// 1) 全拼匹配   jin tian wan shang -> 今天晚上
/// 2) 声母简拼   jin tian wan s     -> 今天晚上（s = shang 首字母）
/// 3) 末音节部分匹配  jin ti        -> 今天（输入未打完时的实时联想）
final class PinyinComposer {

    private(set) var entries: [DictEntry] = []

    init() {
        // 词库 JSON 打包在键盘扩展的 Bundle 里
        if let url = Bundle.main.url(forResource: "pinyin_dict", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([DictEntry].self, from: data) {
            entries = list
        }
    }

    func candidates(for input: String) -> [Candidate] {
        let letters = Array(input.lowercased().filter { $0.isLetter })
        guard !letters.isEmpty else { return [] }

        var scored: [(score: Double, order: Int, candidate: Candidate)] = []

        // 第一轮：输入必须被词条音节完整消耗
        for (idx, entry) in entries.enumerated() {
            if let score = Self.matchAll(syllables: entry.p, input: letters) {
                scored.append((score, idx, Candidate(hanzi: entry.h, english: entry.e)))
            }
        }

        // 第二轮兜底：词条只对应输入的一部分（长词联想）
        if scored.isEmpty {
            for (idx, entry) in entries.enumerated() {
                if let score = Self.matchPrefix(syllables: entry.p, input: letters) {
                    scored.append((score - 10, idx, Candidate(hanzi: entry.h, english: entry.e)))
                }
            }
        }

        return scored.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.order < $1.order   // 同分保持词库顺序（=词频优先）
        }.map { $0.candidate }
    }

    // MARK: - 完整匹配（全拼 / 简拼 / 末音节截断）
    private static func matchAll(syllables: [String], input: [Character]) -> Double? {
        func rec(_ si: Int, _ ci: Int) -> Double? {
            if si == syllables.count { return ci == input.count ? 0 : nil }
            guard ci < input.count else { return nil }
            let s = Array(syllables[si])
            var best: Double?
            func consider(_ v: Double) {
                if best == nil || v < best! { best = v }
            }
            // 规则1：全拼匹配
            if input.count - ci >= s.count {
                var ok = true
                for k in 0..<s.count where input[ci + k] != s[k] { ok = false; break }
                if ok, let r = rec(si + 1, ci + s.count) { consider(r) }
            }
            // 规则2：声母简拼（单个字母 = 音节首字母）
            if input[ci] == s[0], let r = rec(si + 1, ci + 1) { consider(r + 1) }
            // 规则3：末音节部分匹配（用户还没打完）
            if si == syllables.count - 1, !s.isEmpty, input.count - ci < s.count {
                var ok = true
                for k in 0..<(input.count - ci) where input[ci + k] != s[k] { ok = false; break }
                if ok, let r = rec(si + 1, input.count) { consider(r + 0.5) }
            }
            return best
        }
        return rec(0, 0)
    }

    // MARK: - 前缀匹配（词条消耗不完输入也命中，用于长词联想）
    private static func matchPrefix(syllables: [String], input: [Character]) -> Double? {
        func rec(_ si: Int, _ ci: Int) -> Double? {
            if ci == input.count { return 0 }
            guard si < syllables.count else { return nil }
            let s = Array(syllables[si])
            var best: Double?
            func consider(_ v: Double) {
                if best == nil || v < best! { best = v }
            }
            if input.count - ci >= s.count {
                var ok = true
                for k in 0..<s.count where input[ci + k] != s[k] { ok = false; break }
                if ok, let r = rec(si + 1, ci + s.count) { consider(r) }
            }
            if input[ci] == s[0], let r = rec(si + 1, ci + 1) { consider(r + 1) }
            if si == syllables.count - 1, !s.isEmpty, input.count - ci < s.count {
                var ok = true
                for k in 0..<(input.count - ci) where input[ci + k] != s[k] { ok = false; break }
                if ok, let r = rec(si + 1, input.count) { consider(r + 0.5) }
            }
            return best
        }
        return rec(0, 0)
    }
}
