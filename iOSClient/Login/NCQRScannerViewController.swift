//
//  NCQRScannerViewController.swift
//  Nextcloud
//
//  QR login scanner based on VisionKit's DataScannerViewController.
//
//  The previous implementation (NCLoginQRCode.swift, using the third-party
//  QRCodeReader.swift package pinned to a 2019 commit) silently failed on
//  real devices: QRCodeReader.supportsMetadataObjectTypes() checks
//  AVCaptureMetadataOutput.availableMetadataObjectTypes before the capture
//  session is ever started, which returns empty on current iOS — so
//  checkScanPermissions() returns false and scan() just returns, with no
//  camera view and no error shown to the user.
//
//  This mirrors the QRScannerViewController already shipping (and verified
//  working on a real device) in Talk gov.ao's fork of nextcloud/talk-ios.
//  Unlike that version, this one hands the raw scanned string back to the
//  existing NCLoginQRCodeDelegate (NCLogin.dismissQRCode), which already
//  parses it using this app's own NCBrandOptions.webLoginAutenticationProtocol
//  scheme — so the QR payload format/parsing is untouched, only the camera
//  capture mechanism changes.
//

import UIKit
import VisionKit

@objcMembers
class NCQRScannerViewController: UIViewController, DataScannerViewControllerDelegate {

    weak var delegate: NCLoginQRCodeDelegate?

    private var scannerViewController: DataScannerViewController?
    private var didHandleScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let scannerVC = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .accurate,
            isHighlightingEnabled: true
        )
        scannerVC.delegate = self
        scannerViewController = scannerVC

        addChild(scannerVC)
        scannerVC.view.frame = view.bounds
        scannerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scannerVC.view)
        scannerVC.didMove(toParent: self)

        let closeButton = UIButton(type: .system)
        closeButton.setTitle(NSLocalizedString("_close_", comment: ""), for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonPressed), for: .touchUpInside)
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard DataScannerViewController.isAvailable else {
            showCameraPermissionAlert()
            return
        }

        try? scannerViewController?.startScanning()
    }

    class func isDataScannerSupported() -> Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    @objc private func closeButtonPressed() {
        delegate?.dismissQRCode(nil, metadataType: nil)
        dismiss(animated: true)
    }

    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: NSLocalizedString("_error_", comment: ""),
            message: NSLocalizedString("_qrcode_not_authorized_", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel) { [weak self] _ in
            self?.delegate?.dismissQRCode(nil, metadataType: nil)
            self?.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("_settings_", comment: ""), style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        present(alert, animated: true)
    }

    // MARK: - DataScannerViewController delegate

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        guard !didHandleScan, let item = addedItems.first, case let .barcode(barcode) = item,
              let value = barcode.payloadStringValue else { return }

        didHandleScan = true
        scannerViewController?.stopScanning()
        dismiss(animated: true) { [weak self] in
            self?.delegate?.dismissQRCode(value, metadataType: barcode.observation.symbology.rawValue)
        }
    }

    func dataScannerDidTapToDismiss(_ dataScanner: DataScannerViewController) {
        closeButtonPressed()
    }
}
