import Observation
import QuartzCore
import SwiftUI

@Observable
final class BenchRow: Identifiable {
    let id: Int
    var label: String
    var done: Bool

    init(id: Int) {
        self.id = id
        label = "Row \(id)"
        done = id.isMultiple(of: 3)
    }
}

@Observable
final class BenchEntry: Identifiable {
    let id: Int
    var title: String
    let body: String

    init(id: Int) {
        self.id = id
        title = "Entry \(id)"
        body = "The meaning of entry \(id), with a few more words to wrap."
    }
}

@Observable
final class BenchModel {
    var rows: Array<BenchRow> = []
    var page = false
    var entries: Array<BenchEntry> = []
    var status = "Starting"
    var text = ""
    @ObservationIgnored private var nextID = 1
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private var lastTick: CFTimeInterval = 0
    @ObservationIgnored private var maxGap: Double = 0

    func makeRows(_ count: Int) -> Array<BenchRow> {
        var created: Array<BenchRow> = []
        for _ in 0..<count {
            created.append(BenchRow(id: nextID))
            nextID += 1
        }
        return created
    }

    func run() async {
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
        try? await Task.sleep(for: .seconds(1))
        await measure("create") { self.rows = self.makeRows(1000) }
        await measure("update-all") { for row in self.rows { row.label += "!" } }
        await measure("update-one") { self.rows[self.rows.count / 2].label = "Changed" }
        await measure("toggle-all") { for row in self.rows { row.done.toggle() } }
        await measure("reverse") { self.rows.reverse() }
        await measure("append-one") { self.rows.append(contentsOf: self.makeRows(1)) }
        await measure("clear") { self.rows = [] }
        page = true
        try? await Task.sleep(for: .milliseconds(500))
        await measure("page-create") { self.entries = (0..<300).map(BenchEntry.init) }
        await measure("page-update") { for entry in self.entries { entry.title += "!" } }
        await measure("page-clear") { self.entries = [] }
        status = "Done"
        print("NATIVE done")
    }

    private func measure(_ name: String, _ change: () -> Void) async {
        status = name
        try? await Task.sleep(for: .milliseconds(400))
        maxGap = 0
        let start = CACurrentMediaTime()
        change()
        let elapsed = (CACurrentMediaTime() - start) * 1000
        try? await Task.sleep(for: .milliseconds(600))
        print(
            "NATIVE \(name.padding(toLength: 12, withPad: " ", startingAt: 0)) change=\(String(format: "%.1f", elapsed))ms maxFrame=\(String(format: "%.1f", maxGap))ms"
        )
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTick > 0 { maxGap = max(maxGap, (link.timestamp - lastTick) * 1000) }
        lastTick = link.timestamp
    }
}

struct NativeBench: View {
    @State private var model = BenchModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.page {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.status).font(.headline)
                            ForEach(model.entries) { entry in
                                BenchEntryView(entry: entry)
                            }
                        }
                        .padding()
                    }
                } else {
                    List {
                        Text(model.status).font(.headline)
                        TextField("", text: $model.text)
                        ForEach(model.rows) { row in
                            BenchRowView(row: row)
                        }
                    }
                }
            }
            .navigationTitle("Benchmark")
        }
        .task { await model.run() }
    }
}

private struct BenchEntryView: View {
    let entry: BenchEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title).font(.headline)
            Text(entry.body).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "book")
                Text("Source \(entry.id)").font(.caption)
            }
        }
    }
}

private struct BenchRowView: View {
    @Bindable var row: BenchRow

    var body: some View {
        HStack {
            Text(row.label)
            Spacer()
            Toggle("", isOn: $row.done).labelsHidden()
        }
    }
}
