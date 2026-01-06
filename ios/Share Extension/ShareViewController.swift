//
//  ShareViewController.swift
//  Share Extension
//
//  Created by Ibrahim on 1/6/26.
//

import UIKit
import receive_sharing_intent

class ShareViewController: RSIShareViewController {
    override func shouldAutoRedirect() -> Bool {
        return false
    }
}
