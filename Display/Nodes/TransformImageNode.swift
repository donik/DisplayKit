//
//  TransformImageNode.swift
//  Display
//
//  Created by Данияр Габбасов on 17.04.2020.
//

import Foundation
import UIKit
import AsyncDisplayKit
import SSignalKit

public enum TransformImageResizeMode {
    case fill(UIColor)
    case aspectFill
    case blurBackground
}

public protocol TransformImageCustomArguments {
    func serialized() -> NSArray
}

public struct TransformImageArguments: Equatable {
    public let corners: ImageCorners
    
    public let imageSize: CGSize
    public let boundingSize: CGSize
    public let intrinsicInsets: UIEdgeInsets
    public let resizeMode: TransformImageResizeMode
    public let emptyColor: UIColor?
    public let custom: TransformImageCustomArguments?
    public let scale: CGFloat?
    
    public init(corners: ImageCorners, imageSize: CGSize, boundingSize: CGSize, intrinsicInsets: UIEdgeInsets, resizeMode: TransformImageResizeMode = .fill(.black), emptyColor: UIColor? = nil, custom: TransformImageCustomArguments? = nil, scale: CGFloat? = nil) {
        self.corners = corners
        self.imageSize = imageSize
        self.boundingSize = boundingSize
        self.intrinsicInsets = intrinsicInsets
        self.resizeMode = resizeMode
        self.emptyColor = emptyColor
        self.custom = custom
        self.scale = scale
    }
    
    public var drawingSize: CGSize {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGSize(width: self.boundingSize.width + cornersExtendedEdges.left + cornersExtendedEdges.right + self.intrinsicInsets.left + self.intrinsicInsets.right, height: self.boundingSize.height + cornersExtendedEdges.top + cornersExtendedEdges.bottom + self.intrinsicInsets.top + self.intrinsicInsets.bottom)
    }
    
    public var drawingRect: CGRect {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGRect(x: cornersExtendedEdges.left + self.intrinsicInsets.left, y: cornersExtendedEdges.top + self.intrinsicInsets.top, width: self.boundingSize.width, height: self.boundingSize.height)
    }
    
    public var imageRect: CGRect {
        let drawingRect = self.drawingRect
        return CGRect(x: drawingRect.minX + floor((drawingRect.width - self.imageSize.width) / 2.0), y: drawingRect.minX + floor((drawingRect.height - self.imageSize.height) / 2.0), width: self.imageSize.width, height: self.imageSize.height)
    }
    
    public var insets: UIEdgeInsets {
        let cornersExtendedEdges = self.corners.extendedEdges
        return UIEdgeInsets(top: cornersExtendedEdges.top + self.intrinsicInsets.top, left: cornersExtendedEdges.left + self.intrinsicInsets.left, bottom: cornersExtendedEdges.bottom + self.intrinsicInsets.bottom, right: cornersExtendedEdges.right + self.intrinsicInsets.right)
    }
    
    public static func ==(lhs: TransformImageArguments, rhs: TransformImageArguments) -> Bool {
        var result = lhs.imageSize == rhs.imageSize && lhs.boundingSize == rhs.boundingSize && lhs.corners == rhs.corners && lhs.emptyColor == rhs.emptyColor
        if result {
            if let lhsCustom = lhs.custom, let rhsCustom = rhs.custom {
                return lhsCustom.serialized().isEqual(rhsCustom.serialized())
            } else {
                return (lhs.custom != nil) == (rhs.custom != nil)
            }
        }
        return result
    }
}

public struct TransformImageNodeContentAnimations: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let firstUpdate = TransformImageNodeContentAnimations(rawValue: 1 << 0)
    public static let subsequentUpdates = TransformImageNodeContentAnimations(rawValue: 1 << 1)
}

open class TransformImageNode: ASDisplayNode {
    public var imageUpdated: ((UIImage?) -> Void)?
    public var contentAnimations: TransformImageNodeContentAnimations = []
    private var disposable = MetaDisposable()
    
    private var currentTransform: ((TransformImageArguments) -> DrawingContext?)?
    private var currentArguments: TransformImageArguments?
    private var argumentsPromise = ValuePromise<TransformImageArguments>(ignoreRepeated: true)
    
    private var overlayColor: UIColor?
    private var overlayNode: ASDisplayNode?
    
    deinit {
        self.disposable.dispose()
    }
    
