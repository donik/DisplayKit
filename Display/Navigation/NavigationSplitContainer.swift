//
//  NavigationSplitContainer.swift
//  Display
//
//  Created by Данияр Габбасов on 09.04.2020.
//

import Foundation
import AsyncDisplayKit

public protocol MasterDetailEmptyDelegate: NSObjectProtocol {
    func detailTitle() -> NSAttributedString
    
}

enum NavigationSplitContainerScrollToTop {
    case master
    case detail
}

final class NavigationSplitContainer: ASDisplayNode {
    private var theme: NavigationControllerTheme
    
    private let masterScrollToTopView: ScrollToTopView
    private let detailScrollToTopView: ScrollToTopView
    private let masterContainer: NavigationContainer
    private let detailContainer: NavigationContainer
    private let separator: ASDisplayNode
    private let separatorLeft: ASDisplayNode
    private let separatorRight: ASDisplayNode
    
    private(set) var masterControllers: [ViewController] = []
    private(set) var detailControllers: [ViewController] = []
    
    private let textLabel: UILabel
    
    var canHaveKeyboardFocus: Bool = false {
        didSet {
            self.masterContainer.canHaveKeyboardFocus = self.canHaveKeyboardFocus
            self.detailContainer.canHaveKeyboardFocus = self.canHaveKeyboardFocus
        }
    }
    
    init(theme: NavigationControllerTheme, controllerRemoved: @escaping (ViewController) -> Void, scrollToTop: @escaping (NavigationSplitContainerScrollToTop) -> Void) {
        self.theme = theme
        
        self.masterScrollToTopView = ScrollToTopView(frame: CGRect())
        self.masterScrollToTopView.action = {
            scrollToTop(.master)
        }
        self.detailScrollToTopView = ScrollToTopView(frame: CGRect())
        self.detailScrollToTopView.action = {
            scrollToTop(.detail)
        }
        
        self.masterContainer = NavigationContainer(controllerRemoved: controllerRemoved)
        self.masterContainer.clipsToBounds = true
        
        self.detailContainer = NavigationContainer(controllerRemoved: controllerRemoved)
        self.detailContainer.clipsToBounds = true
        
        self.separator = ASDisplayNode()
        self.separator.backgroundColor = theme.navigationBar.separatorColor
        
        self.separatorLeft = ASDisplayNode()
        self.separatorLeft.backgroundColor = theme.navigationBar.separatorColor
        
        self.separatorRight = ASDisplayNode()
        self.separatorRight.backgroundColor = theme.navigationBar.separatorColor
        
        self.textLabel = UILabel()
        self.textLabel.numberOfLines = 0
        self.textLabel.font = Font.bold(16)
        self.textLabel.textAlignment = .center
        
        super.init()
        
        self.addSubnode(self.masterContainer)
        self.view.addSubview(self.textLabel)
        self.addSubnode(self.detailContainer)
        self.addSubnode(self.separator)
        self.addSubnode(self.separatorLeft)
        self.addSubnode(self.separatorRight)
        self.view.addSubview(self.masterScrollToTopView)
        self.view.addSubview(self.detailScrollToTopView)
    }
    
    func hasNonReadyControllers() -> Bool {
        if self.masterContainer.hasNonReadyControllers() {
            return true
        }
        if self.detailContainer.hasNonReadyControllers() {
            return true
        }
        return false
    }
    
    func updateTheme(theme: NavigationControllerTheme) {
        self.separator.backgroundColor = theme.navigationBar.separatorColor
        self.separatorLeft.backgroundColor = theme.navigationBar.separatorColor
        self.separatorRight.backgroundColor = theme.navigationBar.separatorColor
    }
    
    private func safe(_ layout: ContainerViewLayout) -> UIEdgeInsets {
        return UIEdgeInsets(top: layout.safeInsets.top, left: 0, bottom: layout.safeInsets.bottom, right: 0)
    }
    
