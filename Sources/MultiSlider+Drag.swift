//
//  MultiSlider+Drag.swift
//  MultiSlider
//
//  Created by Yonat Sharon on 25.10.2018.
//

extension MultiSlider {
    @objc open func didDrag(_ panGesture: UIPanGestureRecognizer) {
        self.equalViewIndexes.removeAll()
        
        switch panGesture.state {
        case .began:
            selectionFeedbackGenerator.prepare()
            // determine thumb to drag
            let location = panGesture.location(in: slideView)
            draggedThumbIndex = closestThumb(point: location)
        case .ended, .cancelled, .failed:
            selectionFeedbackGenerator.end()
            sendActions(for: .touchUpInside) // no bounds check for now (.touchUpInside vs .touchUpOutside)
            if !isContinuous { sendActions(for: [.valueChanged, .primaryActionTriggered]) }
        case .possible, .changed: break
        }
        guard draggedThumbIndex >= 0 else { return }
        //guard self.equalViewIndexes.count == 2 else { return }
        
        if self.equalViewIndexes.count > 0 {
            if panGesture.velocity(in: slideView).x > 0 {
                //right
                draggedThumbIndex = self.equalViewIndexes.sorted().last ?? value.count - 1
            } else {
                //left
                draggedThumbIndex = self.equalViewIndexes.sorted().first ?? 0
            }
        }
        
        let slideViewLength = slideView.bounds.size(in: orientation)
        var targetPosition = panGesture.location(in: slideView).coordinate(in: orientation)
        let stepSizeInView = (snapStepSize / (maximumValue - minimumValue)) * slideViewLength
        
        // snap translation to stepSizeInView
        if snapStepSize > 0 {
            let translationSnapped = panGesture.translation(in: slideView).coordinate(in: orientation).rounded(stepSizeInView)
            if 0 == Int(translationSnapped) { return }
            panGesture.setTranslation(.zero, in: slideView)
        }
        
        // don't cross prev/next thumb and total range
        targetPosition = boundedDraggedThumbPosition(targetPosition: targetPosition, stepSizeInView: stepSizeInView)
        
        // change corresponding value
        updateDraggedThumbValue(relativeValue: targetPosition / slideViewLength)
        
        UIView.animate(withDuration: 0.1) {
            self.updateDraggedThumbPositionAndLabel()
            self.layoutIfNeeded()
        }
        
        if isContinuous { sendActions(for: [.valueChanged, .primaryActionTriggered]) }
    }
    
    /// adjusted position that doesn't cross prev/next thumb and total range
    private func boundedDraggedThumbPosition(targetPosition: CGFloat, stepSizeInView: CGFloat) -> CGFloat {
        var delta = snapStepSize > 0 ? stepSizeInView : thumbViews[draggedThumbIndex].frame.size(in: orientation) / 2
        delta = keepsDistanceBetweenThumbs ? delta : 0
        if orientation == .horizontal { delta = -delta }
        let bottomLimit = draggedThumbIndex > 0
            ? thumbViews[draggedThumbIndex - 1].center.coordinate(in: orientation) - delta
            : slideView.bounds.bottom(in: orientation)
        let topLimit = draggedThumbIndex < thumbViews.count - 1
            ? thumbViews[draggedThumbIndex + 1].center.coordinate(in: orientation) + delta
            : slideView.bounds.top(in: orientation)
        if orientation == .vertical {
            return min(bottomLimit, max(targetPosition, topLimit))
        } else {
            return max(bottomLimit, min(targetPosition, topLimit))
        }
    }
    
    private func updateDraggedThumbValue(relativeValue: CGFloat) {
        var newValue = relativeValue * (maximumValue - minimumValue)
        if orientation == .vertical {
            newValue = maximumValue - newValue
        } else {
            newValue += minimumValue
        }
        newValue = newValue.rounded(snapStepSize)
        guard newValue != value[draggedThumbIndex] else { return }
        isSettingValue = true
        value[draggedThumbIndex] = newValue
        isSettingValue = false
        if snapStepSize > 0 || relativeValue == 0 || relativeValue == 1 {
            selectionFeedbackGenerator.generateFeedback()
        }
    }
    
    private func updateDraggedThumbPositionAndLabel() {
        positionThumbView(draggedThumbIndex)
        if draggedThumbIndex < valueLabels.count {
            updateValueLabel(draggedThumbIndex)
            if isValueLabelRelative && draggedThumbIndex + 1 < valueLabels.count {
                updateValueLabel(draggedThumbIndex + 1)
            }
        }
    }
    
    private func closestThumb(point: CGPoint) -> Int {
        
        var closest = -1
        var minimumDistance = CGFloat.greatestFiniteMagnitude
        var minimumDistanceViewIndex: Int!
        for i in 0 ..< thumbViews.count {
            guard !disabledThumbIndices.contains(i) else { continue }
            let distance = point.distanceTo(thumbViews[i].center)
            if distance > minimumDistance { break }
            
            if minimumDistance == distance {
                self.equalViewIndexes.append(i)
                self.equalViewIndexes.append(minimumDistanceViewIndex)
            }
            minimumDistance = distance
            minimumDistanceViewIndex = i
            if distance < thumbViews[i].diagonalSize {
                closest = i
            }
        }
        return closest
    }
}
