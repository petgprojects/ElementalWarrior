//
//  GestureDetection.swift
//  ElementalWarrior
//
//  Hand gesture detection algorithms for fist, open palm, and punch recognition.
//

import ARKit
import simd
import QuartzCore

// MARK: - Gesture Detection

/// Encapsulates all gesture detection logic for hand tracking
enum GestureDetection {

    // MARK: - Fist Detection (Multi-Method)

    /// Multi-method fist detection that works even when ARKit estimates occluded joints.
    /// Uses multiple signals since ARKit predicts joint positions even when occluded.
    /// Returns (isFist, debugInfo) tuple.
    static func checkHandIsFist(skeleton: HandSkeleton?, isLeft: Bool) -> (isFist: Bool, debugInfo: String) {
        guard let skeleton = skeleton else {
            return (false, "no skeleton")
        }

        var debugParts: [String] = []
        var fistSignals = 0
        let requiredSignals = 3  // Need at least 3 signals to consider it a fist

        // METHOD 1: Finger alignment (relaxed threshold)
        let alignmentResult = checkFingerAlignment(skeleton: skeleton)
        if alignmentResult.alignment < 0.75 {
            fistSignals += 1
            debugParts.append("align:\(String(format: "%.2f", alignmentResult.alignment))✓")
        } else {
            debugParts.append("align:\(String(format: "%.2f", alignmentResult.alignment))")
        }

        // METHOD 2: Thumb position - in a fist, thumb crosses in front of fingers
        let thumbResult = checkThumbCurl(skeleton: skeleton)
        if thumbResult.isCurled {
            fistSignals += 1
            debugParts.append("thumb:curled✓")
        } else {
            debugParts.append("thumb:\(String(format: "%.2f", thumbResult.distance))")
        }

        // METHOD 3: Hand compactness - fist is more compact than open hand
        let compactResult = checkHandCompactness(skeleton: skeleton)
        if compactResult.isCompact {
            fistSignals += 1
            debugParts.append("compact:\(String(format: "%.2f", compactResult.ratio))✓")
        } else {
            debugParts.append("compact:\(String(format: "%.2f", compactResult.ratio))")
        }

        // METHOD 4: Fingertip clustering - in a fist, all fingertips are close together
        let clusterResult = checkFingertipClustering(skeleton: skeleton)
        if clusterResult.isClustered {
            fistSignals += 1
            debugParts.append("cluster:\(String(format: "%.2f", clusterResult.spread))✓")
        } else {
            debugParts.append("cluster:\(String(format: "%.2f", clusterResult.spread))")
        }

        let isFist = fistSignals >= requiredSignals
        let debugInfo = "\(fistSignals)/4: " + debugParts.joined(separator: " | ")

        let shouldLog = Int.random(in: 0..<30) == 0
        if shouldLog || isFist {
            print("[FIST \(isLeft ? "L" : "R")] signals=\(fistSignals)/\(requiredSignals) -> \(isFist ? "FIST" : "open") | \(debugInfo)")
        }

        return (isFist, debugInfo)
    }

    /// Check finger alignment using the standard approach
    private static func checkFingerAlignment(skeleton: HandSkeleton) -> (alignment: Float, detected: Bool) {
        let middleMetacarpal = skeleton.joint(.middleFingerMetacarpal)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        let middleIntermediateBase = skeleton.joint(.middleFingerIntermediateBase)

        let metacarpalPos = extractPosition(from: middleMetacarpal.anchorFromJointTransform)
        let knucklePos = extractPosition(from: middleKnuckle.anchorFromJointTransform)
        let intermediateBasePos = extractPosition(from: middleIntermediateBase.anchorFromJointTransform)

        let palmDirection = simd_normalize(knucklePos - metacarpalPos)
        let fingerDirection = simd_normalize(intermediateBasePos - knucklePos)
        let alignment = simd_dot(palmDirection, fingerDirection)

        return (alignment, alignment < 0.75)
    }

