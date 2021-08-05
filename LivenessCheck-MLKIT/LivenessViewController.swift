//
//  ViewController.swift
//  LivenessCheck-MLKIT
//
//  Created by Abdul Basit on 17/06/2020.
//  Copyright © 2020 Abdul Basit. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import CoreMedia

final internal class LivenessCheckViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak private var stepIndicator: UILabel!
    @IBOutlet weak private var videoPreview: UIView!
    @IBOutlet weak private var imageLeft: UIImageView!
    @IBOutlet weak private var imageRight: UIImageView!
    @IBOutlet weak private var imageSmile: UIImageView!
    @IBOutlet weak private var buttonReset: UIButton!

    // MARK: - Properties
    private var videoCapture: CameraPreview!
    private var faceDetector: VisionFaceDetector!
    private var timer: Timer?
    private var remainingTime = 0
    private var currentStep = 1
    private let options = VisionFaceDetectorOptions()
    private lazy var vision = Vision.vision()
    private var initialEyeDetect: String?
    
    public var callback: ((_ isSuccess: Bool, _ error: NSError?) -> Void)?
    
    // MARK: - Data
    
    private var detectionOptions = [" 👉🏻 Look Right",
                                    " 👈🏻 Look Left",
                                    " 🙂 Smile :)"]
    private var completedSteps =  [Int]()
    private var images = [UIImage]()
    private var count = 0;
    private var indicator: ANSegmentIndicator?

    // MARK: - Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let screenSize: CGRect = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        let x = screenWidth - ((screenHeight - 100)/2);

        videoPreview.frame = CGRect(x: x / 2, y: 80, width: (screenHeight - 100)/2, height: (screenHeight - 100)/2)
        videoPreview.layer.cornerRadius = (screenHeight - 100)/4;
        videoPreview.contentMode = UIView.ContentMode.scaleToFill
        videoPreview.layer.masksToBounds = true

        stepIndicator.frame = CGRect(x: (screenWidth-220)/2, y: (screenHeight - 100)/2, width: 220, height: 40)
        stepIndicator.textColor = UIColor.red

        let y = 150 + ((screenHeight - 100)/2);
        let height = screenHeight - y - 50;

        imageLeft.frame = CGRect(x: 30, y: y, width: (screenWidth-120) / 3, height: height)
        imageRight.frame = CGRect(x: 60 + ((screenWidth-120) / 3), y: y, width: (screenWidth-120) / 3, height: height)
        imageSmile.frame = CGRect(x: 90 + (2*(screenWidth-120)/3), y: y, width: (screenWidth-120) / 3, height: height)

        overrideUserInterfaceStyle = .dark
        options.performanceMode = .fast
        options.landmarkMode = .all
        options.classificationMode = .all
        options.minFaceSize = CGFloat(0.1)
        faceDetector = vision.faceDetector(options: options)
        setUpCamera()
        stepIndicator.layer.masksToBounds = true
        stepIndicator.clipsToBounds = true
        stepIndicator.layer.cornerRadius = 20
        stepIndicator.text = detectionOptions.first
        
        let segmentWidth =  x/2 + (screenHeight - 40)/2;
        let segmentHeight = x/2 + (screenHeight - 40)/2;

        let segment = ANSegmentIndicator(frame: CGRect(x: (screenWidth - segmentWidth) / 2, y: 40, width: segmentWidth, height: segmentHeight))
        indicator = segment
        self.view.addSubview(segment)
        
        buttonReset.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        buttonReset.frame = CGRect(x: screenWidth - 100, y: 20, width: 100, height: 32)
    }
    
    @objc func buttonAction(sender: UIButton!) {
        print("Button tapped")
        indicator!.updateProgress(percent: 0)
        images.removeAll();
        invalidateAll()
        imageLeft.isHidden = true;
        imageRight.isHidden = true;
        imageSmile.isHidden = true;
        count = 0;
        videoCapture.resetData();
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    // MARK: - SetUp Video
    private func setUpCamera() {
        videoCapture = CameraPreview()
        videoCapture.delegate = self
        videoCapture.fps = 5
        videoCapture.setUp(sessionPreset: .hd1280x720) { success in
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
    
    private func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
    // MARK: - Actions
    
    @IBAction private func restartAction(_ sender: Any) {
        invalidateAll()
    }
    
    // Remove All Checks
    private func invalidateAll() {
        currentStep = 1
        stepIndicator.text = detectionOptions.first
        timer?.invalidate()
        completedSteps.removeAll()
    }
    
    // Setup New Checks
    private func setupAutoDetection() {
        if self.images.count < detectionOptions.count {
            currentStep = randomStepGenerator()
            if (currentStep < detectionOptions.count + 1) {
                stepIndicator.text = detectionOptions[currentStep - 1]
            }
        } else {
            stepIndicator.text = "Done ✅"
            timer?.invalidate()
            self.callback?(true, nil)
           
        }
    }
    
    // Checks Time Management
    private func setupMonitor() {
        remainingTime = 10
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] (_) in
            self?.remainingTime -= 1
            if self?.remainingTime == 0 {
                self?.invalidateAll()
            }
        }
    }
    
    //Random Check Generator
    private func randomStepGenerator () -> Int {
        let newStep = self.currentStep + 1
            return newStep
    }
    
    // MARK: - Detection Checks
    
    private func detectFace(_ pickedImage: UIImage) {
        let visionImage = VisionImage(image: pickedImage)
        faceDetector.process(visionImage) { [weak self] (faces, error) in
            
            guard let self = self, error == nil else {
                return
            }
            // Detect Face
            guard let faces = faces, !faces.isEmpty, faces.count == 1, let face = faces.first else {
                return
            }

            self.validateLiveness(face)
        }
    }
    
    private func validateLiveness(_ face: VisionFace) {
        if (self.images.count == 1) {
            self.imageLeft.image =  self.images[0];
            self.imageLeft.isHidden = false;
        }

        if (self.images.count == 2) {
            self.imageRight.image =  self.images[1];
            self.imageRight.isHidden = false;
        }

        if (self.images.count == 3) {
            self.imageSmile.image =  self.images[2];
            self.imageSmile.isHidden = false;
        }

        if (face.leftEyeOpenProbability > 0.4) {
            if self.currentStep == 1 { // Look Left Check
                if face.headEulerAngleY < -35 {
                    videoCapture.handleTakePhoto(value: 0)
                    self.completedSteps.append(1)
                    self.setupAutoDetection()
                    self.indicator!.updateProgress(percent: 33)

                }
            } else if self.currentStep == 2 { // Look Right Check
                if face.headEulerAngleY > 35 {
                    videoCapture.handleTakePhoto(value: 1)
                    self.completedSteps.append(2)
                    self.setupAutoDetection()
                    self.indicator!.updateProgress(percent: 66)

                }
            } else if self.currentStep == 3 { // Smile Check
                if (face.headEulerAngleY > -3 && face.headEulerAngleY < 3) {
                    videoCapture.handleTakePhoto(value: 2)
                    self.completedSteps.append(3)
                    self.setupAutoDetection()
                    self.indicator!.updateProgress(percent: 100)
                } 
            } else if self.currentStep == 4 {
                self.setupAutoDetection()
            }
        }
    }
    
}

