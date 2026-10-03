import SwiftUI

struct HomeSoonSectionView: View {
    @Binding var soonDays: Int
    let exhibitions: [Exhibition]
    @State private var showPicker = false

    var body: some View {
        Section {
            if exhibitions.isEmpty {
                ContentUnavailableView("該当する展示はありません", systemImage: "calendar.circle")
            } else {
                ForEach(Array(exhibitions.prefix(5))) { ex in
                    NavigationLink {
                        ExhibitionDetailView(exhibition: ex)
                    } label: {
                        ExhibitionRowView(ex: ex, distanceKm: nil)
                    }
                    .id("soon-\(ex.id)")
                }
            }

        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("まもなく終了")
                Spacer()
                // 現在の抽出日数を表示（任意）
                Text("\(soonDays)日以内")
                // アイコンからPickerを展開
                Menu {
                    Picker("抽出期間の選択", selection: $soonDays) {
                        Text("3日以内").tag(3)
                        Text("7日以内").tag(7)
                        Text("10日以内").tag(10)
                        Text("14日以内").tag(14)
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .menuStyle(.automatic)
            }
        }
    }
}
