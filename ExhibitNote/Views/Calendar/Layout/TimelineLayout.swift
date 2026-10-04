import Foundation

/// 時間が重なる項目をグループにまとめ、空いている表示列へ配置する。
enum TimelineLayout {
    struct Item<Value> {
        let value: Value
        let column: Int
    }

    struct Cluster<Value> {
        let items: [Item<Value>]
        let columnCount: Int
        let start: Date
        let end: Date
    }

    static func clusters<Value>(
        for values: [Value],
        start: KeyPath<Value, Date>,
        end: KeyPath<Value, Date>
    ) -> [Cluster<Value>] {
        let sorted = values.sorted { $0[keyPath: start] < $1[keyPath: start] }
        var active: [(end: Date, column: Int)] = []
        var items: [Item<Value>] = []
        var columnCount = 0
        var result: [Cluster<Value>] = []

        func finishCluster() {
            guard let first = items.first else { return }
            result.append(Cluster(
                items: items,
                columnCount: columnCount,
                start: first.value[keyPath: start],
                end: items.map { $0.value[keyPath: end] }.max()!
            ))
            items.removeAll()
            columnCount = 0
        }

        for value in sorted {
            // 終了と開始が同時刻の項目は重なりとして扱わない。
            active.removeAll { $0.end <= value[keyPath: start] }
            if active.isEmpty { finishCluster() }

            let usedColumns = Set(active.map(\.column))
            var column = 0
            while usedColumns.contains(column) { column += 1 }
            active.append((end: value[keyPath: end], column: column))
            items.append(Item(value: value, column: column))
            columnCount = max(columnCount, active.count)
        }
        finishCluster()
        return result
    }
}