    /// Check if thumb is curled toward palm (for fist detection)
    private static func checkThumbCurl(skeleton: HandSkeleton) -> (isCurled: Bool, distance: Float) {
        let thumbTip = skeleton.joint(.thumbTip)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        let middleIntermediateBase = skeleton.joint(.middleFingerIntermediateBase)
        let wrist = skeleton.joint(.wrist)

        let thumbTipPos = extractPosition(from: thumbTip.anchorFromJointTransform)
        let middleKnucklePos = extractPosition(from: middleKnuckle.anchorFromJointTransform)
        let middleIntermediatePos = extractPosition(from: middleIntermediateBase.anchorFromJointTransform)
        let wristPos = extractPosition(from: wrist.anchorFromJointTransform)

        let distToMiddleIntermediate = simd_distance(thumbTipPos, middleIntermediatePos)

        let thumbTipToWrist = simd_distance(thumbTipPos, wristPos)
        let middleKnuckleToWrist = simd_distance(middleKnucklePos, wristPos)

        let isCloseToFingers = distToMiddleIntermediate < 0.07
        let isFoldedIn = thumbTipToWrist < middleKnuckleToWrist
        let isCurled = isCloseToFingers || isFoldedIn

        return (isCurled, distToMiddleIntermediate)
    }

    /// Check if hand is compact (fingertips close to wrist compared to open hand)
    private static func checkHandCompactness(skeleton: HandSkeleton) -> (isCompact: Bool, ratio: Float) {
        let wrist = skeleton.joint(.wrist)
        let middleTip = skeleton.joint(.middleFingerTip)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)

        let wristPos = extractPosition(from: wrist.anchorFromJointTransform)
        let tipPos = extractPosition(from: middleTip.anchorFromJointTransform)
        let knucklePos = extractPosition(from: middleKnuckle.anchorFromJointTransform)

        let tipToWrist = simd_distance(tipPos, wristPos)
        let knuckleToWrist = simd_distance(knucklePos, wristPos)

        guard knuckleToWrist > 0.001 else { return (false, 999) }

