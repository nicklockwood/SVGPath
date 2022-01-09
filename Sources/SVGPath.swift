//
//  SVGPath.swift
//  SVGPath
//
//  Created by Nick Lockwood on 27/09/2021.
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

import Foundation

public struct SVGPath: Hashable {
    public var commands: [SVGCommand]

    public init(commands: [SVGCommand]) {
        self.commands = commands
    }

    public init(string: String) throws {
        var token: UnicodeScalar?
        var commands = [SVGCommand]()
        var numbers = ArraySlice<Double>()
        var number = ""
        var isRelative = false

        func assertArgs(_ count: Int) throws -> [Double] {
            if numbers.count < count {
                throw SVGError
                    .missingArgument(for: String(token!), expected: count)
            } else if !numbers.count.isMultiple(of: count) {
                throw SVGError
                    .unexpectedArgument(for: String(token!), expected: count)
            }
            defer { numbers.removeFirst(count) }
            return Array(numbers.prefix(count))
        }

        func moveTo() throws -> SVGCommand {
            let numbers = try assertArgs(2)
            return .moveTo(SVGPoint(x: numbers[0], y: -numbers[1]))
        }

        func lineTo() throws -> SVGCommand {
            let numbers = try assertArgs(2)
            return .lineTo(SVGPoint(x: numbers[0], y: -numbers[1]))
        }

        func lineToVertical() throws -> SVGCommand {
            let numbers = try assertArgs(1)
            return .lineTo(SVGPoint(
                x: isRelative ? 0 : (commands.last?.point.x ?? 0),
                y: -numbers[0]
            ))
        }

        func lineToHorizontal() throws -> SVGCommand {
            let numbers = try assertArgs(1)
            return .lineTo(SVGPoint(
                x: numbers[0],
                y: isRelative ? 0 : (commands.last?.point.y ?? 0)
            ))
        }

        func quadCurve() throws -> SVGCommand {
            let numbers = try assertArgs(4)
            return .quadratic(
                SVGPoint(x: numbers[0], y: -numbers[1]),
                SVGPoint(x: numbers[2], y: -numbers[3])
            )
        }

        func quadTo() throws -> SVGCommand {
            let numbers = try assertArgs(2)
            var lastControl = commands.last?.control1 ?? .zero
            let lastPoint = commands.last?.point ?? .zero
            if case .quadratic? = commands.last {} else {
                lastControl = lastPoint
            }
            var control = lastPoint - lastControl
            if !isRelative {
                control = control + lastPoint
            }
            return .quadratic(control, SVGPoint(x: numbers[0], y: -numbers[1]))
        }

        func cubicCurve() throws -> SVGCommand {
            let numbers = try assertArgs(6)
            return .cubic(
                SVGPoint(x: numbers[0], y: -numbers[1]),
                SVGPoint(x: numbers[2], y: -numbers[3]),
                SVGPoint(x: numbers[4], y: -numbers[5])
            )
        }

        func cubicTo() throws -> SVGCommand {
            let numbers = try assertArgs(4)
            var lastControl = commands.last?.control2 ?? .zero
            let lastPoint = commands.last?.point ?? .zero
            if case .cubic? = commands.last {} else {
                lastControl = lastPoint
            }
            var control = lastPoint - lastControl
            if !isRelative {
                control = control + lastPoint
            }
            return .cubic(
                control,
                SVGPoint(x: numbers[0], y: -numbers[1]),
                SVGPoint(x: numbers[2], y: -numbers[3])
            )
        }

        func arc() throws -> SVGCommand {
            let numbers = try assertArgs(7)
            return .arc(SVGArc(
                radius: SVGPoint(x: numbers[0], y: numbers[1]),
                rotation: numbers[2] * .pi / 180,
                largeArc: numbers[3] != 0,
                sweep: numbers[4] != 0,
                end: SVGPoint(x: numbers[5], y: -numbers[6])
            ))
        }

        func end() throws -> SVGCommand {
            _ = try assertArgs(0)
            return .end
        }

        func processNumber() throws {
            if number.isEmpty {
                return
            }
            if let double = Double(number) {
                numbers.append(double)
                number = ""
                return
            }
            throw SVGError.unexpectedToken(number)
        }

        func processCommand() throws {
            guard let token = token else {
                return
            }
            let command: SVGCommand
            switch token {
            case "m", "M": command = try moveTo()
            case "l", "L": command = try lineTo()
            case "v", "V": command = try lineToVertical()
            case "h", "H": command = try lineToHorizontal()
            case "q", "Q": command = try quadCurve()
            case "t", "T": command = try quadTo()
            case "c", "C": command = try cubicCurve()
            case "s", "S": command = try cubicTo()
            case "a", "A": command = try arc()
            case "z", "Z": command = try end()
            default: throw SVGError.unexpectedToken(String(token))
            }
            let last = isRelative ? commands.last : nil
            commands.append(command.relative(to: last))
            if !numbers.isEmpty {
                try processCommand()
            }
        }

        for char in string.unicodeScalars {
            switch char {
            case "0" ... "9", "E", "e", "+":
                number.append(Character(char))
            case ".":
                if number.contains(".") {
                    try processNumber()
                }
                number.append(".")
            case "-":
                try processNumber()
                number = "-"
            case "a" ... "z", "A" ... "Z":
                try processNumber()
                try processCommand()
                token = char
                isRelative = char > "Z"
            case " ", "\r", "\n", "\t", ",":
                try processNumber()
            default:
                throw SVGError.unexpectedToken(String(char))
            }
        }
        try processNumber()
        try processCommand()
        self.commands = commands
    }
}