    func update(layout: ContainerViewLayout, masterControllers: [ViewController], detailControllers: [ViewController], transition: ContainedViewLayoutTransition) {
        let horizontalInsets = max(layout.safeInsets.left, layout.safeInsets.right)
        
        let masterWidth = min(max(320.0, floor(layout.size.width / 3.0)), floor(layout.size.width / 2.0))
        let detailWidth = layout.size.width - masterWidth - (horizontalInsets * 2)
        
        self.masterScrollToTopView.frame = CGRect(origin: CGPoint(x: horizontalInsets, y: -1.0), size: CGSize(width: masterWidth, height: 1.0))
        self.detailScrollToTopView.frame = CGRect(origin: CGPoint(x: masterWidth + horizontalInsets, y: -1.0), size: CGSize(width: detailWidth, height: 1.0))
        
        transition.updateFrame(node: self.masterContainer, frame: CGRect(origin: CGPoint(x: horizontalInsets, y: 0.0), size: CGSize(width: masterWidth, height: layout.size.height)))
        transition.updateFrame(node: self.detailContainer, frame: CGRect(origin: CGPoint(x: masterWidth + horizontalInsets, y: 0.0), size: CGSize(width: detailWidth, height: layout.size.height)))
        transition.updateFrame(node: self.separator, frame: CGRect(origin: CGPoint(x: masterWidth + horizontalInsets, y: 0.0), size: CGSize(width: CCScreenPixel, height: layout.size.height)))
        transition.updateFrame(node: self.separatorLeft, frame: CGRect(origin: CGPoint(x: horizontalInsets - 1.0, y: 0.0), size: CGSize(width: CCScreenPixel, height: layout.size.height)))
        transition.updateFrame(node: self.separatorRight, frame: CGRect(origin: CGPoint(x: layout.size.width - horizontalInsets + 1.0, y: 0.0), size: CGSize(width: CCScreenPixel, height: layout.size.height)))
        
        if masterControllers.count > 0 {
            var title = NSAttributedString()
            if let delegate = masterControllers.first?.navigationController as? MasterDetailEmptyDelegate {
                title = delegate.detailTitle()
            }
            
            self.textLabel.attributedText = title
            self.textLabel.frame = CGRect(x: masterWidth + horizontalInsets, y: (layout.size.height - 44) / 2, width: detailWidth, height: 44)
            self.textLabel.isHidden = false
        } else {
            self.textLabel.isHidden = true
        }
        
        self.masterContainer.update(
            layout: ContainerViewLayout(
                size: CGSize(width: masterWidth, height: layout.size.height),
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                intrinsicInsets: layout.intrinsicInsets,
                safeInsets: self.safe(layout),
                statusBarHeight: layout.statusBarHeight,
                inputHeight: layout.inputHeight,
                inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging,
                inVoiceOver: layout.inVoiceOver
            ),
            canBeClosed: false,
            controllers: masterControllers,
            transition: transition
        )
        self.detailContainer.update(
            layout: ContainerViewLayout(
                size: CGSize(width: detailWidth, height: layout.size.height),
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                intrinsicInsets: layout.intrinsicInsets,
                safeInsets: self.safe(layout),
                statusBarHeight: layout.statusBarHeight,
                inputHeight: layout.inputHeight,
                inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging,
                inVoiceOver: layout.inVoiceOver
            ),
            canBeClosed: true,
            controllers: detailControllers,
            transition: transition
        )
        
        var controllersUpdated = false
        if self.detailControllers.last !== detailControllers.last {
            controllersUpdated = true
        } else if self.masterControllers.count != masterControllers.count {
            controllersUpdated = true
        } else {
            for i in 0 ..< masterControllers.count {
                if masterControllers[i] !== self.masterControllers[i] {
                    controllersUpdated = true
                    break
                }
            }
        }
        
        self.masterControllers = masterControllers
        self.detailControllers = detailControllers
        
        if controllersUpdated {
            let data = self.detailControllers.last?.customData
            for controller in self.masterControllers {
                controller.updateNavigationCustomData(data, progress: 1.0, transition: transition)
            }
        }
    }
}
