import Foundation
import AsyncDisplayKit

private let alertWidth: CGFloat = 270.0

public enum TextAlertActionType {
    case genericAction
    case defaultAction
    case destructiveAction
}

public struct TextAlertAction {
    public let type: TextAlertActionType
    public let title: String
    public let action: () -> Void
    
    public init(type: TextAlertActionType, title: String, action: @escaping () -> Void) {
        self.type = type
        self.title = title
        self.action = action
    }
}

public final class TextAlertContentActionNode: HighlightableButtonNode {
    private var theme: AlertControllerTheme
    let action: TextAlertAction
    
    private let backgroundNode: ASDisplayNode
    
    public init(theme: AlertControllerTheme, action: TextAlertAction) {
        self.theme = theme
        self.action = action
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.alpha = 0.0
        
        super.init()
        
        self.titleNode.maximumNumberOfLines = 2
        
        self.highligthedChanged = { [weak self] value in
            if let strongSelf = self {
                if value {
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 1.0
                } else if !strongSelf.backgroundNode.alpha.isZero {
                    strongSelf.backgroundNode.alpha = 0.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                }
            }
        }
        
        self.updateTheme(theme)
    }
    
    public var actionEnabled: Bool = true {
        didSet {
            self.isUserInteractionEnabled = self.actionEnabled
            self.updateTitle()
        }
    }
    
    public func updateTheme(_ theme: AlertControllerTheme) {
        self.theme = theme
        self.backgroundNode.backgroundColor = theme.highlightedItemColor
        self.updateTitle()
    }
    
    private func updateTitle() {
        var font = Font.regular(theme.baseFontSize)
        var color: UIColor
        switch self.action.type {
            case .defaultAction, .genericAction:
                color = self.actionEnabled ? self.theme.accentColor : self.theme.disabledColor
            case .destructiveAction:
                color = self.actionEnabled ? self.theme.destructiveColor : self.theme.disabledColor
        }
        switch self.action.type {
            case .defaultAction:
                font = Font.semibold(theme.baseFontSize)
            case .destructiveAction, .genericAction:
                break
        }
        self.setAttributedTitle(NSAttributedString(string: self.action.title, font: font, textColor: color), for: [])
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc func pressed() {
        self.action.action()
    }
    
    override public func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
    }
}

public enum TextAlertContentActionLayout {
    case horizontal
    case vertical
}

public final class ProgressAlertContentNode: AlertContentNode {
    private var theme: AlertControllerTheme
    private let actionLayout: TextAlertContentActionLayout
    
    private let titleNode: ASTextNode?
    private let textNode: ImmediateTextNode
    private var progressView: UIProgressView?
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    public override var dismissOnOutsideTap: Bool {
        return false
    }
    
    public var textAttributeAction: (NSAttributedString.Key, (Any) -> Void)? {
        didSet {
            if let (attribute, textAttributeAction) = self.textAttributeAction {
                self.textNode.highlightAttributeAction = { attributes in
                    if let _ = attributes[attribute] {
                        return attribute
                    } else {
                        return nil
                    }
                }
                self.textNode.tapAttributeAction = { attributes in
                    if let value = attributes[attribute] {
                        textAttributeAction(value)
                    }
                }
                self.textNode.linkHighlightColor = self.theme.accentColor.withAlphaComponent(0.5)
            } else {
                self.textNode.highlightAttributeAction = nil
                self.textNode.tapAttributeAction = nil
            }
        }
    }
    
    public init(theme: AlertControllerTheme, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout) {
        self.theme = theme
        self.actionLayout = actionLayout
        if let title = title {
            let titleNode = ASTextNode()
            titleNode.attributedText = NSAttributedString(
                string: title,
                font: .boldSystemFont(ofSize: 16.0),
                textColor: theme.primaryColor
            )
            titleNode.displaysAsynchronously = false
            titleNode.isUserInteractionEnabled = false
            titleNode.maximumNumberOfLines = 2
            titleNode.truncationMode = .byTruncatingTail
            titleNode.isAccessibilityElement = true
            self.titleNode = titleNode
        } else {
            self.titleNode = nil
        }
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.attributedText = NSAttributedString(
            string: text,
            font: .systemFont(ofSize: 14.0),
            textColor: theme.primaryColor
        )
        self.textNode.displaysAsynchronously = false
        self.textNode.isLayerBacked = false
        self.textNode.isAccessibilityElement = true
        self.textNode.accessibilityLabel = text
        self.textNode.insets = UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                separatorNode.backgroundColor = theme.separatorColor
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        if let titleNode = self.titleNode {
            self.addSubnode(titleNode)
        }
        self.addSubnode(self.textNode)

        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.progressView = UIProgressView()
        self.progressView?.tintColor = self.theme.accentColor
        self.view.addSubview(progressView!)
    }
    
