//
//  SVGPath+SwiftUI.swift
//  SVGPath
//
//  Created by Nick Lockwood on 08/01/2025.
//  Copyright © 2025 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/SVGPath
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#if canImport(SwiftUI)

import CoreGraphics
import SwiftUI

// MARK: SVGPath to SwiftUI Path

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension Path {
    init(_ svgPath: SVGPath, in rect: CGRect? = nil) {
        var cgPath = CGPath.from(svgPath)
        if let rect {
            let bounds = cgPath.boundingBoxOfPath
            let target = bounds.scaledToFit(in: rect)
            var transform = CGAffineTransform.identity
                .translatedBy(x: target.minX - bounds.minX, y: target.minY - bounds.minY)
                .scaledBy(x: target.width / bounds.width, y: target.height / bounds.height)
            cgPath = cgPath.copy(using: &transform) ?? cgPath
        }
        self.init(cgPath)
    }

    init(svgPath: String, in rect: CGRect? = nil) throws {
        try self.init(SVGPath(string: svgPath, with: .init(invertYAxis: false)), in: rect)
    }
}

private extension CGRect {
    func scaledToFit(in rect: CGRect) -> CGRect {
        var scale = rect.width / width
        if height * scale > rect.height {
            scale = rect.height / height
        }
        let width = width * scale
        let height = height * scale
        return .init(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }
}

// MARK: SwiftUI Path to SVGPath

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension SVGPath {
    init(_ path: Path) {
        self.init(path.cgPath)
    }
}

#endif
