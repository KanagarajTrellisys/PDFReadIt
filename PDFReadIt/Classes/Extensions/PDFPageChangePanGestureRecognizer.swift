//
//  PDFPageChangePanGestureRecognizer.swift
//  PDFReadIt
//
//  Created by Dmitry Zawadsky on 14.02.2020.
//  Copyright © 2020 Kishikawa Katsumi. All rights reserved.
//

import PDFKit
import UIKit

class PDFPageChangeSwipeGestureRecognizer: UISwipeGestureRecognizer {

    unowned let pdfView: PDFView

    init(pdfView: PDFView) {
        self.pdfView = pdfView
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(handleGesture(_:)))
    }

    @objc
    func handleGesture(_ gestureRecognizer: UISwipeGestureRecognizer) {
        guard gestureRecognizer.state == .ended else { return }
        switch gestureRecognizer.direction {
        case .left:
            if pdfView.canGoToNextPage {
                
                let animation = CATransition()
                animation.type = CATransitionType.reveal
                animation.subtype = CATransitionSubtype.fromLeft
                  animation.duration = 1.0
                  animation.delegate = self as? CAAnimationDelegate
                pdfView.goToNextPage(self)
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

            }
        case .right:
            if pdfView.canGoToPreviousPage {
                let animation = CATransition()
                animation.type = CATransitionType.reveal
                animation.subtype = CATransitionSubtype.fromLeft
                  animation.duration = 1.0
                  animation.delegate = self as? CAAnimationDelegate

                pdfView.goToPreviousPage(self)
                pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

            }
        case .up:
            break
        case .down:
            break
        default:
            break
        }
    }
}
