//
//  ExhibitionEditView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/28.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct ExhibitionEditView: View {
    @Environment(\.modelContext) private var context
    @State private var writeState = ExhibitionWriteState()
    @Environment(\.dismiss) private var dismiss
    @State private var vm: ExhibitionEditViewModel

    init(exhibition: Exhibition) {
        _vm = State(initialValue: ExhibitionEditViewModel(exhibition: exhibition))
    }
    
    var body: some View {
        @Bindable var draft = vm.draft
        NavigationStack {
            Form {
                BasicInfoSectionView(
                    title: $draft.title,
                    venue: $draft.venue,
                    addressLine: $draft.addressLine,
                    startDate: $draft.startDate,
                    endDate: $draft.endDate,
                    urlString: $draft.urlString,
                    isAIAnalyzing: false,
                    isExtracting: false,
                    isApplyingAutoDates: draft.isApplyingAutoDates,
                    hasManuallyEditedDates: $draft.hasManuallyEditedDates,
                    onVenueSubmit: draft.triggerGeocoding,
                    onTapMap: draft.prepareMapPicker
                )
                AdmissionInfoSectionView(
                    showAdmissionFees: $draft.showAdmissionFees,
                    admissionFees: $draft.admissionFees,
                    reservationRequired: $draft.reservationRequired,
                    isAIAnalyzing: false,
                    admissionPriceText: draft.admissionPriceText,
                    reservationStatusText: draft.reservationStatusText,
                    onAddFee: draft.beginAddingAdmissionFee,
                    onEditFee: draft.beginEditingAdmissionFee
                )
                ScheduleSectionView(isAIAnalyzing: false) {
                    ScheduleEditorListView(
                        scheduleOpenTime: $draft.scheduleOpenTime,
                        scheduleCloseTime: $draft.scheduleCloseTime,
                        scheduleLastEntryTime: $draft.scheduleLastEntryTime,
                        scheduleClosedWeekdays: $draft.scheduleClosedWeekdays,
                        scheduleHolidayHandling: $draft.scheduleHolidayHandling,
                        scheduleClosedDateRules: $draft.scheduleClosedDateRules,
                        scheduleOpenDateRules: $draft.scheduleOpenDateRules,
                        scheduleSpecialOpenings: $draft.scheduleSpecialOpenings,
                        onAddSpecialOpening: draft.beginAddingSpecialOpening,
                        onEditSpecialOpening: draft.beginEditingSpecialOpening
                    )
                }
                ColorSelectionSectionView(
                    pickedColor: $draft.pickedColor,
                    autoColor: $draft.autoColor
                )
                Section("ポスター") {
                    HStack(spacing: 12) {
                        ExhibitionPosterPreviewView(
                            data: draft.posterThumbData,
                            fallbackColor: draft.pickedColor ?? .gray
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
                            if draft.posterThumbData != nil {
                                Button(role: .destructive, action: vm.removePoster) {
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
                        writeState.run {
                            try await vm.save(in: context)
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $draft.showMapPicker) {
                MapPickerView(seed: draft.tempCoordinate) { pickedCoord, pickedAddress in
                    draft.applyMapSelection(coordinate: pickedCoord, address: pickedAddress)
                }
            }
            .sheet(isPresented: $draft.showSpecialOpeningEditor) {
                SpecialOpeningEditorSheetView(
                    editingSpecialOpeningIndex: $draft.editingSpecialOpeningIndex,
                    showSpecialOpeningEditor: $draft.showSpecialOpeningEditor,
                    specialOpeningMode: $draft.specialOpeningMode,
                    draftSpecialOpeningDate: $draft.draftSpecialOpeningDate,
                    draftSpecialOpeningStartDate: $draft.draftSpecialOpeningStartDate,
                    draftSpecialOpeningEndDate: $draft.draftSpecialOpeningEndDate,
                    draftSpecialOpeningWeekdays: $draft.draftSpecialOpeningWeekdays,
                    draftSpecialOpeningOpenTime: $draft.draftSpecialOpeningOpenTime,
                    draftSpecialOpeningCloseTime: $draft.draftSpecialOpeningCloseTime,
                    draftSpecialOpeningLastEntryTime: $draft.draftSpecialOpeningLastEntryTime,
                    onToggleWeekday: draft.toggleDraftWeekday,
                    onCommit: draft.commitDraftSpecialOpening
                )
            }
            .sheet(isPresented: $draft.showAdmissionFeeEditor) {
                AdmissionFeeEditorSheetView(
                    editingAdmissionFeeIndex: $draft.editingAdmissionFeeIndex,
                    showAdmissionFeeEditor: $draft.showAdmissionFeeEditor,
                    draftAdmissionLabel: $draft.draftAdmissionLabel,
                    draftAdmissionPriceText: $draft.draftAdmissionPriceText,
                    draftAdmissionNote: $draft.draftAdmissionNote,
                    canSaveAdmissionFee: draft.canSaveAdmissionFee,
                    onCommit: draft.commitAdmissionFee
                )
            }
        }
        .exhibitionWriteFeedback(writeState)
        .photosPicker(
            isPresented: $vm.showLibrary,
            selection: $vm.selectedPhotoItem,
            matching: .images
        )
        .onChange(of: vm.selectedPhotoItem) { _, item in
            Task { await vm.handleSelectedPhotoItem(item) }
        }
        .fullScreenCover(isPresented: $vm.showCamera) {
            CameraPicker { image in
                vm.showCamera = false
                if let image {
                    vm.handlePickedImage(image)
                }
            }
        }
    }

}
