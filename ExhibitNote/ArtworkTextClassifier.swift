//
//  ArtworkTextClassifier.swift
//  ExhibitNote
//
//  Created by Honoka Nishiyama on 2025/11/11.
//

import Foundation
import CoreML
import NaturalLanguage

/// Create ML で作ったラベルと対応
enum ArtworkFieldLabel: String {
    case title
    case artist
    case year
    case material
    case collection
    case other
}

final class ArtworkTextClassifier {
    static let shared = ArtworkTextClassifier()
    private let nlModel: NLModel?

    private init() {
        // Create ML で作ったモデル名と合わせる
        let config = MLModelConfiguration()
        if let coreMLModel = try? MyTextClassifier(configuration: config).model {
            nlModel = try? NLModel(mlModel: coreMLModel)
        } else {
            nlModel = nil
        }
    }

    /// 1行のテキストをどのラベルか判定
    func predictLabel(for text: String) -> ArtworkFieldLabel {
        guard
            let nlModel,
            let raw = nlModel.predictedLabel(for: text),
            let label = ArtworkFieldLabel(rawValue: raw)
        else {
            return .other
        }
        return label
    }
}

struct ClassifiedTextFragment {
    let text: String
    let label: ArtworkFieldLabel
}
