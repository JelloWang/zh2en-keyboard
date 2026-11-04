import Foundation

/// 在线整句翻译（MyMemory 免费 API，无需 Key，中→英）。
/// 键盘扩展只有在用户开启「允许完全访问」（RequestsOpenAccess）后才能联网。
/// 想换更高质量的翻译：把 translate 换成你自己的 API（如有道/百度/DeepL），改这个文件即可。
final class TranslationService {

    func translate(_ text: String, completion: @escaping (String?) -> Void) {
        var comps = URLComponents(string: "https://api.mymemory.translations.net/get")
        comps?.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "zh-CN|en-GB"),
        ]
        guard let url = comps?.url else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            var result: String?
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseData = json["responseData"] as? [String: Any],
               let translated = responseData["translatedText"] as? String {
                result = translated
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
}