    public func updateProgress(progress: Float, text: String, animated: Bool = true) {
        guard let validLayout = self.validLayout else {
            return
        }
        self.progressView?.progress = progress
        self.textNode.attributedText = NSAttributedString(
            string: text,
            font: .systemFont(ofSize: 14.0),
            textColor: theme.primaryColor
        )
        let _ = self.updateLayout(
            size: validLayout,
            transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate
        )
    }
    
    override public func updateTheme(_ theme: AlertControllerTheme) {
        self.theme = theme
        
        if let titleNode = self.titleNode, let attributedText = titleNode.attributedText {
            let updatedText = NSMutableAttributedString(attributedString: attributedText)
            updatedText.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.primaryColor, range: NSRange(location: 0, length: updatedText.length))
            titleNode.attributedText = updatedText
        }
        if let attributedText = self.textNode.attributedText {
            let updatedText = NSMutableAttributedString(attributedString: attributedText)
            updatedText.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.primaryColor, range: NSRange(location: 0, length: updatedText.length))
            self.textNode.attributedText = updatedText
        }

        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
        
        self.progressView?.tintColor = self.theme.accentColor
        
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    override public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        self.validLayout = size
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var size = size
        size.width = min(size.width, alertWidth)
        
        var titleSize: CGSize?
        if let titleNode = self.titleNode {
            titleSize = titleNode.measure(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        }
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        
        let actionButtonHeight: CGFloat = 44.0
        
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = self.actionLayout
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.measure(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
                case .horizontal:
                    minActionsWidth += actionTitleSize.width + actionTitleInsets
                case .vertical:
                    minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        
        var resultSize: CGSize
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let contentWidth = alertWidth - insets.left - insets.right
        if let titleNode = self.titleNode, let titleSize = titleSize {
            let spacing: CGFloat = 6.0
            let titleFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - titleSize.width) / 2.0), y: insets.top), size: titleSize)
            transition.updateFrame(node: titleNode, frame: titleFrame)
            
            let textFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - textSize.width) / 2.0), y: titleFrame.maxY + spacing), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame.offsetBy(dx: -1.0, dy: -1.0))
            
            resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: titleSize.height + spacing + textSize.height + actionsHeight + insets.top + insets.bottom)
        } else {
            let textFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - textSize.width) / 2.0), y: insets.top), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame)
            
            resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: textSize.height + actionsHeight + insets.top + insets.bottom)
        }
        
        resultSize.height += 10
        
        self.progressView?.frame = CGRect(x: 8.0, y: resultSize.height - actionsHeight - CCScreenPixel - 12.0, width: resultSize.width - 16, height: 2.0)
        self.actionNodesSeparator.frame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - CCScreenPixel), size: CGSize(width: resultSize.width, height: CCScreenPixel))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - CCScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: CCScreenPixel, height: actionsHeight - CCScreenPixel)))
                    case .vertical:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - CCScreenPixel), size: CGSize(width: resultSize.width, height: CCScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            switch effectiveActionLayout {
                case .horizontal:
                    if nodeIndex == self.actionNodes.count - 1 {
                        currentActionWidth = resultSize.width - actionOffset
                    } else {
                        currentActionWidth = actionWidth
                    }
                case .vertical:
                    currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        return resultSize
    }
}

public final class TextAlertContentNode: AlertContentNode {
    private var theme: AlertControllerTheme
    private let actionLayout: TextAlertContentActionLayout
    
    private let titleNode: ASTextNode?
    private let textNode: ImmediateTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    public var textAttributeAction: (NSAttributedString.Key, (Any) -> Void)? {
        didSet {
            if let (attribute, textAttributeAction) = self.textAttributeAction {
                self.textNode.highlightAttributeAction = { attributes in
                    if let _ = attributes[attribute] {
                        return attribute
                    } else {
                        return nil
                    }
                }
                self.textNode.tapAttributeAction = { attributes in
                    if let value = attributes[attribute] {
                        textAttributeAction(value)
                    }
                }
                self.textNode.linkHighlightColor = self.theme.accentColor.withAlphaComponent(0.5)
            } else {
                self.textNode.highlightAttributeAction = nil
                self.textNode.tapAttributeAction = nil
            }
        }
    }
    
