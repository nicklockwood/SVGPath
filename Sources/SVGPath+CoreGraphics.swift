//
//  SVGPath+CoreGraphics.swift
//  SVGPath
//
//  Created by Nick Lockwood on 08/01/2022.
//  Copyright © 2021 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/SVGPath
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

#if canImport(CoreGraphics)

import CoreGraphics
import Foundation

public extension CGPath {
    static func from(svgPath: String) throws -> CGPath {
        from(svgPath: try SVGPath(string: svgPath))
    }

    static func from(svgPath: SVGPath) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        for command in svgPath.commands {
            switch command {
            case let .moveTo(point):
                path.move(to: CGPoint(point))
            case let .lineTo(point):
                path.addLine(to: CGPoint(point))
            case let .quadratic(control, point):
                path.addQuadCurve(
                    to: CGPoint(point),
                    control: CGPoint(control)
                )
            case let .cubic(control1, control2, point):
                path.addCurve(
                    to: CGPoint(point),
                    control1: CGPoint(control1),
                    control2: CGPoint(control2)
                )
            case let .arc(arc):
                path.addArc(arc)
            case .end:
                path.closeSubpath()
            }
        }
        return path
    }
}

public extension CGPoint {
    init(_ svgPoint: SVGPoint) {
        self.init(x: svgPoint.x, y: svgPoint.y)
    }
}

private extension CGMutablePath {
    func addArc(_ arc: SVGArc) {
        let px = Double(currentPoint.x), py = Double(currentPoint.y)
        var rx = abs(arc.radius.x), ry = abs(arc.radius.y)
        let xr = arc.rotation
        let largeArcFlag = arc.largeArc
        let sweepFlag = arc.sweep
        let cx = arc.end.x, cy = arc.end.y
        let sinphi = sin(xr), cosphi = cos(xr)

        func vectorAngle(
            _ ux: Double, _ uy: Double,
            _ vx: Double, _ vy: Double
        ) -> Double {
            let sign = (ux * vy - uy * vx < 0) ? -1.0 : 1.0
            let umag = sqrt(ux * ux + uy * uy), vmag = sqrt(vx * vx + vy * vy)
            let dot = ux * vx + uy * vy
            return sign * acos(max(-1, min(1, dot / (umag * vmag))))
        }

        func toEllipse(_ x: Double, _ y: Double) -> CGPoint {
            let x = x * rx, y = y * ry
            let xp = cosphi * x - sinphi * y, yp = sinphi * x + cosphi * y
            return CGPoint(x: xp + centerx, y: yp + centery)
        }

        let dx = (px - cx) / 2, dy = (py - cy) / 2
        let pxp = cosphi * dx + sinphi * dy, pyp = -sinphi * dx + cosphi * dy
        if pxp == 0, pyp == 0 {
            return
        }

        let lambda = pow(pxp, 2) / pow(rx, 2) + pow(pyp, 2) / pow(ry, 2)
        if lambda > 1 {
            rx *= sqrt(lambda)
            ry *= sqrt(lambda)
        }

        let rxsq = pow(rx, 2), rysq = pow(ry, 2)
        let pxpsq = pow(pxp, 2), pypsq = pow(pyp, 2)

        var radicant = max(0, rxsq * rysq - rxsq * pypsq - rysq * pxpsq)
        radicant /= (rxsq * pypsq) + (rysq * pxpsq)
        radicant = sqrt(radicant) * (largeArcFlag != sweepFlag ? -1 : 1)

        let centerxp = radicant * rx / ry * pyp
        let centeryp = radicant * -ry / rx * pxp

        let centerx = cosphi * centerxp - sinphi * centeryp + (px + cx) / 2
        let centery = sinphi * centerxp + cosphi * centeryp + (py + cy) / 2

        let vx1 = (pxp - centerxp) / rx, vy1 = (pyp - centeryp) / ry
        let vx2 = (-pxp - centerxp) / rx, vy2 = (-pyp - centeryp) / ry

        var a1 = vectorAngle(1, 0, vx1, vy1)
        var a2 = vectorAngle(vx1, vy1, vx2, vy2)
        if sweepFlag, a2 > 0 {
            a2 -= .pi * 2
        } else if !sweepFlag, a2 < 0 {
            a2 += .pi * 2
        }

        let segments = max(ceil(abs(a2) / (.pi / 2)), 1)
        a2 /= segments
        let a = 4 / 3 * tan(a2 / 4)
        for _ in 0 ..< Int(segments) {
            let x1 = cos(a1), y1 = sin(a1)
            let x2 = cos(a1 + a2), y2 = sin(a1 + a2)

            let p1 = toEllipse(x1 - y1 * a, y1 + x1 * a)
            let p2 = toEllipse(x2 + y2 * a, y2 - x2 * a)
            let p = toEllipse(x2, y2)

            addCurve(to: p, control1: p1, control2: p2)
            a1 += a2
        }
    }
}

#endif
