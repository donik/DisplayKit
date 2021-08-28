//
//  TouchDownGestureRecognizer.swift
//  Display
//
//  Created by Данияр Габбасов on 24.04.2020.
//

import Foundation
import UIKit
import UIKit.UIGestureRecognizerSubclass

public class TouchDownGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    public var touchDown: (() -> Void)?
    
    public override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.delegate = self
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let touchDown = self.touchDown {
            touchDown()
        }
    }
}