    public init(theme: AlertControllerTheme, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout) {
        self.theme = theme
        self.actionLayout = actionLayout
        if let title = title {
            let titleNode = ASTextNode()
            titleNode.attributedText = title
            titleNode.displaysAsynchronously = false
            titleNode.isUserInteractionEnabled = false
            titleNode.maximumNumberOfLines = 2
            titleNode.truncationMode = .byTruncatingTail
            titleNode.isAccessibilityElement = true
            self.titleNode = titleNode
        } else {
            self.titleNode = nil
        }
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.attributedText = text
        self.textNode.displaysAsynchronously = false
        self.textNode.isLayerBacked = false
        self.textNode.isAccessibilityElement = true
        self.textNode.accessibilityLabel = text.string
        self.textNode.insets = UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
        if text.length != 0 {
            if let paragraphStyle = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                self.textNode.textAlignment = paragraphStyle.alignment
            }
        }
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                separatorNode.backgroundColor = theme.separatorColor
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        if let titleNode = self.titleNode {
            self.addSubnode(titleNode)
        }
        self.addSubnode(self.textNode)

        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
    }
    
    override public func updateTheme(_ theme: AlertControllerTheme) {
        self.theme = theme
        
        if let titleNode = self.titleNode, let attributedText = titleNode.attributedText {
            let updatedText = NSMutableAttributedString(attributedString: attributedText)
            updatedText.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.primaryColor, range: NSRange(location: 0, length: updatedText.length))
            titleNode.attributedText = updatedText
        }
        if let attributedText = self.textNode.attributedText {
            let updatedText = NSMutableAttributedString(attributedString: attributedText)
            updatedText.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.primaryColor, range: NSRange(location: 0, length: updatedText.length))
            self.textNode.attributedText = updatedText
        }

        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
        
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    override public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        self.validLayout = size
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var size = size
        size.width = min(size.width, alertWidth)
        
        var titleSize: CGSize?
        if let titleNode = self.titleNode {
            titleSize = titleNode.measure(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        }
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        
        let actionButtonHeight: CGFloat = 44.0
        
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = self.actionLayout
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.measure(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
                case .horizontal:
                    minActionsWidth += actionTitleSize.width + actionTitleInsets
                case .vertical:
                    minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        
        let resultSize: CGSize
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let contentWidth = alertWidth - insets.left - insets.right
        if let titleNode = self.titleNode, let titleSize = titleSize {
            let spacing: CGFloat = 6.0
            let titleFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - titleSize.width) / 2.0), y: insets.top), size: titleSize)
            transition.updateFrame(node: titleNode, frame: titleFrame)
            
            let textFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - textSize.width) / 2.0), y: titleFrame.maxY + spacing), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame.offsetBy(dx: -1.0, dy: -1.0))
            
            resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: titleSize.height + spacing + textSize.height + actionsHeight + insets.top + insets.bottom)
        } else {
            let textFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - textSize.width) / 2.0), y: insets.top), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame)
            
            resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: textSize.height + actionsHeight + insets.top + insets.bottom)
        }
        
        self.actionNodesSeparator.frame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - CCScreenPixel), size: CGSize(width: resultSize.width, height: CCScreenPixel))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - CCScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: CCScreenPixel, height: actionsHeight - CCScreenPixel)))
                    case .vertical:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - CCScreenPixel), size: CGSize(width: resultSize.width, height: CCScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            switch effectiveActionLayout {
                case .horizontal:
                    if nodeIndex == self.actionNodes.count - 1 {
                        currentActionWidth = resultSize.width - actionOffset
                    } else {
                        currentActionWidth = actionWidth
                    }
                case .vertical:
                    currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        return resultSize
    }
}

public func textAlertController(theme: AlertControllerTheme, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal) -> AlertController {
    return AlertController(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: title, text: text, actions: actions, actionLayout: actionLayout))
}