public enum SVGError: Error, Hashable {
    case unexpectedToken(String)
    case unexpectedArgument(for: String, expected: Int)
    case missingArgument(for: String, expected: Int)

    public var message: String {
        switch self {
        case let .unexpectedToken(string):
            return "Unexpected token '\(string)'"
        case let .unexpectedArgument(command, _):
            return "Too many arguments for '\(command)'"
        case let .missingArgument(command, _):
            return "Missing argument for '\(command)'"
        }
    }
}

public struct SVGArc: Hashable {
    public var radius: SVGPoint
    public var rotation: Double
    public var largeArc: Bool
    public var sweep: Bool
    public var end: SVGPoint

    fileprivate func relative(to last: SVGPoint) -> SVGArc {
        var arc = self
        arc.end = arc.end + last
        return arc
    }
}

public enum SVGCommand: Hashable {
    case moveTo(SVGPoint)
    case lineTo(SVGPoint)
    case cubic(SVGPoint, SVGPoint, SVGPoint)
    case quadratic(SVGPoint, SVGPoint)
    case arc(SVGArc)
    case end
}

public extension SVGCommand {
    var point: SVGPoint {
        switch self {
        case let .moveTo(point),
             let .lineTo(point),
             let .cubic(_, _, point),
             let .quadratic(_, point):
            return point
        case let .arc(arc):
            return arc.end
        case .end:
            return .zero
        }
    }

    var control1: SVGPoint? {
        switch self {
        case let .cubic(control1, _, _), let .quadratic(control1, _):
            return control1
        case .moveTo, .lineTo, .arc, .end:
            return nil
        }
    }

    var control2: SVGPoint? {
        switch self {
        case let .cubic(_, control2, _):
            return control2
        case .moveTo, .lineTo, .quadratic, .arc, .end:
            return nil
        }
    }

    fileprivate func relative(to last: SVGCommand?) -> SVGCommand {
        guard let last = last?.point else {
            return self
        }
        switch self {
        case let .moveTo(point):
            return .moveTo(point + last)
        case let .lineTo(point):
            return .lineTo(point + last)
        case let .cubic(control1, control2, point):
            return .cubic(control1 + last, control2 + last, point + last)
        case let .quadratic(control, point):
            return .quadratic(control + last, point + last)
        case let .arc(arc):
            return .arc(arc.relative(to: last))
        case .end:
            return .end
        }
    }
}

public struct SVGPoint: Hashable {
    public var x, y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public extension SVGPoint {
    static let zero = SVGPoint(x: 0, y: 0)

    static func + (lhs: SVGPoint, rhs: SVGPoint) -> SVGPoint {
        SVGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: SVGPoint, rhs: SVGPoint) -> SVGPoint {
        SVGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}
