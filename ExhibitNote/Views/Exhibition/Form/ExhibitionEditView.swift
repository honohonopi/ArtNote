//
//  ExhibitionEditView.swift
//  ArtNote
//
//  Created by Honoka Nishiyama on 2025/10/28.
//

import SwiftUI
import SwiftData
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
                    isExtracting: false,
                    isApplyingAutoDates: vm.isApplyingAutoDates,
                    hasManuallyEditedDates: $vm.hasManuallyEditedDates,
                    onVenueSubmit: vm.triggerGeocoding,
                    onTapMap: vm.prepareMapPicker
                )
                AdmissionInfoSectionView(
                    showAdmissionFees: $vm.showAdmissionFees,
                    admissionFees: $vm.admissionFees,
                    reservationRequired: $vm.reservationRequired,
                    isAIAnalyzing: false,
                    admissionPriceText: vm.admissionPriceText,
                    reservationStatusText: vm.reservationStatusText,
                    onAddFee: vm.beginAddingAdmissionFee,
                    onEditFee: vm.beginEditingAdmissionFee
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
                        onAddSpecialOpening: vm.beginAddingSpecialOpening,
                        onEditSpecialOpening: vm.beginEditingSpecialOpening
                    )
                }
                ColorSelectionSectionView(
                    pickedColor: $vm.pickedColor,
                    autoColor: $vm.autoColor
                )
                Section("ポスター") {
                    HStack(spacing: 12) {
                        ExhibitionPosterPreviewView(
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
            .sheet(isPresented: $vm.showMapPicker) {
                MapPickerView(seed: vm.tempCoordinate) { pickedCoord, pickedAddress in
                    vm.applyMapSelection(coordinate: pickedCoord, address: pickedAddress)
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
        .exhibitionWriteFeedback(writeState)
    }

}
