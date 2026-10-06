//
//  CameraCaptureView.swift
//  ExhibitNote
//
//  Created by Codex on 2026/01/xx.
//

import AVFoundation
import Observation
import SwiftUI
import UIKit

struct CameraCaptureView: View {
    let maxCount: Int
    let onCancel: () -> Void
    let onComplete: ([UIImage]) -> Void

    @State private var model = CameraCaptureModel()

    init(maxCount: Int = 2, onCancel: @escaping () -> Void, onComplete: @escaping ([UIImage]) -> Void) {
        self.maxCount = maxCount
        self.onCancel = onCancel
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if model.isReady {
                CameraPreview(session: model.session)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }
            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .alert("カメラを使用できません", isPresented: $model.showError) {
            Button("OK") { onCancel() }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.5), in: Circle())
            }
            Spacer()
            Text("\(model.photos.count)/\(maxCount)")
                .font(.footnote)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5), in: Capsule())
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(model.photos.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Button {
                                model.removePhoto(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6), in: Circle())
                            }
                            .padding(4)
                        }
                    }
                }
            }
            HStack {
                ZStack {
                    Button {
                        model.capturePhoto(maxCount: maxCount)
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(model.photos.count >= maxCount)
                    HStack {
                        Spacer()
                        Button {
                            onComplete(model.photos)
                        } label: {
                            Text("完了")
                                .font(.headline)
                                .foregroundColor(model.photos.isEmpty ? .gray : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.5), in: Capsule())
                        }
                        .disabled(model.photos.isEmpty)
                    }
                }
            }
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        view.videoLayer.session = session
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? PreviewView else { return }
        view.videoLayer.session = session
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var layer: AVCaptureVideoPreviewLayer?
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoLayer.videoGravity = .resizeAspectFill
        videoLayer.frame = bounds
    }
}

@MainActor
@Observable
private final class CameraCaptureModel: NSObject, @preconcurrency AVCapturePhotoCaptureDelegate {
    var photos: [UIImage] = []
    var isReady = false
    var showError = false
    var errorMessage: String?

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var isConfigured = false

    func start() {
        checkPermission { [weak self] granted in
            guard let self else { return }
            if !granted {
                self.errorMessage = "カメラへのアクセスが許可されていません。設定から許可してください。"
                self.showError = true
                return
            }
            if !self.isConfigured {
                self.configure()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.isReady = true
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func capturePhoto(maxCount: Int) {
        guard photos.count < maxCount else { return }
        let settings = AVCapturePhotoSettings()
        if let connection = output.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        output.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            errorMessage = error.localizedDescription
            showError = true
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else { return }
        DispatchQueue.main.async {
            self.photos.append(image)
        }
    }

    func removePhoto(at index: Int) {
        guard index >= 0, index < photos.count else { return }
        photos.remove(at: index)
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer {
            session.commitConfiguration()
            isConfigured = true
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            errorMessage = "カメラを利用できません。"
            showError = true
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func checkPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
}
