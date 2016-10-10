//
//  ToastWindow.swift
//  Pods
//
//  Created by Franco Meloni on 05/08/16.
//
//

import UIKit

/**
 Toast screen position
 
 - Bottom: Toast will be shown on the bottom of the screen
 - Top: Toast will be shown on the top of the screen
*/
public enum ToastPosition {
    /**
     Toast will be shown on the bottom of the screen
    */
    case Bottom
    
    /**
     Toast will be shown on the top of the screen
    */
    case Top
}

private let kMaxToastWidth: CGFloat = UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 500 : 300

private let kToastDistance: CGFloat = 100

/**
 No pop time for toast
 */
public let kToastNoPopTime : Double = 0

class ToastWindow: UIWindow {
    private lazy var textLabel: UILabel = {
        let padding = EasyToastConfiguration.toastInnerPadding
        
        let textLabel = UILabel(frame: CGRectMake(padding, padding, CGRectGetHeight(self.toastView.frame) - (padding * 2), CGRectGetWidth(self.toastView.frame) - (padding * 2)))
        textLabel.numberOfLines = 0
        textLabel.font = self.font
        textLabel.textColor = self.textColor
        
        return textLabel
    }()
    
    private lazy var toastView: UIView = {
        let toastView = UIView(frame: CGRectZero)
        
        toastView.backgroundColor = self.toastBgColor
        toastView.layer.cornerRadius = 5
        toastView.clipsToBounds = true
        
        return toastView
    }()
    
    private lazy var containerVC: UIViewController = {
        let containerVC = ToastContainerVC(nibName: nil, bundle: nil)
        containerVC.view.addSubview(self.toastView)
        
        return containerVC
    }()
    
    private let oldWindow: UIWindow?
    
    var toast: QueueToast? {
        didSet {
            let popTime = toast?.popTime ?? kToastNoPopTime
            
            self.text = toast?.message
            self.toastPosition = toast?.position ?? .Bottom
            self.dismissOnTap = popTime == kToastNoPopTime ? true : toast?.dismissOnTap ?? false
            
            if let toastBackgroundColor = toast?.bgColor  {
                self.toastBgColor = toastBackgroundColor
            }
            
            if let toastTextColor = toast?.textColor  {
                self.textColor = toastTextColor
            }
            
            if let font = toast?.font {
                self.font = font
            }
        }
    }
    
    var toastPosition: ToastPosition = .Bottom
    
    var dismissOnTap: Bool = false {
        didSet {
            self.userInteractionEnabled = self.dismissOnTap
        }
    }
    
    var text: String? {
        didSet {
            self.textLabel.text = self.text
        }
    }
    
    var toastBgColor: UIColor = UIColor.blackColor().colorWithAlphaComponent(0.7) {
        didSet {
            self.toastView.backgroundColor = self.toastBgColor
        }
    }
    
    var font: UIFont = UIFont.systemFontOfSize(19) {
        didSet {
            self.textLabel.font = self.font
        }
    }
    
    var textColor: UIColor = UIColor.whiteColor() {
        didSet {
            self.textLabel.textColor = self.textColor
        }
    }
    
    var onToastDimissed: ((toast: ToastWindow) -> ())?
    
    private var tapGestureRecognizer: UITapGestureRecognizer?
    
    private func commonInit() {
        self.opaque = false
        self.backgroundColor = UIColor.clearColor()
        self.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.windowLevel = UIWindowLevelNormal
        self.rootViewController = self.containerVC
        self.toastView.addSubview(self.textLabel)
        self.userInteractionEnabled = false
        
        self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(windowTapped))
        self.addGestureRecognizer(self.tapGestureRecognizer!)
    }
    
    override init(frame: CGRect) {
        self.oldWindow = UIApplication.sharedApplication().keyWindow
        
        super.init(frame: frame)
        
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.oldWindow = UIApplication.sharedApplication().keyWindow
        
        super.init(coder: aDecoder)
        
        self.commonInit()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.toastView.frame = self.toastEndPosition()
    }
    
    func show() {
        self.makeKeyAndVisible()
        self.containerVC.view.frame = UIScreen.mainScreen().applicationFrame
        
        self.toastView.frame = self.toastStartPosition()
        
        let padding = EasyToastConfiguration.toastInnerPadding
        
        self.textLabel.frame = CGRectMake(padding, padding, CGRectGetWidth(self.toastView.frame) - (padding * 2), CGRectGetHeight(self.toastView.frame) - (padding * 2))
        
        UIView.animateWithDuration(EasyToastConfiguration.animationDuration, delay: 0, usingSpringWithDamping: EasyToastConfiguration.dampingRatio, initialSpringVelocity: EasyToastConfiguration.initialSpringVelocity, options: .TransitionNone, animations: {
            self.toastView.frame = self.toastEndPosition()
            }, completion: nil)
    }
    
    
    func dismiss() {
        let lockQueue = dispatch_queue_create("easyToast.toast.dismissQueue", nil)
        dispatch_sync(lockQueue) { [weak self] in
            UIView.animateWithDuration(EasyToastConfiguration.animationDuration, delay: 0, usingSpringWithDamping: EasyToastConfiguration.dampingRatio, initialSpringVelocity: EasyToastConfiguration.initialSpringVelocity, options: .TransitionNone, animations: {
                self?.toastView.frame = self?.toastStartPosition() ?? CGRectZero
            }) { (success) in
                self?.hidden = true
                self?.oldWindow?.makeKeyAndVisible()
                self?.resignKeyWindow()
                
                if let onToastDimissed = self?.onToastDimissed {
                    onToastDimissed(toast: self ?? ToastWindow())
                }
            }
        }
    }
    
    //MARK: Actions
    
    func windowTapped() {
        self.userInteractionEnabled = false
        self.dismiss()
    }
    
    //MARK: Private
    
    private func textSize() -> CGSize {
        let size = self.textLabel.sizeThatFits(CGSizeMake(kMaxToastWidth, CGFloat.max))
        
        return size
    }
    
    private func rectWithY(y: CGFloat) -> CGRect {
        let size = self.textSize()
        
        let padding = EasyToastConfiguration.toastInnerPadding
        
        let viewWidth = (size.width + padding * 2)
        
        return CGRectMake((CGRectGetWidth(self.bounds) - viewWidth)/2, y, viewWidth, size.height +  padding * 2)
    }
    
    private func toastStartPosition() -> CGRect {
        if toastPosition == .Top {
            return self.rectWithY(-self.textSize().height - EasyToastConfiguration.toastInnerPadding * 2 - UIApplication.sharedApplication().statusBarFrame.size.height)
        }
        else {
            return self.rectWithY(CGRectGetHeight(self.bounds))
        }
    }

    private func toastEndPosition() -> CGRect {
        if toastPosition == .Top {
            return self.rectWithY(kToastDistance)
        }
        else {
            return self.rectWithY(CGRectGetHeight(self.bounds) - kToastDistance - self.textSize().height -  EasyToastConfiguration.toastInnerPadding * 2)
        }
    }
}