    override open func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *), !self.isLayerBacked {
            self.view.accessibilityIgnoresInvertColors = true
        }
    }
    
    override open var frame: CGRect {
        didSet {
            if let overlayNode = self.overlayNode {
                overlayNode.frame = self.bounds
            }
        }
    }
    
    public func reset() {
        self.disposable.set(nil)
        self.currentArguments = nil
        self.currentTransform = nil
        self.contents = nil
    }
    
    public func setSignal(_ signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>, attemptSynchronously: Bool = false, dispatchOnDisplayLink: Bool = true) {
        let argumentsPromise = self.argumentsPromise
        
        let data = combineLatest(signal, argumentsPromise.get())
        
        let resultData: Signal<((TransformImageArguments) -> DrawingContext?, TransformImageArguments), NoError>
        if attemptSynchronously {
            resultData = data
        } else {
            resultData = data
            |> deliverOn(Queue.concurrentDefaultQueue())
        }
        
        let result = resultData
        |> mapToThrottled { transform, arguments -> Signal<((TransformImageArguments) -> DrawingContext?, TransformImageArguments, UIImage?)?, NoError> in
            return deferred {
                if let context = transform(arguments) {
                    return .single((transform, arguments, context.generateImage()))
                } else {
                    return .single(nil)
                }
            }
        }
        
        self.disposable.set((result |> deliverOnMainQueue).start(next: { [weak self] next in
            let apply: () -> Void = {
                if let strongSelf = self {
                    if strongSelf.contents == nil {
                        if strongSelf.contentAnimations.contains(.firstUpdate) && !attemptSynchronously {
                            strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        }
                    } else if strongSelf.contentAnimations.contains(.subsequentUpdates) {
                        let tempLayer = CALayer()
                        tempLayer.frame = strongSelf.bounds
                        tempLayer.contentsGravity = strongSelf.layer.contentsGravity
                        tempLayer.contents = strongSelf.contents
                        strongSelf.layer.addSublayer(tempLayer)
                        tempLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak tempLayer] _ in
                            tempLayer?.removeFromSuperlayer()
                        })
                    }
                    
                    var imageUpdate: UIImage?
                    if let (transform, arguments, image) = next {
                        strongSelf.currentTransform = transform
                        strongSelf.currentArguments = arguments
                        strongSelf.contents = image?.cgImage
                        imageUpdate = image
                    }
                    if let _ = strongSelf.overlayColor {
                        strongSelf.applyOverlayColor(animated: false)
                    }
                    if let imageUpdated = strongSelf.imageUpdated {
                        imageUpdated(imageUpdate)
                    }
                }
            }
            if dispatchOnDisplayLink && !attemptSynchronously {
                displayLinkDispatcher.dispatch {
                    apply()
                }
            } else {
                apply()
            }
        }))
    }
    
    public func asyncLayout() -> (TransformImageArguments) -> (() -> Void) {
        let currentTransform = self.currentTransform
        let currentArguments = self.currentArguments
        return { [weak self] arguments in
            let updatedImage: UIImage?
            if currentArguments != arguments {
                updatedImage = currentTransform?(arguments)?.generateImage()
            } else {
                updatedImage = nil
            }
            return {
                guard let strongSelf = self else {
                    return
                }
                if let image = updatedImage {
                    strongSelf.contents = image.cgImage
                    strongSelf.currentArguments = arguments
                    if let _ = strongSelf.overlayColor {
                        strongSelf.applyOverlayColor(animated: false)
                    }
                }
                strongSelf.argumentsPromise.set(arguments)
            }
        }
    }
    
    public class func asyncLayout(_ maybeNode: TransformImageNode?) -> (TransformImageArguments) -> (() -> TransformImageNode) {
        return { arguments in
            let node: TransformImageNode
            if let maybeNode = maybeNode {
                node = maybeNode
            } else {
                node = TransformImageNode()
            }
            return {
                node.argumentsPromise.set(arguments)
                return node
            }
        }
    }
    
    public func setOverlayColor(_ color: UIColor?, animated: Bool) {
        var updated = false
        if let overlayColor = self.overlayColor, let color = color {
            updated = !overlayColor.isEqual(color)
        } else if (self.overlayColor != nil) != (color != nil) {
            updated = true
        }
        if updated {
            self.overlayColor = color
            if let _ = self.overlayColor {
                self.applyOverlayColor(animated: animated)
            } else if let overlayNode = self.overlayNode {
                self.overlayNode = nil
                if animated {
                    overlayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak overlayNode] _ in
                        overlayNode?.removeFromSupernode()
                    })
                } else {
                    overlayNode.removeFromSupernode()
                }
            }
        }
    }
    
    private func applyOverlayColor(animated: Bool) {
        if let overlayColor = self.overlayColor {
            if let contents = self.contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID {
                if let overlayNode = self.overlayNode {
                    (overlayNode.view as! UIImageView).image = UIImage(cgImage: contents as! CGImage).withRenderingMode(.alwaysTemplate)
                    overlayNode.tintColor = overlayColor
                } else {
                    let overlayNode = ASDisplayNode(viewBlock: {
                        return UIImageView()
                    }, didLoad: nil)
                    overlayNode.displaysAsynchronously = false
                    (overlayNode.view as! UIImageView).image = UIImage(cgImage: contents as! CGImage).withRenderingMode(.alwaysTemplate)
                    overlayNode.tintColor = overlayColor
                    overlayNode.frame = self.bounds
                    self.addSubnode(overlayNode)
                    self.overlayNode = overlayNode
                }
            }
        }
    }
}
