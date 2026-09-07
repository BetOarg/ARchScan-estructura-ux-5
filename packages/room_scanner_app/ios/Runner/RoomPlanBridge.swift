import Foundation
import RoomPlan
import Flutter
import UIKit
import simd

/// Native RoomPlan bridge. It emits positioned, versioned geometry so Flutter
/// can convert it to ARchScan's stable RoomModel format.
@available(iOS 16.0, *)
public final class RoomPlanBridge: NSObject,
    RoomCaptureViewDelegate, RoomCaptureSessionDelegate {

    public override init() {
        super.init()
    }

    public required init?(coder: NSCoder) {
        super.init()
    }

    public func encode(with coder: NSCoder) {
        // The active native session is never persisted.
    }

    private var roomCaptureView: RoomCaptureView?
    private var controlsView: UIStackView?
    private var flutterResult: FlutterResult?
    private weak var presentingViewController: UIViewController?
    private var isFinishing = false

    public static func isSupported() -> Bool {
        RoomCaptureSession.isSupported
    }

    public func startScanning(
        from viewController: UIViewController,
        result: @escaping FlutterResult
    ) {
        guard RoomPlanBridge.isSupported() else {
            result(FlutterError(
                code: "UNSUPPORTED_HARDWARE",
                message: "RoomPlan requires iOS 16 or later and LiDAR.",
                details: nil
            ))
            return
        }
        guard flutterResult == nil else {
            result(FlutterError(
                code: "SCAN_ALREADY_RUNNING",
                message: "A RoomPlan scan is already active.",
                details: nil
            ))
            return
        }

        flutterResult = result
        presentingViewController = viewController
        isFinishing = false

        DispatchQueue.main.async { [weak self, weak viewController] in
            guard let self, let viewController else {
                self?.finish(with: FlutterError(
                    code: "NO_CONTROLLER",
                    message: "The active view controller is unavailable.",
                    details: nil
                ))
                return
            }

            let captureView = RoomCaptureView(frame: viewController.view.bounds)
            captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            captureView.delegate = self
            captureView.captureSession.delegate = self
            captureView.accessibilityIdentifier = "archscan-roomplan-view"
            self.roomCaptureView = captureView
            viewController.view.addSubview(captureView)
            self.addControls(to: viewController.view)
            captureView.captureSession.run(
                configuration: RoomCaptureSession.Configuration()
            )
        }
    }

    public func stopScanning() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.flutterResult != nil else { return }
            self.cancelScanning()
        }
    }

    private func addControls(to parentView: UIView) {
        let usesSpanish = Locale.preferredLanguages.first?.hasPrefix("es") == true
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(usesSpanish ? "Cancelar" : "Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelScanning), for: .touchUpInside)

        let doneButton = UIButton(type: .system)
        doneButton.setTitle(usesSpanish ? "Listo" : "Done", for: .normal)
        doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        doneButton.addTarget(self, action: #selector(completeScanning), for: .touchUpInside)

        let controls = UIStackView(arrangedSubviews: [cancelButton, doneButton])
        controls.axis = .horizontal
        controls.distribution = .equalSpacing
        controls.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.88)
        controls.layer.cornerRadius = 14
        controls.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        controls.isLayoutMarginsRelativeArrangement = true
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.accessibilityIdentifier = "archscan-roomplan-controls"
        parentView.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.topAnchor, constant: 8),
            controls.leadingAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            controls.trailingAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
        controlsView = controls
    }

    @objc private func completeScanning() {
        guard flutterResult != nil, !isFinishing else { return }
        controlsView?.isUserInteractionEnabled = false
        roomCaptureView?.captureSession.stop()
    }

    @objc private func cancelScanning() {
        guard flutterResult != nil, !isFinishing else { return }
        finish(with: nil)
    }

    public func captureView(
        shouldPresent roomDataForProcessing: CapturedRoomData,
        error: Error?
    ) -> Bool {
        if let error {
            finish(with: flutterError(error, code: "CAPTURE_FAILED"))
            return false
        }
        return true
    }

    public func captureView(
        didPresent processedResult: CapturedRoom,
        error: Error?
    ) {
        if let error {
            finish(with: flutterError(error, code: "PROCESSING_FAILED"))
            return
        }

        do {
            let payload = makePayload(from: processedResult)
            let data = try JSONSerialization.data(
                withJSONObject: payload,
                options: []
            )
            guard let json = String(data: data, encoding: .utf8) else {
                throw RoomPlanBridgeError.invalidUTF8
            }
            finish(with: json)
        } catch {
            finish(with: flutterError(error, code: "SERIALIZATION_FAILED"))
        }
    }

    private func makePayload(from room: CapturedRoom) -> [String: Any] {
        let floorY = room.walls.map {
            Double($0.transform.columns.3.y - $0.dimensions.y / 2)
        }.min() ?? 0.0

        let walls = room.walls.map {
            surfacePayload($0, type: "wall", floorY: floorY)
        }
        let doors = room.doors.map {
            surfacePayload($0, type: "door", floorY: floorY)
        }
        let windows = room.windows.map {
            surfacePayload($0, type: "window", floorY: floorY)
        }

        return [
            "schemaVersion": 2,
            "coordinateSystem": "roomplan-xz-meters",
            "walls": walls,
            "openings": doors + windows,
            "capturedAt": ISO8601DateFormatter().string(from: Date())
        ]
    }

    private func surfacePayload(
        _ surface: CapturedRoom.Surface,
        type: String,
        floorY: Double
    ) -> [String: Any] {
        let transform = surface.transform
        let center = transform.columns.3
        let widthAxis = simd_normalize(
            SIMD3<Float>(
                transform.columns.0.x,
                transform.columns.0.y,
                transform.columns.0.z
            )
        )
        let halfWidth = surface.dimensions.x / 2
        let start = SIMD3<Float>(center.x, center.y, center.z)
            - widthAxis * halfWidth
        let end = SIMD3<Float>(center.x, center.y, center.z)
            + widthAxis * halfWidth
        let bottom = max(0.0, Double(center.y) -
            Double(surface.dimensions.y) / 2.0 - floorY)

        return [
            "id": surface.identifier.uuidString,
            "type": type,
            "start": point(start, floorY: floorY),
            "end": point(end, floorY: floorY),
            "center": point(
                SIMD3<Float>(center.x, center.y, center.z),
                floorY: floorY
            ),
            "width": Double(surface.dimensions.x),
            "height": Double(surface.dimensions.y),
            "sillHeight": type == "window" ? bottom : 0.0,
            "transform": matrix(transform)
        ]
    }

    private func point(
        _ value: SIMD3<Float>,
        floorY: Double
    ) -> [String: Double] {
        [
            "x": Double(value.x),
            "y": Double(value.y) - floorY,
            "z": Double(value.z)
        ]
    }

    private func matrix(_ value: simd_float4x4) -> [Double] {
        [
            Double(value.columns.0.x), Double(value.columns.0.y),
            Double(value.columns.0.z), Double(value.columns.0.w),
            Double(value.columns.1.x), Double(value.columns.1.y),
            Double(value.columns.1.z), Double(value.columns.1.w),
            Double(value.columns.2.x), Double(value.columns.2.y),
            Double(value.columns.2.z), Double(value.columns.2.w),
            Double(value.columns.3.x), Double(value.columns.3.y),
            Double(value.columns.3.z), Double(value.columns.3.w)
        ]
    }

    private func finish(with value: Any?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isFinishing else { return }
            self.isFinishing = true

            self.roomCaptureView?.captureSession.stop()
            self.roomCaptureView?.removeFromSuperview()
            self.roomCaptureView = nil
            self.controlsView?.removeFromSuperview()
            self.controlsView = nil
            self.presentingViewController = nil

            let result = self.flutterResult
            self.flutterResult = nil
            result?(value)
            self.isFinishing = false
        }
    }

    private func flutterError(
        _ error: Error,
        code: String
    ) -> FlutterError {
        FlutterError(
            code: code,
            message: error.localizedDescription,
            details: String(describing: error)
        )
    }
}

@available(iOS 16.0, *)
private enum RoomPlanBridgeError: LocalizedError {
    case invalidUTF8

    var errorDescription: String? {
        "RoomPlan produced an invalid UTF-8 result."
    }
}