        let ratio = tipToWrist / knuckleToWrist
        return (ratio < 1.4, ratio)
    }

    /// Check if fingertips are clustered together (fist) vs spread out (open)
    private static func checkFingertipClustering(skeleton: HandSkeleton) -> (isClustered: Bool, spread: Float) {
        let indexTip = skeleton.joint(.indexFingerTip)
        let middleTip = skeleton.joint(.middleFingerTip)
        let ringTip = skeleton.joint(.ringFingerTip)
        let littleTip = skeleton.joint(.littleFingerTip)

        let indexPos = extractPosition(from: indexTip.anchorFromJointTransform)
        let middlePos = extractPosition(from: middleTip.anchorFromJointTransform)
        let ringPos = extractPosition(from: ringTip.anchorFromJointTransform)
        let littlePos = extractPosition(from: littleTip.anchorFromJointTransform)

        let d1 = simd_distance(indexPos, littlePos)
        let d2 = simd_distance(indexPos, ringPos)
        let d3 = simd_distance(middlePos, littlePos)
        let maxSpread = max(d1, max(d2, d3))

        return (maxSpread < 0.08, maxSpread)
    }

    // MARK: - Open Palm Detection

    /// Check if the hand should show a fireball (open palm facing up)
    static func checkShouldShowFireball(anchor: HandAnchor, skeleton: HandSkeleton?) -> Bool {
        guard let skeleton = skeleton else { return false }
        let isPalmUp = checkPalmFacingUp(anchor: anchor, skeleton: skeleton)
        let isHandOpen = checkHandIsOpen(skeleton: skeleton)
        return isPalmUp && isHandOpen
    }

    /// Check if palm is facing upward by examining wrist orientation
    static func checkPalmFacingUp(anchor: HandAnchor, skeleton: HandSkeleton) -> Bool {
        guard let palmNormal = getPalmNormal(anchor: anchor, skeleton: skeleton) else { return false }
        let worldUp = SIMD3<Float>(0, 1, 0)
        let dotProduct = simd_dot(simd_normalize(palmNormal), worldUp)
        return dotProduct > 0.4
    }

    /// Check if hand is open by measuring finger extension
    static func checkHandIsOpen(skeleton: HandSkeleton) -> Bool {
        let middleTip = skeleton.joint(.middleFingerTip)
        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        let indexTip = skeleton.joint(.indexFingerTip)
        let indexKnuckle = skeleton.joint(.indexFingerKnuckle)

        guard middleTip.isTracked && middleKnuckle.isTracked &&
              indexTip.isTracked && indexKnuckle.isTracked else {
            return false
        }

        let middleTipPos = extractPosition(from: middleTip.anchorFromJointTransform)
        let middleKnucklePos = extractPosition(from: middleKnuckle.anchorFromJointTransform)
        let indexTipPos = extractPosition(from: indexTip.anchorFromJointTransform)
        let indexKnucklePos = extractPosition(from: indexKnuckle.anchorFromJointTransform)

        let middleExtension = simd_distance(middleTipPos, middleKnucklePos)
        let indexExtension = simd_distance(indexTipPos, indexKnucklePos)

        let extensionThreshold: Float = 0.05
        return middleExtension > extensionThreshold && indexExtension > extensionThreshold
    }

    /// Check if the hand should emit a flamethrower (open palm facing forward, away from user)
    static func checkShouldFireFlamethrower(
        anchor: HandAnchor,
        skeleton: HandSkeleton?,
        deviceTransform: simd_float4x4?
    ) -> Bool {
        guard let skeleton = skeleton else { return false }
        let isHandOpen = checkHandIsOpen(skeleton: skeleton)
        let isFacingForward = checkPalmFacingForward(anchor: anchor, skeleton: skeleton, deviceTransform: deviceTransform)
        return isHandOpen && isFacingForward
    }

    /// Compute palm normal in world space (points outward from the palm)
    static func getPalmNormal(anchor: HandAnchor, skeleton: HandSkeleton?) -> SIMD3<Float>? {
        guard let skeleton = skeleton else { return nil }
        let wrist = skeleton.joint(.wrist)
        guard wrist.isTracked else { return nil }

        let worldWristTransform = anchor.originFromAnchorTransform * wrist.anchorFromJointTransform
        let isLeftHand = anchor.chirality == .left
        let yAxisMultiplier: Float = isLeftHand ? 1.0 : -1.0

        let palmNormal = SIMD3<Float>(
            yAxisMultiplier * worldWristTransform.columns.1.x,
            yAxisMultiplier * worldWristTransform.columns.1.y,
            yAxisMultiplier * worldWristTransform.columns.1.z
        )
        return simd_normalize(palmNormal)
    }

    /// Check if palm is roughly aligned with the headset forward vector (stop-sign pose)
    static func checkPalmFacingForward(
        anchor: HandAnchor,
        skeleton: HandSkeleton,
        deviceTransform: simd_float4x4?
    ) -> Bool {
        guard let palmNormal = getPalmNormal(anchor: anchor, skeleton: skeleton) else { return false }

        let worldForward: SIMD3<Float>
        if let deviceTransform = deviceTransform {
            worldForward = SIMD3<Float>(
                -deviceTransform.columns.2.x,
                -deviceTransform.columns.2.y,
                -deviceTransform.columns.2.z
            )
        } else {
            worldForward = SIMD3<Float>(0, 0, -1)
        }

        let alignment = simd_dot(simd_normalize(palmNormal), simd_normalize(worldForward))
        let verticalAlignment = abs(simd_dot(palmNormal, SIMD3<Float>(0, 1, 0)))

        return alignment > GestureConstants.flamethrowerForwardDotThreshold &&
            verticalAlignment < GestureConstants.flamethrowerUpRejectThreshold
    }

    // MARK: - Zombie Pose Detection (Fire Wall)

    /// Check if palm is facing downward (for zombie pose)
    /// Uses back-of-hand visibility as a more relaxed check than strict palm normal
    static func checkPalmFacingDown(anchor: HandAnchor, skeleton: HandSkeleton) -> Bool {
        guard let palmNormal = getPalmNormal(anchor: anchor, skeleton: skeleton) else { return false }
        let worldDown = SIMD3<Float>(0, -1, 0)
        let dotProduct = simd_dot(simd_normalize(palmNormal), worldDown)
        // Relaxed threshold: back of hand visible means palm is facing down-ish
        return dotProduct > GestureConstants.zombiePalmDownDotThreshold
    }

    /// Relaxed hand-not-fist check for zombie pose - doesn't require all fingers to be perfectly visible
    /// Only checks that the hand is NOT making a tight fist (inverse of fist detection)
    static func checkHandNotFist(skeleton: HandSkeleton) -> Bool {
        // Use 2 of the 4 fist signals - if fewer than 2 fist signals, consider it "not a fist"
        var fistSignals = 0

        // METHOD 1: Fingertip clustering - in a fist, all fingertips are close together
        let clusterResult = checkFingertipClustering(skeleton: skeleton)
        if clusterResult.isClustered {
            fistSignals += 1
        }

        // METHOD 2: Hand compactness - fist is more compact than open hand
        let compactResult = checkHandCompactness(skeleton: skeleton)
        if compactResult.isCompact {
            fistSignals += 1
        }

        // METHOD 3: Thumb curl - thumb crosses in front when making fist
        let thumbResult = checkThumbCurl(skeleton: skeleton)
        if thumbResult.isCurled {
            fistSignals += 1
        }

        // If 2 or more fist signals, it's likely a fist, so return false
        // Otherwise, the hand is open enough for zombie pose
        return fistSignals < 2
    }

    /// Check if arm is extended forward from chest
    static func checkArmExtended(
        handPosition: SIMD3<Float>,
        deviceTransform: simd_float4x4?
    ) -> Bool {
        guard let deviceTransform = deviceTransform else { return false }

        // Estimate chest position (below and slightly behind head)
        let headPosition = extractPosition(from: deviceTransform)
        let chestPosition = headPosition - SIMD3<Float>(0, 0.3, 0)

        // Get forward direction (horizontal only)
        let forward = simd_normalize(SIMD3<Float>(
            -deviceTransform.columns.2.x,
            0,
            -deviceTransform.columns.2.z
        ))

        // Project hand-to-chest vector onto forward direction
        let toHand = handPosition - chestPosition
        let forwardDistance = simd_dot(toHand, forward)

        return forwardDistance > GestureConstants.zombieArmExtensionMinDistance
    }

    /// Check if both hands are in zombie pose (arms extended, palms down, NOT making fists)
    /// Returns tuple with pose status, hand positions, and calculated height percentage
    /// Uses relaxed detection that only requires:
    /// 1. Both arms extended forward
    /// 2. Back of palms visible (palms facing down-ish)
    /// 3. Hands not clenched into fists
    static func checkZombiePose(
        leftAnchor: HandAnchor?,
        rightAnchor: HandAnchor?,
        deviceTransform: simd_float4x4?
    ) -> (isZombiePose: Bool, leftPosition: SIMD3<Float>?, rightPosition: SIMD3<Float>?, heightPercent: Float) {
        guard let leftAnchor = leftAnchor,
              let rightAnchor = rightAnchor,
              let leftSkeleton = leftAnchor.handSkeleton,
              let rightSkeleton = rightAnchor.handSkeleton,
              leftAnchor.isTracked,
              rightAnchor.isTracked else {
            return (false, nil, nil, 0)
        }

        // Check both palms facing down (back of hands visible)
        guard checkPalmFacingDown(anchor: leftAnchor, skeleton: leftSkeleton),
              checkPalmFacingDown(anchor: rightAnchor, skeleton: rightSkeleton) else {
            return (false, nil, nil, 0)
        }

        // Check both hands are NOT fists (relaxed open-hand check)
        guard checkHandNotFist(skeleton: leftSkeleton),
              checkHandNotFist(skeleton: rightSkeleton) else {
            return (false, nil, nil, 0)
        }

        // Get hand positions (use wrist position for more stable tracking with palms down)
        let leftPos = getWristPosition(anchor: leftAnchor, skeleton: leftSkeleton)
        let rightPos = getWristPosition(anchor: rightAnchor, skeleton: rightSkeleton)

        // Check arms are extended forward
        guard checkArmExtended(handPosition: leftPos, deviceTransform: deviceTransform),
              checkArmExtended(handPosition: rightPos, deviceTransform: deviceTransform) else {
            return (false, nil, nil, 0)
        }

        // Calculate height percentage from arm elevation
        let heightPercent = calculateHeightPercent(
            leftPos: leftPos,
            rightPos: rightPos,
            deviceTransform: deviceTransform
        )

        return (true, leftPos, rightPos, heightPercent)
    }

    /// Get wrist position for zombie pose (more stable than palm position when palms are down)
    static func getWristPosition(anchor: HandAnchor, skeleton: HandSkeleton) -> SIMD3<Float> {
        let wrist = skeleton.joint(.wrist)
        guard wrist.isTracked else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let jointTransform = anchor.originFromAnchorTransform * wrist.anchorFromJointTransform
        return extractPosition(from: jointTransform)
    }

    /// Calculate wall height percentage from hand elevation (chest=0%, eye=100%)
    static func calculateHeightPercent(
        leftPos: SIMD3<Float>,
        rightPos: SIMD3<Float>,
        deviceTransform: simd_float4x4?
    ) -> Float {
        guard let deviceTransform = deviceTransform else { return 0.5 }

        let headY = deviceTransform.columns.3.y
        let chestY = headY + GestureConstants.zombieHandHeightChestOffset  // Below head
        let eyeY = headY + GestureConstants.zombieHandHeightEyeOffset      // At head level

        let avgHandY = (leftPos.y + rightPos.y) / 2
        let range = eyeY - chestY
        guard range > 0.01 else { return 0.5 }

        return max(0, min(1, (avgHandY - chestY) / range))
    }

    /// Calculate horizontal distance between hands (for wall width control)
    static func calculateHandSeparation(left: SIMD3<Float>, right: SIMD3<Float>) -> Float {
        let dx = right.x - left.x
        let dz = right.z - left.z
        return sqrt(dx * dx + dz * dz)
    }

    /// Calculate wall rotation from hand forward offset
    /// Left hand forward = counter-clockwise, right hand forward = clockwise
    static func calculateWallRotation(
        left: SIMD3<Float>,
        right: SIMD3<Float>,
        deviceTransform: simd_float4x4?
    ) -> Float {
        guard let deviceTransform = deviceTransform else { return 0 }

        // Get forward direction (horizontal)
        let forward = simd_normalize(SIMD3<Float>(
            -deviceTransform.columns.2.x,
            0,
            -deviceTransform.columns.2.z
        ))

        // Project each hand position onto the forward axis
        let leftForward = simd_dot(left, forward)
        let rightForward = simd_dot(right, forward)

        // Difference determines rotation direction and magnitude
        let forwardDiff = rightForward - leftForward

        // Scale and clamp rotation
        let rotation = forwardDiff * GestureConstants.fireWallRotationSensitivity
        return max(-GestureConstants.fireWallMaxRotation,
                   min(GestureConstants.fireWallMaxRotation, rotation))
    }

    // MARK: - Position Helpers

    /// Get the palm position for fireball placement (with offset above palm)
    static func getPalmPosition(anchor: HandAnchor, skeleton: HandSkeleton?) -> SIMD3<Float> {
        guard let skeleton = skeleton else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        guard middleKnuckle.isTracked else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let jointTransform = anchor.originFromAnchorTransform * middleKnuckle.anchorFromJointTransform
        return SIMD3<Float>(
            jointTransform.columns.3.x,
            jointTransform.columns.3.y + 0.08,
            jointTransform.columns.3.z
        )
    }

    /// Get fist position for punch detection (without palm offset)
    static func getFistPosition(anchor: HandAnchor, skeleton: HandSkeleton?) -> SIMD3<Float> {
        guard let skeleton = skeleton else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let middleKnuckle = skeleton.joint(.middleFingerKnuckle)
        guard middleKnuckle.isTracked else {
            return extractPosition(from: anchor.originFromAnchorTransform)
        }

        let jointTransform = anchor.originFromAnchorTransform * middleKnuckle.anchorFromJointTransform
        return extractPosition(from: jointTransform)
    }

    /// Extract position from a 4x4 transform matrix
    static func extractPosition(from transform: simd_float4x4) -> SIMD3<Float> {
        SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    // MARK: - Velocity Calculation

    /// Update position history for velocity calculation
    static func updatePositionHistory(
        for state: inout HandState,
        position: SIMD3<Float>,
        historyDuration: TimeInterval = GestureConstants.velocityHistoryDuration
    ) {
        let now = CACurrentMediaTime()
        state.lastPositions.append((position: position, timestamp: now))
        state.lastPositions.removeAll { now - $0.timestamp > historyDuration }
    }

    /// Calculate velocity from position history
    static func calculateVelocity(from history: [(position: SIMD3<Float>, timestamp: TimeInterval)]) -> SIMD3<Float> {
        guard history.count >= 2 else { return .zero }
        let oldest = history.first!
        let newest = history.last!
        let timeDelta = Float(newest.timestamp - oldest.timestamp)
        guard timeDelta > 0.001 else { return .zero }
        return (newest.position - oldest.position) / timeDelta
    }
}
