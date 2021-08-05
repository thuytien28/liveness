//
//  LivenessCheckViewController.swift
//  VRPMLFramework
//
//  Created by Abdul Basit on 17/05/2020.
//  Copyright © 2020 Abdul Basit. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import CoreVideo


protocol CameraPreviewDelegate: class {
    func videoCapture(_ capture: CameraPreview, didCaptureVideoFrame: CVPixelBuffer?, timestamp: CMTime)
}

/**
 This enum holds the state of the camera initialization.
 */
enum CameraConfiguration {

  case success
  case failed
  case permissionDenied
}

final internal class CameraPreview: NSObject, AVCapturePhotoCaptureDelegate {
    
    // MARK: - Properties
    public var previewLayer: AVCaptureVideoPreviewLayer?
    public weak var delegate: CameraPreviewDelegate?
    public var fps = 15
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    let queue = DispatchQueue(label: "camera.queue")
    var lastTimestamp = CMTime()
    
    public var images = [UIImage]()
    private var atImage = 0;

    private let photoOutput = AVCapturePhotoOutput()
    private var cameraConfiguration: CameraConfiguration = .failed
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private let session: AVCaptureSession = AVCaptureSession()

    // override init() {
    //     super.init()
    //     self.attemptToConfigureSession()
    // }

    // MARK: - Setup
    
    public func setUp(sessionPreset: AVCaptureSession.Preset = .hd1280x720,
                      completion: @escaping (Bool) -> Void) {
        self.setUpCamera(sessionPreset: sessionPreset, completion: { success in
            completion(success)
        })
    }
    
    func setUpCamera(sessionPreset: AVCaptureSession.Preset, completion: @escaping (_ success: Bool) -> Void) {
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                          for: .video,
                                                          position: .front) else {
                                                            
                                                            print("Error: no video devices available")
                                                            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Error: could not create AVCaptureDeviceInput")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer
        
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
        ]
        
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // We want the buffers to be in portrait orientation otherwise they are
        // rotated by 90 degrees. Need to set this _after_ addOutput()!
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        
        captureSession.commitConfiguration()
        
        let success = true
        completion(success)
    }
    
    public func start() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    public func stop() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    func handleTakePhoto(value: Int) {
      let photoSettings = AVCapturePhotoSettings()
      if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
          self.atImage = value;
          photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
          photoOutput.capturePhoto(with: photoSettings, delegate: self)
      }
    }

    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        guard let image = UIImage(data: imageData) else {return}
        // self.images.append(image)
        print("handleTakePhoto", self.images.count, self.atImage)
        
        if (self.images.count > self.atImage) {
            self.images.insert(image, at: self.atImage)
        } else {
            self.images.append(image)
        }
    }

    func getImages () -> Array<UIImage> {
      if (self.images == nil) {
        return [UIImage()];
      }
        return self.images;
    }

    func resetData () {
      self.images.removeAll();
    }

}

// MARK: - Extensions

extension CameraPreview: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        // Because lowering the capture device's FPS looks ugly in the preview,
        // we capture at full speed but only call the delegate at its desired
        // framerate.
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let deltaTime = timestamp - lastTimestamp
        if deltaTime >= CMTimeMake(value: 1, timescale: Int32(fps)) {
            lastTimestamp = timestamp
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput,
                              didDrop sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        //print("dropped frame")
    }
}

/**
 AVCaptureVideoDataOutputSampleBufferDelegate
 */
// extension CameraPreview: AVCaptureVideoDataOutputSampleBufferDelegate {

//   /** This method delegates the CVPixelBuffer of the frame seen by the camera currently.
//  */
//   func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

//     // Converts the CMSampleBuffer to a CVPixelBuffer.
//     let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)

//     guard pixelBuffer != nil else {
//       return
//     }

//     // Delegates the pixel buffer to the ViewController.
// //    delegate?.didOutput(pixelBuffer: imagePixelBuffer)
//   }

// }
