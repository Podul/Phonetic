//
//  CWStatusBarNotification.swift
//  CWNotificationDemo
//
//  Created by Cezary Wojcik on 7/12/15.
//  Copyright © 2015 Cezary Wojcik. All rights reserved.
//

import UIKit

// MARK: - enums

@objc public enum CWNotificationStyle: Int {
    case statusBarNotification
    case navigationBarNotification
}

@objc public enum CWNotificationAnimationStyle: Int {
    case top
    case bottom
    case left
    case right
}

@objc public enum CWNotificationAnimationType: Int {
    case replace
    case overlay
}

// MARK: - CWStatusBarNotification

open class CWStatusBarNotification: NSObject {
    // MARK: - properties
    
    private let fontSize: CGFloat = 10.0

    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var dismissHandle: CWDelayedClosureHandle?
    private var isCustomView: Bool
    
    open var notificationLabel: ScrollLabel?
    open var statusBarView: UIView?
    open var notificationTappedClosure: () -> ()
    open var notificationIsShowing = false
    open var notificationIsDismissing = false
    open var notificationWindow: CWWindowContainer?
    
    open var notificationLabelBackgroundColor: UIColor
    open var notificationLabelTextColor: UIColor
    open var notificationLabelFont: UIFont
    open var notificationLabelHeight: CGFloat
    open var customView: UIView?
    open var multiline: Bool
    open var supportedInterfaceOrientations: UIInterfaceOrientationMask
    open var notificationAnimationDuration: TimeInterval
    open var notificationStyle: CWNotificationStyle
    open var notificationAnimationInStyle: CWNotificationAnimationStyle
    open var notificationAnimationOutStyle: CWNotificationAnimationStyle
    open var notificationAnimationType: CWNotificationAnimationType
    open var preferredStatusBarStyle: UIStatusBarStyle
    
    // MARK: - setup
    