public func standardTextAlertController(theme: AlertControllerTheme, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, parseMarkdown: Bool = false) -> AlertController {
    var dismissImpl: (() -> Void)?
    let attributedText: NSAttributedString
    if parseMarkdown {
        let font = title == nil ? Font.semibold(theme.baseFontSize * 13.0 / 17.0) : Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        let boldFont = title == nil ? Font.bold(theme.baseFontSize * 13.0 / 17.0) : Font.semibold(floor(theme.baseFontSize * 13.0 / 17.0))
        let body = MarkdownAttributeSet(font: font, textColor: theme.primaryColor)
        let bold = MarkdownAttributeSet(font: boldFont, textColor: theme.primaryColor)
        attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil }), textAlignment: .center)
    } else {
        attributedText = NSAttributedString(string: text, font: title == nil ? Font.semibold(theme.baseFontSize) : Font.regular(floor(theme.baseFontSize * 13.0 / 17.0)), textColor: theme.primaryColor)
    }
    let controller = AlertController(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: title != nil ? NSAttributedString(string: title!, font: Font.semibold(theme.baseFontSize), textColor: theme.primaryColor) : nil, text: attributedText, actions: actions.map { action in
        return TextAlertAction(type: action.type, title: action.title, action: {
            dismissImpl?()
            action.action()
        })
    }, actionLayout: actionLayout), allowInputInset: allowInputInset)
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    return controller
}

private let controlStartCharactersSet = CharacterSet(charactersIn: "[*")
private let controlCharactersSet = CharacterSet(charactersIn: "[]()*_-\\")

private final class MarkdownAttributeSet {
    public let font: UIFont
    public let textColor: UIColor
    public let additionalAttributes: [String: Any]
    
    public init(font: UIFont, textColor: UIColor, additionalAttributes: [String: Any] = [:]) {
        self.font = font
        self.textColor = textColor
        self.additionalAttributes = additionalAttributes
    }
}

private final class MarkdownAttributes {
    public let body: MarkdownAttributeSet
    public let bold: MarkdownAttributeSet
    public let link: MarkdownAttributeSet
    public let linkAttribute: (String) -> (String, Any)?
    
    public init(body: MarkdownAttributeSet, bold: MarkdownAttributeSet, link: MarkdownAttributeSet, linkAttribute: @escaping (String) -> (String, Any)?) {
        self.body = body
        self.link = link
        self.bold = bold
        self.linkAttribute = linkAttribute
    }
}

private func escapedPlaintextForMarkdown(_ string: String) -> String {
    let nsString = string as NSString
    var remainingRange = NSMakeRange(0, nsString.length)
    let result = NSMutableString()
    while true {
        let range = nsString.rangeOfCharacter(from: controlCharactersSet, options: [], range: remainingRange)
        if range.location != NSNotFound {
            if range.location - remainingRange.location > 0 {
                result.append(nsString.substring(with: NSMakeRange(remainingRange.location, range.location - remainingRange.location)))
            }
            result.append("\\")
            result.append(nsString.substring(with: NSMakeRange(range.location, range.length)))
            remainingRange = NSMakeRange(range.location + range.length, remainingRange.location + remainingRange.length - (range.location + range.length))
        } else {
            result.append(nsString.substring(with: NSMakeRange(remainingRange.location, remainingRange.length)))
            break
        }
    }
    return result as String
}

private func paragraphStyleWithAlignment(_ alignment: NSTextAlignment) -> NSParagraphStyle {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = alignment
    return paragraphStyle
}

