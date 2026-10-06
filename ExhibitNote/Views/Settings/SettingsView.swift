import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @State private var vm = SettingsViewModel()
    @Bindable private var settingsStore = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query(sort: [SortDescriptor(\Exhibition.endDate, order: .forward)]) private var allExhibitions: [Exhibition]

    var body: some View {
        NavigationStack {
            Form {
                Section("提案") {
                    Toggle("訪問済みも提案に含める", isOn: $settingsStore.includeVisitedSuggestions)
                }
                Section {
                    if vm.notificationAuthorizationStatus == .denied {
                        Text("iPhoneの設定で通知が許可されていません。通知を受け取るには、設定アプリで「通知を許可」をオンにしてください。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("iPhoneの設定を開く") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                openURL(url)
                            }
                        }
                    } else if vm.notificationAuthorizationStatus == .notDetermined {
                        Button("通知を許可する") {
                            Task {
                                await vm.requestAuthorization(exhibitions: allExhibitions)
                            }
                        }
                        .disabled(vm.isRequestingAuthorization)
                    }
                    if let message = vm.authorizationErrorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Toggle(isOn: $settingsStore.endingSoonNotificationSettings.isEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("間もなく終了する展覧会を通知する")
                            Text("会期終了1週間前と1日前に通知します")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    DatePicker(
                        "通知時刻",
                        selection: $settingsStore.endingSoonNotificationSettings.pickerDate,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!settingsStore.endingSoonNotificationSettings.isEnabled)
                    Toggle("近くで開館中の展示を通知する", isOn: $settingsStore.notifyNearbyOpenEnabled)
                    Picker("通知の半径", selection: $settingsStore.notifyNearbyRadiusKm) {
                        Text("3km").tag(3.0)
                        Text("5km").tag(5.0)
                        Text("10km").tag(10.0)
                        Text("20km").tag(20.0)
                        Text("50km").tag(50.0)
                    }
                    .disabled(!settingsStore.notifyNearbyOpenEnabled)
                } header: {
                    Text("通知")
                }
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await vm.refreshAuthorization(exhibitions: allExhibitions)
            }
            .onChange(of: settingsStore.endingSoonNotificationSettings) {
                vm.rescheduleNotifications(exhibitions: allExhibitions)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

}
