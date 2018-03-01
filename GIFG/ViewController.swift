//
//  ViewController.swift
//  GIFG
//
//  Created by jote on 2017/10/15.
//  Copyright © 2017年 jote. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {

    let moveToCameraButton = UIButton.init()
    let moveToLibraryButton = UIButton.init()
    let buttonSize = CGSize.init(width: 100, height: 100)
    let disposebag = DisposeBag.init()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = Constants.GIFG_COLORS.LIGHT_BACK_GROUND
        
        moveToLibraryButton.setTitle("写真へ", for: UIControlState.normal)
        moveToLibraryButton.backgroundColor = UIColor.red
        moveToCameraButton.setTitle("かめらへ", for: UIControlState.normal)
        moveToCameraButton.backgroundColor = UIColor.blue
        moveToCameraButton.rx.tap.subscribe(
            onNext: {[weak self] in self?.navigationController?.pushViewController(CameraViewController(), animated: true)}
            ).disposed(by: disposebag)

        view.addSubview(moveToLibraryButton)
        view.addSubview(moveToCameraButton)
    }
    
    override func viewDidLayoutSubviews() {
        let padding:CGFloat = (self.view.bounds.width - 2 * buttonSize.width)/3
        let centerY:CGFloat = (self.view.bounds.height - buttonSize.height)/2
        moveToCameraButton.frame = CGRect.init(x:padding, y: centerY, width: buttonSize.width, height: buttonSize.height )
        moveToLibraryButton.frame = CGRect.init(x:moveToCameraButton.frame.origin.x + buttonSize.width + padding,
                                                y:moveToCameraButton.frame.origin.y,
                                                width: buttonSize.width,
                                                height: buttonSize.height)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