private func parseMarkdownIntoAttributedString(_ string: String, attributes: MarkdownAttributes, textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    let nsString = string as NSString
    let result = NSMutableAttributedString()
    var remainingRange = NSMakeRange(0, nsString.length)
    
    var bodyAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: attributes.body.font, NSAttributedString.Key.foregroundColor: attributes.body.textColor, NSAttributedString.Key.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
    if !attributes.body.additionalAttributes.isEmpty {
        for (key, value) in attributes.body.additionalAttributes {
            bodyAttributes[NSAttributedString.Key(rawValue: key)] = value
        }
    }
    
    while true {
        let range = nsString.rangeOfCharacter(from: controlStartCharactersSet, options: [], range: remainingRange)
        if range.location != NSNotFound {
            if range.location != remainingRange.location {
                result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, range.location - remainingRange.location)), attributes: bodyAttributes))
                remainingRange = NSMakeRange(range.location, remainingRange.location + remainingRange.length - range.location)
            }
            
            let character = nsString.character(at: range.location)
            if character == UInt16(("[" as UnicodeScalar).value) {
                remainingRange = NSMakeRange(range.location + range.length, remainingRange.location + remainingRange.length - (range.location + range.length))
                if let (parsedLinkText, parsedLinkContents) = parseLink(string: nsString, remainingRange: &remainingRange) {
                    var linkAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: attributes.link.font, NSAttributedString.Key.foregroundColor: attributes.link.textColor, NSAttributedString.Key.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
                    if !attributes.link.additionalAttributes.isEmpty {
                        for (key, value) in attributes.link.additionalAttributes {
                            linkAttributes[NSAttributedString.Key(rawValue: key)] = value
                        }
                    }
                    if let (attributeName, attributeValue) = attributes.linkAttribute(parsedLinkContents) {
                        linkAttributes[NSAttributedString.Key(rawValue: attributeName)] = attributeValue
                    }
                    result.append(NSAttributedString(string: parsedLinkText, attributes: linkAttributes))
                }
            } else if character == UInt16(("*" as UnicodeScalar).value) {
                if range.location + 1 != remainingRange.length {
                    let nextCharacter = nsString.character(at: range.location + 1)
                    if nextCharacter == character {
                        remainingRange = NSMakeRange(range.location + range.length + 1, remainingRange.location + remainingRange.length - (range.location + range.length + 1))
                        
                        if let bold = parseBold(string: nsString, remainingRange: &remainingRange) {
                            var boldAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: attributes.bold.font, NSAttributedString.Key.foregroundColor: attributes.bold.textColor, NSAttributedString.Key.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
                            if !attributes.body.additionalAttributes.isEmpty {
                                for (key, value) in attributes.bold.additionalAttributes {
                                    boldAttributes[NSAttributedString.Key(rawValue: key)] = value
                                }
                            }
                            result.append(NSAttributedString(string: bold, attributes: boldAttributes))
                        } else {
                            result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, 1)), attributes: bodyAttributes))
                            remainingRange = NSMakeRange(range.location + 1, remainingRange.length - 1)
                        }
                    } else {
                        if result.string.hasSuffix("\\") {
                            result.deleteCharacters(in: NSMakeRange(result.string.count - 1, 1))
                        }
                        result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, 1)), attributes: bodyAttributes))
                        remainingRange = NSMakeRange(range.location + 1, remainingRange.length - 1)
                    }
                } else {
                    result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, 1)), attributes: bodyAttributes))
                    remainingRange = NSMakeRange(range.location + 1, remainingRange.length - 1)
                }
            }
        } else {
            if remainingRange.length != 0 {
                result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, remainingRange.length)), attributes: bodyAttributes))
            }
            break
        }
    }
    return result
}

private func parseLink(string: NSString, remainingRange: inout NSRange) -> (text: String, contents: String)? {
    var localRemainingRange = remainingRange
    let closingSquareBraceRange = string.range(of: "]", options: [], range: localRemainingRange)
    if closingSquareBraceRange.location != NSNotFound {
        localRemainingRange = NSMakeRange(closingSquareBraceRange.location + closingSquareBraceRange.length, remainingRange.location + remainingRange.length - (closingSquareBraceRange.location + closingSquareBraceRange.length))
        let openingRoundBraceRange = string.range(of: "(", options: [], range: localRemainingRange)
        let closingRoundBraceRange = string.range(of: ")", options: [], range: localRemainingRange)
        if openingRoundBraceRange.location == closingSquareBraceRange.location + closingSquareBraceRange.length && closingRoundBraceRange.location != NSNotFound && openingRoundBraceRange.location < closingRoundBraceRange.location {
            let linkText = string.substring(with: NSMakeRange(remainingRange.location, closingSquareBraceRange.location - remainingRange.location))
            let linkContents = string.substring(with: NSMakeRange(openingRoundBraceRange.location + openingRoundBraceRange.length, closingRoundBraceRange.location - (openingRoundBraceRange.location + openingRoundBraceRange.length)))
            remainingRange = NSMakeRange(closingRoundBraceRange.location + closingRoundBraceRange.length, remainingRange.location + remainingRange.length - (closingRoundBraceRange.location + closingRoundBraceRange.length))
            return (linkText, linkContents)
        }
    }
    return nil
}

private func parseBold(string: NSString, remainingRange: inout NSRange) -> String? {
    var localRemainingRange = remainingRange
    let closingRange = string.range(of: "**", options: [], range: localRemainingRange)
    if closingRange.location != NSNotFound {
        localRemainingRange = NSMakeRange(closingRange.location + closingRange.length, remainingRange.location + remainingRange.length - (closingRange.location + closingRange.length))
        
        let result = string.substring(with: NSRange(location: remainingRange.location, length: closingRange.location - remainingRange.location))
        remainingRange = localRemainingRange
        return result
    }
    return nil
}

private func foldMultipleLineBreaks(_ string: String) -> String {
    return string.replacingOccurrences(of: "(([\n\r]\\s*){2,})+", with: "\n\n", options: .regularExpression, range: nil)
}
