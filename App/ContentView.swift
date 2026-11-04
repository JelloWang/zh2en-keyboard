import SwiftUI
import UIKit

struct ContentView: View {
    @State private var demoText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("① 添加键盘（首次必须做）") {
                    Text("1. 打开 设置 → 通用 → 键盘 → 键盘\n2. 点「添加新键盘…」→ 选「中译英键盘」\n3. 点键盘列表里的「中译英键盘」→ 打开「允许完全访问」")
                        .font(.footnote)
                    Link("打开本 App 的系统设置", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
                Section("② 怎么用") {
                    Text("在任意输入框切到「中译英」键盘：\n· 打拼音 → 上方候选栏选中文词\n· 下方自动显示英文翻译\n· 空格键直接上屏第一个候选词\n· 点「清空」重新翻译一句新话")
                        .font(.footnote)
                }
                Section("③ 试用") {
                    TextField("点我，切到中译英键盘试试", text: $demoText)
                }
            }
            .navigationTitle("中译英键盘")
        }
    }
}
