//
//  TestButton.swift
//  ActionStageSwift
//
//  Created by Hanguang on 07/04/2017.
//  Copyright © 2017 Hanguang. All rights reserved.
//

import UIKit

class TestButton: UIButton {
    var extendedEdgeInsets: UIEdgeInsets?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !isHidden && alpha > CGFloat.ulpOfOne {
            if let extendedEdgeInsets = extendedEdgeInsets {
                var bounds = self.bounds
                bounds.origin.x -= extendedEdgeInsets.left
                bounds.size.width += extendedEdgeInsets.left + extendedEdgeInsets.right
                bounds.origin.y -= extendedEdgeInsets.top + extendedEdgeInsets.bottom
                bounds.size.height += extendedEdgeInsets.top + extendedEdgeInsets.bottom
                if bounds.contains(point) {
                    return self
                }
            }
        }
        
        return super.hitTest(point, with: event)
    }
}
