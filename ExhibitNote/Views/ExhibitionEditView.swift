//
//  ExhibitionEditView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/28.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct ExhibitionEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let exhibition: Exhibition
    @StateObject private var vm: ExhibitionEditViewModel

    init(exhibition: Exhibition) {
        self.exhibition = exhibition
        _vm = StateObject(wrappedValue: ExhibitionEditViewModel(exhibition: exhibition))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                BasicInfoSectionView(
                    title: $vm.title,
                    venue: $vm.venue,
                    addressLine: $vm.addressLine,
                    startDate: $vm.startDate,
                    endDate: $vm.endDate,
                    urlString: $vm.urlString,
                    isAIAnalyzing: false,
                    isApplyingAutoDates: vm.isApplyingAutoDates,
                    hasManuallyEditedDates: $vm.hasManuallyEditedDates,
                    onVenueSubmit: vm.triggerGeocoding,
                    onTapMap: {
                        let q = vm.addressLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? vm.venue.trimmingCharacters(in: .whitespacesAndNewlines)
                        : vm.addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !q.isEmpty else { return }
                        vm.mapPickerPayload = ExhibitionEditViewModel.MapPickerPayload(query: q)
                    }
                )
                AdmissionInfoSectionView(
                    showAdmissionFees: $vm.showAdmissionFees,
                    admissionFees: $vm.admissionFees,
                    reservationRequired: $vm.reservationRequired,
                    isAIAnalyzing: false,
                    admissionPriceText: admissionPriceText,
                    reservationStatusText: reservationStatusText,
                    onAddFee: {
                        vm.editingAdmissionFeeIndex = nil
                        vm.prepareAdmissionFeeEditor()
                        vm.showAdmissionFeeEditor = true
                    },
                    onEditFee: { idx in
                        vm.editingAdmissionFeeIndex = idx
                        vm.prepareAdmissionFeeEditor(for: vm.admissionFees[idx])
                        vm.showAdmissionFeeEditor = true
                    }
                )
                ScheduleSectionView(isAIAnalyzing: false) {
                    ScheduleEditorListView(
                        scheduleOpenTime: $vm.scheduleOpenTime,
                        scheduleCloseTime: $vm.scheduleCloseTime,
                        scheduleLastEntryTime: $vm.scheduleLastEntryTime,
                        scheduleClosedWeekdays: $vm.scheduleClosedWeekdays,
                        scheduleHolidayHandling: $vm.scheduleHolidayHandling,
                        scheduleClosedDateRules: $vm.scheduleClosedDateRules,
                        scheduleOpenDateRules: $vm.scheduleOpenDateRules,
                        scheduleSpecialOpenings: $vm.scheduleSpecialOpenings,
                        onAddSpecialOpening: {
                            vm.editingSpecialOpeningIndex = nil
                            vm.prepareSpecialOpeningEditor()
                            vm.showSpecialOpeningEditor = true
                        },
                        onEditSpecialOpening: { idx in
                            vm.editingSpecialOpeningIndex = idx
                            vm.prepareSpecialOpeningEditor(for: vm.scheduleSpecialOpenings[idx])
                            vm.showSpecialOpeningEditor = true
                        }
                    )
                }
                ColorSelectionSectionView(
                    pickedColor: $vm.pickedColor,
                    autoColor: $vm.autoColor
                )
                Section("ポスター") {
                    HStack(spacing: 12) {
                        PosterPreviewView(
                            data: vm.posterThumbData,
                            fallbackColor: vm.pickedColor ?? .gray
                        )
                        .overlay(
                            Group {
                                if let img = vm.localPreviewImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                }
                            }
                        )
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        Menu {
                            Button {
                                vm.showLibrary = true
                            } label: {
                                Label("写真ライブラリから選ぶ", systemImage: "photo.on.rectangle")
                            }
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    vm.showCamera = true
                                } label: {
                                    Label("カメラで撮る", systemImage: "camera.viewfinder")
                                }
                            }
                            if vm.posterThumbData != nil {
                                Button(role: .destructive) {
                                    vm.posterThumbData = nil
                                    vm.localPreviewImage = nil
                                } label: {
                                    Label("ポスターを削除", systemImage: "trash")
                                }
                            }
                        } label: {
                            Label("ポスター画像を変更", systemImage: "text.viewfinder")
                        }
                    }
                }
            }
            .navigationTitle("編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        vm.applyChanges(to: exhibition)
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .sheet(item: $vm.mapPickerPayload) { payload in
                NavigationStack {
                    MapPickerView(seed: vm.tempCoordinate, initialQuery: payload.query) { pickedCoord, pickedAddress in
                        vm.tempCoordinate = pickedCoord
                        vm.previewRegion.center = pickedCoord
                        vm.previewRegion.span = .init(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        if let addr = pickedAddress, !addr.isEmpty, vm.addressLine.isEmpty {
                            vm.addressLine = addr
                        }
                    }
                }
            }
            .sheet(isPresented: $vm.showSpecialOpeningEditor) {
                SpecialOpeningEditorSheetView(
                    editingSpecialOpeningIndex: $vm.editingSpecialOpeningIndex,
                    showSpecialOpeningEditor: $vm.showSpecialOpeningEditor,
                    specialOpeningMode: $vm.specialOpeningMode,
                    draftSpecialOpeningDate: $vm.draftSpecialOpeningDate,
                    draftSpecialOpeningStartDate: $vm.draftSpecialOpeningStartDate,
                    draftSpecialOpeningEndDate: $vm.draftSpecialOpeningEndDate,
                    draftSpecialOpeningWeekdays: $vm.draftSpecialOpeningWeekdays,
                    draftSpecialOpeningOpenTime: $vm.draftSpecialOpeningOpenTime,
                    draftSpecialOpeningCloseTime: $vm.draftSpecialOpeningCloseTime,
                    draftSpecialOpeningLastEntryTime: $vm.draftSpecialOpeningLastEntryTime,
                    onToggleWeekday: vm.toggleDraftWeekday,
                    onCommit: vm.commitDraftSpecialOpening
                )
            }
            .sheet(isPresented: $vm.showAdmissionFeeEditor) {
                AdmissionFeeEditorSheetView(
                    editingAdmissionFeeIndex: $vm.editingAdmissionFeeIndex,
                    showAdmissionFeeEditor: $vm.showAdmissionFeeEditor,
                    draftAdmissionLabel: $vm.draftAdmissionLabel,
                    draftAdmissionPriceText: $vm.draftAdmissionPriceText,
                    draftAdmissionNote: $vm.draftAdmissionNote,
                    canSaveAdmissionFee: vm.canSaveAdmissionFee,
                    onCommit: vm.commitAdmissionFee
                )
            }
            .sheet(isPresented: $vm.showLibrary) {
                PhotoLibraryPicker { image in
                    if let img = image { vm.handlePickedImage(img) }
                    vm.showLibrary = false
                }
            }
            .sheet(isPresented: $vm.showCamera) {
                CameraPicker { image in
                    if let img = image { vm.handlePickedImage(img) }
                    vm.showCamera = false
                }
            }
        }
    }

    private func reservationStatusText(_ value: Bool?) -> String {
        switch value {
        case .some(true):
            return "事前予約制"
        case .some(false):
            return "予約不要"
        case .none:
            return "記載なし"
        }
    }

    private func admissionPriceText(_ fee: AdmissionFeeRule) -> String? {
        if fee.isFreeLike {
            return "無料"
        }
        if let price = fee.priceYen {
            return "\(price)円"
        }
        return nil
    }

    private struct PosterPreviewView: View {
        let data: Data?
        let fallbackColor: Color

        var body: some View {
            if let d = data, let ui = UIImage(data: d) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    fallbackColor.opacity(0.15)
                    Image(systemName: "photo.on.rectangle")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private struct CameraPicker: UIViewControllerRepresentable {
        var onComplete: (UIImage?) -> Void
        func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }
        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = false
            picker.delegate = context.coordinator
            return picker
        }
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
            let onComplete: (UIImage?) -> Void
            init(onComplete: @escaping (UIImage?) -> Void) { self.onComplete = onComplete }
            func imagePickerController(_ picker: UIImagePickerController,
                                       didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                let img = (info[.originalImage] as? UIImage)
                picker.dismiss(animated: true) { self.onComplete(img) }
            }
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                picker.dismiss(animated: true) { self.onComplete(nil) }
            }
        }
    }

    private struct PhotoLibraryPicker: UIViewControllerRepresentable {
        var onComplete: (UIImage?) -> Void

        func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

        func makeUIViewController(context: Context) -> PHPickerViewController {
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 1
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

        final class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let onComplete: (UIImage?) -> Void
            init(onComplete: @escaping (UIImage?) -> Void) { self.onComplete = onComplete }

            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                guard let first = results.first else {
                    picker.dismiss(animated: true) { self.onComplete(nil) }
                    return
                }
                let provider = first.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        DispatchQueue.main.async {
                            picker.dismiss(animated: true) {
                                self.onComplete(image as? UIImage)
                            }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                        let img = data.flatMap { UIImage(data: $0) }
                        DispatchQueue.main.async {
                            picker.dismiss(animated: true) {
                                self.onComplete(img)
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        picker.dismiss(animated: true) { self.onComplete(nil) }
                    }
                }
            }
        }
    }
}
