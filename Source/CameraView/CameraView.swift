import UIKit
import AVFoundation
import PhotosUI

protocol CameraViewDelegate: class {

    func setFlashButtonHidden(_ hidden: Bool)

    func imageToLibrary()

    func cameraNotAvailable()
}

class CameraView: UIViewController, CLLocationManagerDelegate, CameraManDelegate {

    var configuration = Configuration()

    lazy var blurView: UIVisualEffectView = { [unowned self] in
        let effect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: effect)

        return blurView
    }()

    lazy var focusImageView: UIImageView = { [unowned self] in
        let imageView = UIImageView()
        imageView.image = AssetManager.getImage("focusIcon")
        imageView.backgroundColor = UIColor.clear
        imageView.frame = CGRect(x: 0, y: 0, width: 110, height: 110)
        imageView.alpha = 0

        return imageView
    }()

    lazy var capturedImageView: UIView = { [unowned self] in
        let view = UIView()
        view.backgroundColor = UIColor.black
        view.alpha = 0

        return view
    }()

    lazy var containerView: UIView = {
        let view = UIView()
        view.alpha = 0

        return view
    }()

    lazy var noCameraLabel: UILabel = { [unowned self] in
        let label = UILabel()
        label.font = self.configuration.noCameraFont
        label.textColor = self.configuration.noCameraColor
        label.text = self.configuration.noCameraTitle
        label.sizeToFit()

        return label
    }()

    lazy var noCameraButton: UIButton = { [unowned self] in
        let button = UIButton(type: .system)
        let title = NSAttributedString(string: self.configuration.settingsTitle,
                attributes: [
                        NSAttributedString.Key.font: self.configuration.settingsFont,
                        NSAttributedString.Key.foregroundColor: self.configuration.settingsColor,
                ])

        button.setAttributedTitle(title, for: UIControl.State())
        button.contentEdgeInsets = UIEdgeInsets(top: 5.0, left: 10.0, bottom: 5.0, right: 10.0)
        button.sizeToFit()
        button.layer.borderColor = self.configuration.settingsColor.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 4
        button.addTarget(self, action: #selector(settingsButtonDidTap), for: .touchUpInside)

        return button
    }()

    lazy var tapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(tapGestureRecognizerHandler(_:)))

        return gesture
    }()

    let cameraMan = CameraMan()

    var previewLayer: AVCaptureVideoPreviewLayer?
    weak var delegate: CameraViewDelegate?
    var animationTimer: Timer?
    var locationManager: LocationManager?
    var startOnFrontCamera: Bool = false


    public init(configuration: Configuration? = nil) {
        if let configuration = configuration {
            self.configuration = configuration
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if configuration.recordLocation {
            locationManager = LocationManager()
        }

        view.backgroundColor = configuration.mainColor

        view.addSubview(containerView)
        containerView.addSubview(blurView)

        [focusImageView, capturedImageView].forEach {
            view.addSubview($0)
        }

        view.addGestureRecognizer(tapGestureRecognizer)

        cameraMan.delegate = self
        cameraMan.setup(self.startOnFrontCamera)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

//        previewLayer?.connection.videoOrientation = .portrait
        locationManager?.startUpdatingLocation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        locationManager?.stopUpdatingLocation()
    }

    func updateCameraOrientation() {
        switch UIDevice.current.orientation {
        case .portrait:
            previewLayer?.connection?.videoOrientation = .portrait
        case .landscapeLeft:
            previewLayer?.connection?.videoOrientation = .landscapeRight
        case .landscapeRight:
            previewLayer?.connection?.videoOrientation = .landscapeLeft
        case .portraitUpsideDown:
            previewLayer?.connection?.videoOrientation = .portraitUpsideDown
        default:
            break
        }
    }

    func setupPreviewLayer() {
        let layer = AVCaptureVideoPreviewLayer(session: cameraMan.session)

        layer.backgroundColor = configuration.mainColor.cgColor
        layer.autoreverses = true
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill

        view.layer.insertSublayer(layer, at: 0)
        layer.frame = view.layer.frame
        view.clipsToBounds = true

        previewLayer = layer
    }

    // MARK: - Layout

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let centerX = view.bounds.width / 2

        noCameraLabel.center = CGPoint(x: centerX,
                y: view.bounds.height / 2 - 80)

        noCameraButton.center = CGPoint(x: centerX,
                y: noCameraLabel.frame.maxY + 20)

        blurView.frame = view.bounds
        containerView.frame = view.bounds
        capturedImageView.frame = view.bounds

        if let connection = previewLayer?.connection {
            let deviceOrientation = UIDevice.current.orientation
            if connection.isVideoOrientationSupported {
                switch deviceOrientation {
                case .portrait:
                    updatePreviewLayer(orientation: .portrait)
                case .portraitUpsideDown:
                    updatePreviewLayer(orientation: .portraitUpsideDown)
                case .landscapeLeft:
                    updatePreviewLayer(orientation: .landscapeRight)
                case .landscapeRight:
                    updatePreviewLayer(orientation: .landscapeLeft)
                default:
                    break
                }
            }
        }

    }

    private func updatePreviewLayer(orientation: AVCaptureVideoOrientation) {
        previewLayer?.connection?.videoOrientation = orientation
        previewLayer?.frame = self.view.bounds
    }

    // MARK: - Actions

    @objc func settingsButtonDidTap() {
        DispatchQueue.main.async {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.openURL(settingsURL)
            }
        }
    }

    // MARK: - Camera actions

    func rotateCamera() {
        UIView.animate(withDuration: 0.3, animations: { 
            self.containerView.alpha = 1
        }, completion: { _ in
            self.cameraMan.switchCamera {
                UIView.animate(withDuration: 0.7, animations: {
                    self.containerView.alpha = 0
                })
            }
        })
    }

    func flashCamera(_ title: String) {
        let mapping: [String: AVCaptureDevice.FlashMode] = [
                "ON": .on,
                "OFF": .off
        ]

        cameraMan.flash(mapping[title] ?? .auto)
    }

    func takePicture(_ completion: @escaping () -> ()) {
        guard let previewLayer = previewLayer else {
            return
        }

        UIView.animate(withDuration: 0.1, animations: {
            self.capturedImageView.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.1, animations: {
                self.capturedImageView.alpha = 0
            })
        })

        cameraMan.takePhoto(previewLayer, location: locationManager?.latestLocation) {
            completion()
            self.delegate?.imageToLibrary()
        }
    }

    // MARK: - Timer methods

    @objc func timerDidFire() {
        UIView.animate(withDuration: 0.3, animations: { [unowned self] in
            self.focusImageView.alpha = 0
        })
    }

    // MARK: - Camera methods

    func focusTo(_ point: CGPoint) {
        if let convertedPoint = previewLayer?.captureDevicePointConverted(fromLayerPoint: point) {
            cameraMan.focus(convertedPoint)

            focusImageView.center = point
            UIView.animate(withDuration: 0.5, animations: { 
                self.focusImageView.alpha = 1
                self.focusImageView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            }, completion: { _ in
                self.animationTimer = Timer.scheduledTimer(timeInterval: 1, target: self,
                        selector: #selector(CameraView.timerDidFire), userInfo: nil, repeats: false)
            })

        }


    }

    // MARK: - Tap

    @objc func tapGestureRecognizerHandler(_ gesture: UITapGestureRecognizer) {
        let touch = gesture.location(in: view)
        focusTo(touch)
    }

    // MARK: - Private helpers

    func showNoCamera(_ show: Bool) {
        [noCameraButton, noCameraLabel].forEach {
            show ? view.addSubview($0) : $0.removeFromSuperview()
        }
    }

    // CameraManDelegate
    func cameraManNotAvailable(_ cameraMan: CameraMan) {
        showNoCamera(true)
        focusImageView.isHidden = true
        delegate?.cameraNotAvailable()
    }

    func cameraMan(_ cameraMan: CameraMan, didChangeInput input: AVCaptureDeviceInput) {
        delegate?.setFlashButtonHidden(!input.device.hasFlash)
    }

    func cameraManDidStart(_ cameraMan: CameraMan) {
        setupPreviewLayer()
    }
}