    public override init() {
        if let tintColor = UIApplication.shared.delegate?.window??
            .tintColor {
                self.notificationLabelBackgroundColor = tintColor
        } else {
            self.notificationLabelBackgroundColor = UIColor.black
        }
        self.notificationLabelTextColor = UIColor.white
        self.notificationLabelFont = UIFont.systemFont(ofSize: self.fontSize)
        self.notificationLabelHeight = 0.0
        self.customView = nil
        self.multiline = false
        if let supportedInterfaceOrientations = UIApplication
            .shared.keyWindow?.rootViewController?
            .supportedInterfaceOrientations {
                self.supportedInterfaceOrientations = supportedInterfaceOrientations
        } else {
            self.supportedInterfaceOrientations = .all
        }
        self.notificationAnimationDuration = 0.25
        self.notificationStyle = .statusBarNotification
        self.notificationAnimationInStyle = .bottom
        self.notificationAnimationOutStyle = .bottom
        self.notificationAnimationType = .replace
        self.notificationIsDismissing = false
        self.isCustomView = false
        self.preferredStatusBarStyle = .default
        self.dismissHandle = nil
        
        // make swift happy
        self.notificationTappedClosure = {}
        
        super.init()
        
        // create default tap closure
        self.notificationTappedClosure = {
            if !self.notificationIsDismissing {
                self.dismissNotification()
            }
        }
        
        // create tap recognizer
        self.tapGestureRecognizer = UITapGestureRecognizer(target: self,
            action: #selector(CWStatusBarNotification.notificationTapped(_:)))
    }
    
    // MARK: - dimensions
    
    private func getStatusBarHeight() -> CGFloat {
        if self.notificationLabelHeight > 0 {
            return self.notificationLabelHeight
        }
        
        var statusBarHeight = UIApplication.shared.statusBarFrame
            .size.height
        if systemVersionLessThan("8.0.0") && UIApplication.shared.statusBarOrientation.isLandscape {
                statusBarHeight = UIApplication.shared.statusBarFrame.size.width
        }
        return statusBarHeight > 0 ? statusBarHeight: 20
    }
    
    private func getStatusBarWidth() -> CGFloat {
        if systemVersionLessThan("8.0.0") && UIApplication.shared.statusBarOrientation.isLandscape {
                return UIScreen.main.bounds.size.height
        }
        return UIScreen.main.bounds.size.width
    }
    
    private func getStatusBarOffset() -> CGFloat {
        if self.getStatusBarHeight() == 40.0 {
            return -20.0
        }
        return 0.0
    }
    
    private func getNavigationBarHeight() -> CGFloat {
        if UIApplication.shared.statusBarOrientation.isPortrait || UI_USER_INTERFACE_IDIOM() == .pad {
                return 44.0
        }
        return 30.0
    }
    
    private func getNotificationLabelHeight() -> CGFloat {
        switch self.notificationStyle {
        case .navigationBarNotification:
            return self.getStatusBarHeight() + self.getNavigationBarHeight()
        case .statusBarNotification:
            fallthrough
        default:
            return self.getStatusBarHeight()
        }
    }
    
    private func getNotificationLabelTopFrame() -> CGRect {
        return CGRect(x: 0, y: self.getStatusBarOffset() + -1
            * self.getNotificationLabelHeight(), width: self.getStatusBarWidth(),
            height: self.getNotificationLabelHeight())
    }
    
    private func getNotificationLabelBottomFrame() -> CGRect {
        return CGRect(x: 0, y: self.getStatusBarOffset()
            + self.getNotificationLabelHeight(), width: self.getStatusBarWidth(), height: 0)
    }
    
    private func getNotificationLabelLeftFrame() -> CGRect {
        return CGRect(x: -1 * self.getStatusBarWidth(),
            y: self.getStatusBarOffset(), width: self.getStatusBarWidth(),
            height: self.getNotificationLabelHeight())
    }
    
    private func getNotificationLabelRightFrame() -> CGRect {
        return CGRect(x: self.getStatusBarWidth(), y: self.getStatusBarOffset(),
            width: self.getStatusBarWidth(), height: self.getNotificationLabelHeight())
    }
    
    private func getNotificationLabelFrame() -> CGRect {
        return CGRect(x: 0, y: self.getStatusBarOffset(),
            width: self.getStatusBarWidth(), height: self.getNotificationLabelHeight())
    }
    
    // MARK: - screen orientation change
    
    @objc func updateStatusBarFrame() {
        if let view = self.isCustomView ? self.customView :
            self.notificationLabel {
                view.frame = self.getNotificationLabelFrame()
        }
        if let statusBarView = self.statusBarView {
            statusBarView.isHidden = true
        }
    }
    
    // MARK: - on tap
    
    @objc func notificationTapped(_ recognizer: UITapGestureRecognizer) {
        self.notificationTappedClosure()
    }
    
    // MARK: - display helpers
    
    private func setupNotificationView(_ view: UIView) {
        view.clipsToBounds = true
        view.isUserInteractionEnabled = true
        view.addGestureRecognizer(self.tapGestureRecognizer)
        switch self.notificationAnimationInStyle {
        case .top:
            view.frame = self.getNotificationLabelTopFrame()
        case .bottom:
            view.frame = self.getNotificationLabelBottomFrame()
        case .left:
            view.frame = self.getNotificationLabelLeftFrame()
        case .right:
            view.frame = self.getNotificationLabelRightFrame()
        }
    }
    
    private func createNotificationLabelWithMessage(_ message: String) {
        self.notificationLabel = ScrollLabel()
        self.notificationLabel?.numberOfLines = self.multiline ? 0: 1
        self.notificationLabel?.text = message
        self.notificationLabel?.textAlignment = .center
        self.notificationLabel?.adjustsFontSizeToFitWidth = false
        self.notificationLabel?.font = self.notificationLabelFont
        self.notificationLabel?.backgroundColor =
            self.notificationLabelBackgroundColor
        self.notificationLabel?.textColor = self.notificationLabelTextColor
        if self.notificationLabel != nil {
            self.setupNotificationView(self.notificationLabel!)
        }
    }
    
    private func createNotificationWithCustomView(_ view: UIView) {
        self.customView = UIView()
        // no autoresizing masks so that we can create constraints manually
        view.translatesAutoresizingMaskIntoConstraints = false
        self.customView?.addSubview(view)
        
        // setup auto layout constraints so that the custom view that is added
        // is constrained to be the same size as its superview, whose frame will 
        // be altered
        self.customView?.addConstraint(NSLayoutConstraint(item: view,
            attribute: .trailing, relatedBy: .equal, toItem: self.customView,
            attribute: .trailing, multiplier: 1.0, constant: 0.0))
        self.customView?.addConstraint(NSLayoutConstraint(item: view,
            attribute: .leading, relatedBy: .equal, toItem: self.customView,
            attribute: .leading, multiplier: 1.0, constant: 0.0))
        self.customView?.addConstraint(NSLayoutConstraint(item: view,
            attribute: .top, relatedBy: .equal, toItem: self.customView,
            attribute: .top, multiplier: 1.0, constant: 0.0))
        self.customView?.addConstraint(NSLayoutConstraint(item: view,
            attribute: .bottom, relatedBy: .equal, toItem: self.customView,
            attribute: .bottom, multiplier: 1.0, constant: 0.0))
        
        if self.customView != nil {
            self.setupNotificationView(self.customView!)
        }
    }
    
    private func createNotificationWindow() {
        self.notificationWindow = CWWindowContainer(
            frame: UIScreen.main.bounds)
        self.notificationWindow?.backgroundColor = UIColor.clear
        self.notificationWindow?.isUserInteractionEnabled = true
        self.notificationWindow?.autoresizingMask = UIView.AutoresizingMask(arrayLiteral: .flexibleWidth, .flexibleHeight)
        self.notificationWindow?.windowLevel = UIWindow.Level.statusBar
        let rootViewController = CWViewController()
        rootViewController.localSupportedInterfaceOrientations =
            self.supportedInterfaceOrientations
        rootViewController.localPreferredStatusBarStyle =
            self.preferredStatusBarStyle
        self.notificationWindow?.rootViewController = rootViewController
        self.notificationWindow?.notificationHeight =
            self.getNotificationLabelHeight()
    }
    
    private func createStatusBarView() {
        self.statusBarView = UIView(frame: self.getNotificationLabelFrame())
        self.statusBarView?.clipsToBounds = true
        if self.notificationAnimationType == .replace {
            let statusBarImageView = UIScreen.main
                .snapshotView(afterScreenUpdates: true)
            self.statusBarView?.addSubview(statusBarImageView)
        }
        if self.statusBarView != nil {
            self.notificationWindow?.rootViewController?.view
                .addSubview(self.statusBarView!)
            self.notificationWindow?.rootViewController?.view
                .sendSubviewToBack(self.statusBarView!)
        }
    }
    
    // MARK: - frame changing
    
    private func firstFrameChange() {
        guard let view = self.isCustomView ? self.customView :
            self.notificationLabel , self.statusBarView != nil else {
                return
        }
        view.frame = self.getNotificationLabelFrame()
        switch self.notificationAnimationInStyle {
        case .top:
            self.statusBarView!.frame = self.getNotificationLabelBottomFrame()
        case .bottom:
            self.statusBarView!.frame = self.getNotificationLabelTopFrame()
        case .left:
            self.statusBarView!.frame = self.getNotificationLabelRightFrame()
        case .right:
            self.statusBarView!.frame = self.getNotificationLabelLeftFrame()
        }
    }
    
    private func secondFrameChange() {
        guard let view = self.isCustomView ? self.customView :
            self.notificationLabel , self.statusBarView != nil else {
                return
        }
        switch self.notificationAnimationOutStyle {
        case .top:
            self.statusBarView!.frame = self.getNotificationLabelBottomFrame()
        case .bottom:
            self.statusBarView!.frame = self.getNotificationLabelTopFrame()
            view.layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            view.center = CGPoint(x: view.center.x, y: self.getStatusBarOffset()
                + self.getNotificationLabelHeight())
        case .left:
            self.statusBarView!.frame = self.getNotificationLabelRightFrame()
        case .right:
            self.statusBarView!.frame = self.getNotificationLabelLeftFrame()
        }
    }
    
    private func thirdFrameChange() {
        guard let view = self.isCustomView ? self.customView :
            self.notificationLabel , self.statusBarView != nil else {
                return
        }
        self.statusBarView!.frame = self.getNotificationLabelFrame()
        switch self.notificationAnimationOutStyle {
        case .top:
            view.frame = self.getNotificationLabelTopFrame()
        case .bottom:
            view.transform = CGAffineTransform(scaleX: 1.0, y: 0.01)
        case .left:
            view.frame = self.getNotificationLabelLeftFrame()
        case .right:
            view.frame = self.getNotificationLabelRightFrame()
        }
    }
    
    // MARK: - display notification
    
    public func displayNotificationWithMessage(_ message: String,
        completion: @escaping () -> ()) {
            guard !self.notificationIsShowing else {
                return
            }
            self.isCustomView = false
            self.notificationIsShowing = true
            
            // create window
            self.createNotificationWindow()
            
            // create label
            self.createNotificationLabelWithMessage(message)
            
            // create status bar view
            self.createStatusBarView()
            
            // add label to window
            guard let label = self.notificationLabel else {
                return
            }
            self.notificationWindow?.rootViewController?.view.addSubview(label)
            self.notificationWindow?.rootViewController?.view.bringSubviewToFront(label)
            self.notificationWindow?.isHidden = false
            
            // checking for screen orientation change
            NotificationCenter.default.addObserver(self,
                selector: #selector(CWStatusBarNotification.updateStatusBarFrame),
                name: UIApplication.didChangeStatusBarFrameNotification,
                object: nil)
            
            // checking for status bar change
            NotificationCenter.default.addObserver(self,
                selector: #selector(CWStatusBarNotification.updateStatusBarFrame),
                name: UIApplication.willChangeStatusBarFrameNotification,
                object: nil)
            
            // animate
            UIView.animate(withDuration: self.notificationAnimationDuration,
                animations: { () -> () in
                    self.firstFrameChange()
                }) { (finished) -> () in
                    if let delayInSeconds = self.notificationLabel?.scrollTime() {
                        _ = performClosureAfterDelay(Double(delayInSeconds), closure: {
                            () -> () in
                            completion()
                        })
                    }
            }
    }
    
    public func displayNotificationWithMessage(_ message: String,
        forDuration duration: TimeInterval) {
            self.displayNotificationWithMessage(message) { () -> () in
                self.dismissHandle = performClosureAfterDelay(duration, closure: {
                    () -> () in
                    self.dismissNotification()
                })
            }
    }
    
    public func displayNotificationWithAttributedString(
        _ attributedString: NSAttributedString, completion: @escaping () -> ()) {
            self.displayNotificationWithMessage(attributedString.string,
                completion: completion)
            self.notificationLabel?.attributedText = attributedString
    }
    
    public func displayNotificationWithAttributedString(
        _ attributedString: NSAttributedString,
        forDuration duration: TimeInterval) {
            self.displayNotificationWithMessage(attributedString.string,
                forDuration: duration)
            self.notificationLabel?.attributedText = attributedString
    }
    
    public func displayNotificationWithView(_ view: UIView, completion: @escaping () -> ()) {
        guard !self.notificationIsShowing else {
            return
        }
        self.isCustomView = true
        self.notificationIsShowing = true
        
        // create window
        self.createNotificationWindow()
        
        // setup custom view
        self.createNotificationWithCustomView(view)
        
        // create status bar view
        self.createStatusBarView()
        
        // add view to window
        if let rootView = self.notificationWindow?.rootViewController?.view,
            let customView = self.customView {
                rootView.addSubview(customView)
                rootView.bringSubviewToFront(customView)
                self.notificationWindow!.isHidden = false
        }
        
        // checking for screen orientation change
        NotificationCenter.default.addObserver(self,
            selector: #selector(CWStatusBarNotification.updateStatusBarFrame),
            name: UIApplication.didChangeStatusBarFrameNotification,
            object: nil)
        
        // checking for status bar change
        NotificationCenter.default.addObserver(self,
            selector: #selector(CWStatusBarNotification.updateStatusBarFrame),
            name: UIApplication.willChangeStatusBarFrameNotification,
            object: nil)
        
        // animate
        UIView.animate(withDuration: self.notificationAnimationDuration,
            animations: { () -> () in
                self.firstFrameChange()
            }) { (finished) -> () in
                completion()
        }
    }
    
    public func displayNotificationWithView(_ view: UIView,
        forDuration duration: TimeInterval) {
            self.displayNotificationWithView(view) { () -> () in
                self.dismissHandle = performClosureAfterDelay(duration, closure: {
                    self.dismissNotification()
                })
            }
    }
    
    public func dismissNotificationWithCompletion(_ completion: (() -> ())?) {
        cancelDelayedClosure(self.dismissHandle)
        self.notificationIsDismissing = true
        self.secondFrameChange()
        UIView.animate(withDuration: self.notificationAnimationDuration,
            animations: { () -> () in
                self.thirdFrameChange()
            }) { (finished) -> () in
                guard let view = self.isCustomView ? self.customView :
                    self.notificationLabel else {
                        return
                }
                view.removeFromSuperview()
                self.statusBarView?.removeFromSuperview()
                self.notificationWindow?.isHidden = true
                self.notificationWindow = nil
                self.customView = nil
                self.notificationLabel = nil
                self.notificationIsShowing = false
                self.notificationIsDismissing = false
                NotificationCenter.default.removeObserver(self,
                                                          name: UIApplication.didChangeStatusBarFrameNotification,
                                                          object: nil)
                NotificationCenter.default.removeObserver(self,
                                                          name: UIApplication.willChangeStatusBarFrameNotification,
                                                          object: nil)
                if completion != nil {
                    completion!()
                }
        }
    }
    
    public func dismissNotification() {
        self.dismissNotificationWithCompletion(nil)
    }
}
