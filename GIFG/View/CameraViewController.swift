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
    var session : AVCaptureSession!
    var imageOutPut : AVCapturePhotoOutput!
    var images = Array<UIImage>()
    
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
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            let videoInput = try! AVCaptureDeviceInput.init(device: device)
            session.addInput(videoInput)
            session.addOutput(imageOutPut)
            let previewLayer = AVCaptureVideoPreviewLayer.init(session: session) //TODO nilのときがある?
            previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
            view.layer.addSublayer(previewLayer)
            session.startRunning()
        }else {
            return //TODO error
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
    }
    
    override func viewDidLayoutSubviews() {
        let h = (view.bounds.height - Constants.Layout.DefautPadding * 2.0) / 2.0
        label.frame = CGRect.init(x: 0, y: 0, width: h * ( 16.0 / 25.0 ), height: h)
        label.center = view.center
        view.layer.sublayers?.first?.frame = view.bounds
        
        button.frame = CGRect.init(x: label.center.x - 50.0, y: view.bounds.height - 100.0, width: 100.0, height: 100.0)
        createButton.frame = CGRect.init(x: button.frame.origin.x + 150, y: view.bounds.height - 100.0, width: 100.0, height: 100.0)
    }
    
    func createGif() -> Void {
        if (images.isEmpty) { return }
        let url = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(NSUUID().uuidString).gif")!
        print(url)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypeGIF, images.count, nil) else {
            print("gifの distination に失敗")
            return
        }
        let properties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String : 0]] as CFDictionary
        print("gif properties")
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
            print(error.localizedDescription)
            return
        }
        if let data = photo.fileDataRepresentation() {
            images.append(UIImage(data: data)!)
        }
    }
}

