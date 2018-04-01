//
//  CameraViewController.swift
//  GIFG
//
//  Created by jote on 2017/11/08.
//  Copyright © 2017年 jote. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import RxSwift
import RxCocoa
import ImageIO
import MobileCoreServices
import Photos

class CameraViewController: UIViewController {
    
    let label = UILabel.init()
    let button = UIButton.init()
    let createButton = UIButton.init()
    let disposebag = DisposeBag.init()
    let frameRatet = CMTimeMake(1, 5)
    var pointInterest: Variable<CGPoint> = Variable(CGPoint.zero)
    var session: AVCaptureSession!
    var imageOutPut: AVCapturePhotoOutput!
    var videoInput: AVCaptureDeviceInput!
    var images = Array<UIImage>()
    var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        edgesForExtendedLayout = []
        view.backgroundColor = Constants.GIFG_COLORS.LIGHT_BACK_GROUND;

        label.text = "+"
        label.textAlignment = .center
        label.backgroundColor = UIColor.clear
        label.textColor = UIColor.red
        label.layer.borderColor = UIColor.red.cgColor
        label.layer.borderWidth = 2.0
        
        session = AVCaptureSession()
        imageOutPut = AVCapturePhotoOutput()
        imageOutPut.isHighResolutionCaptureEnabled = true
        do {
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                videoInput = try AVCaptureDeviceInput.init(device: device)
                session.addInput(videoInput)
                session.addOutput(imageOutPut)
                previewLayer = AVCaptureVideoPreviewLayer.init(session: session)
                previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
                view.layer.addSublayer(previewLayer)
                session.startRunning()
                setOrientation()
            }else {
                self.toast(message: "カメラを開けませんでした")
                return
            }
        } catch {
            //TODO errorログ
            self.toast(message: "カメラを開けませんでした")
        }
        view.addSubview(label)
        
        button.backgroundColor = UIColor.white
        button.layer.cornerRadius = 0.5
        button.rx.tap.subscribe(onNext: { [weak self] in
            print("tap take a picture")
            if let _ = self {
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                self!.imageOutPut.capturePhoto(with: settings, delegate: self! as AVCapturePhotoCaptureDelegate)
            }
        }).disposed(by: disposebag)
        view.addSubview(button)
        
        createButton.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
        createButton.rx.tap.subscribe(onNext: { [weak self] in
            print("tap create a gif image.")
            self?.createGif()
        }).disposed(by: disposebag)
        view.addSubview(createButton)
        let tapgesture = UITapGestureRecognizer()
        view.addGestureRecognizer(tapgesture)
        tapgesture.rx.event.bind(onNext: { [weak self] x in
            print("gesture point: \(x.location(in: self?.view))")
            self?.pointInterest.value = x.location(in: self?.view)
        } ).disposed(by: disposebag)

        pointInterest.asObservable().distinctUntilChanged().subscribe(onNext: { [weak self] x in self?.focusOn(); }).disposed(by: disposebag)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(self.setOrientation(notification:)), name: .UIDeviceOrientationDidChange, object: nil)
    }

    @objc func setOrientation(notification: Notification) -> Void { setOrientation() }

    func setOrientation() -> Void {
        let deviceOrientation = UIDevice.current.orientation

         //対応していない回転方向はnil
        let previewOrientationMap : [ UIDeviceOrientation : AVCaptureVideoOrientation? ] = [
            .portrait : .portrait,
            .portraitUpsideDown : nil,
            .landscapeLeft : .landscapeRight,
            .landscapeRight : .landscapeLeft,
            .faceUp : .portrait,
            .faceDown : nil,
            .unknown : .portrait
        ]

        print("カメラ回転 device: \( deviceOrientation.hashValue )")
        if let connection = previewLayer.connection, let outputConnection = imageOutPut.connection(with: .video)
        {
            guard let orientation = previewOrientationMap[deviceOrientation]! else { return } //対応していない回転方向の時は 前の回転状態を保つ
            if(connection.isVideoOrientationSupported) { connection.videoOrientation = orientation }
            if(outputConnection.isVideoOrientationSupported) { outputConnection.videoOrientation = orientation }
        }
    }

    func setPoint(touchPoint: CGPoint) -> Void {
        pointInterest.value = CGPoint(x: touchPoint.y / view.bounds.height, y: 1.0 - touchPoint.y/view.bounds.width)
    }

    func focusOn() -> Void {
        do {
            try videoInput.device.lockForConfiguration()
            defer { videoInput.device.unlockForConfiguration() }
            if videoInput.device.isFocusPointOfInterestSupported && videoInput.device.isFocusModeSupported(.continuousAutoFocus) {
                videoInput.device.focusPointOfInterest = pointInterest.value
                videoInput.device.focusMode = .continuousAutoFocus

                print("focus しました: \(pointInterest.value)")
            }
            if videoInput.device.isExposurePointOfInterestSupported && videoInput.device.isExposureModeSupported(.autoExpose) {
                videoInput.device.exposurePointOfInterest = pointInterest.value
                videoInput.device.exposureMode = .autoExpose

                print("exposure しました")
            }
        } catch {
            //erroe処理
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self, name: .UIDeviceOrientationDidChange, object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    override func viewDidLayoutSubviews() {
        let h = (view.bounds.height - Constants.Layout.DefautPadding * 2.0) / 2.0
        label.frame = CGRect.init(x: 0, y: 0, width: h * ( 16.0 / 25.0 ), height: h)
        label.center = view.center
        view.layer.sublayers?.first?.frame = view.bounds
        
        button.frame = CGRect.init(x: view.bounds.size.width - 130 , y: (view.bounds.height - 100.0)/2 , width: 100.0, height: 100.0)
        createButton.frame = CGRect.init(x: button.frame.origin.x, y: view.bounds.height - 100.0, width: 100.0, height: 100.0)
    }

    func createGif() -> Void {
        if (images.isEmpty) { return }
        let url = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(NSUUID().uuidString).gif")!
        print(url)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeGIF, images.count, nil) else {
            print("gifの distination に失敗")
            return
        }
        let orientation = imageOutPut.connection(with: .video)?.videoOrientation ?? AVCaptureVideoOrientation.portrait
        let properties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String : 0]] as CFDictionary
        CGImageDestinationSetProperties(destination, properties)

        let frameProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String : 0.2]] as CFDictionary
        for image in images {
            print("image 追加")
            CGImageDestinationAddImage(destination, image.cgImage!, frameProperties)
        }
        
        if CGImageDestinationFinalize(destination) {
            print("GIF生成")
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            }, completionHandler: {(res, error) in
                if (error == nil) {
                    self.toast(message: "写真へ保存しました")
                    self.cleanGif(url: url)
                } else {
                    self.toast(message: "写真への保存に失敗しました")
                }; })
        } else {
            print("GIF生成に失敗")
        }
    }

    func cleanGif(url: URL) -> Void {
        let manager = FileManager()
        try? manager.removeItem(at: url)
        images.removeAll()
        print("clean up")
    }

    func toast(message: String) -> Void {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        self.present(alert, animated: true, completion: {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: {
                alert.dismiss(animated: true, completion: nil)
            })
        })
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            self.toast(message: "エラーが発生しました")
            print(error.localizedDescription)
            return
        }

        let orientationMap : [AVCaptureVideoOrientation : UIImageOrientation] = [
            .portrait : .right,
            .portraitUpsideDown : .left,
            .landscapeLeft : .down,
            .landscapeRight : .up
        ]

        if let data = photo.fileDataRepresentation(withReplacementMetadata: photo.metadata,
                                                   replacementEmbeddedThumbnailPhotoFormat: photo.embeddedThumbnailPhotoFormat,
                                                   replacementEmbeddedThumbnailPixelBuffer: photo.pixelBuffer,
                                                   replacementDepthData: photo.depthData),
            let connection = output.connection(with: .video),
            let ii = UIImage(data: data) {
            guard let t = transformImage(image: ii, orientation: orientationMap[connection.videoOrientation]!) else { self.toast(message: "画像の生成に失敗しました。"); return }
            images.append(t)
        }
    }

    func transformImage(image: UIImage, orientation: UIImageOrientation) -> UIImage? {
        UIGraphicsBeginImageContext(image.size)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: image.size.width/2, y: image.size.height/2)
        let scale: Array<CGFloat>
        if(orientation == .down || orientation == .up) { scale = [1.0, -1.0] } else { scale = [-1.0, 1.0] }
        context.scaleBy(x: scale[0], y: scale[1])

        let radianMap: [UIImageOrientation : CGFloat] = [
            .right : 90 * CGFloat.pi / 180,//ホームボタン下
            .left  : 270 * CGFloat.pi / 180,//ホームボタン上
            .down : 180 * CGFloat.pi / 180,//ホームボタン左
            .up :   0 * CGFloat.pi / 180,//ホームボタン右
        ]
        context.rotate(by: radianMap[orientation]!)

        let rect: CGRect
        if(orientation == .right || orientation == .left) {
            rect = CGRect(x: -image.size.height/2, y: -image.size.width/2, width: image.size.height, height: image.size.width)
        }else {
            rect = CGRect(x: -image.size.width/2, y: -image.size.height/2, width: image.size.width, height: image.size.height)
        }
        guard let cgimage = image.cgImage else { return nil }
        context.draw(cgimage, in: rect)
        let transformed = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return transformed
    }
}