// MARK: - Video Delegate

extension LivenessCheckViewController: CameraPreviewDelegate {
    func videoCapture(_ capture: CameraPreview, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        // the captured image from camera is contained on pixelBuffer
        if let pixelBuffer = pixelBuffer {
            //Stops detecting if all check are completed
            self.images = self.videoCapture.getImages();
            if (self.count == 0 ) {
                self.predictUsingVision(pixelBuffer: pixelBuffer)
                if (self.images.count == self.detectionOptions.count) {
                    self.count += 1;
                }
            } 

        }
    }
}

// MARK: - Pridict Images

extension LivenessCheckViewController {
    
    private func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        let ciimage: CIImage = CIImage(cvImageBuffer: pixelBuffer)
        // crop found word
        let ciContext = CIContext()
        guard let cgImage: CGImage = ciContext.createCGImage(ciimage, from: ciimage.extent) else {
            // end of measure
            return
        }
        let uiImage: UIImage = UIImage(cgImage: cgImage)
        // predict!
        detectFace(uiImage)
    }
}

// MARK: - TableView Delegates

extension LivenessCheckViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detectionOptions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? (UITableViewCell(style: .default, reuseIdentifier: "cell"))
        cell.textLabel?.text = detectionOptions[indexPath.row]
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15)
        if completedSteps.contains(indexPath.row + 1) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
}
