//
//  Plane.swift
//  Euclid
//
//  Created by Nick Lockwood on 03/07/2018.
//  Copyright © 2018 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/Euclid
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

/// Represents a 2D plane in 3D space.
public struct Plane: Hashable {
    public let normal: Vector
    public let w: Double

    /// Creates a plane from a surface normal and a distance from the world origin
    init?(normal: Vector, w: Double) {
        let length = normal.length
        guard length.isFinite, length > epsilon else {
            return nil
        }
        self.init(unchecked: normal / length, w: w)
    }
}

public extension Plane {
    static let yz = Plane(unchecked: Vector(1, 0, 0), w: 0)
    static let xz = Plane(unchecked: Vector(0, 1, 0), w: 0)
    static let xy = Plane(unchecked: Vector(0, 0, 1), w: 0)

    /// Creates a plane from a point and surface normal
    init?(normal: Vector, pointOnPlane: Vector) {
        let length = normal.length
        guard length.isFinite, length > epsilon else {
            return nil
        }
        self.init(unchecked: normal / length, pointOnPlane: pointOnPlane)
    }

    /// Generate a plane from a set of coplanar points describing a polygon
    /// The polygon can be convex or concave. The direction of the plane normal is
    /// based on the assumption that the points are wound in an anticlockwise direction
    // TODO: make an optimized version for points that are known to form a convex polygon
    init?(points: [Vector]) {
        guard let first = points.first else {
            return nil
        }
        var normal = faceNormalForConvexPoints(points)
        if points.count > 3 {
            let flatteningPlane = FlatteningPlane(points: points)
            let flattenedPoints = points.map { flatteningPlane.flattenPoint($0) }
            let flattenedNormal = faceNormalForConvexPoints(flattenedPoints)
            let isClockwise = flattenedPointsAreClockwise(flattenedPoints)
            if (flattenedNormal.z > 0) == isClockwise {
                normal = -normal
            }
            self.init(normal: normal, pointOnPlane: first)
            // Check all points lie on this plane
            if points.contains(where: { !containsPoint($0) }) {
                return nil
            }
        } else {
            self.init(normal: normal, pointOnPlane: first)
        }
    }

    /// Returns the flipside of the plane
    func inverted() -> Plane {
        return Plane(unchecked: -normal, w: -w)
    }

    /// Checks if point is on plane
    func containsPoint(_ p: Vector) -> Bool {
        return abs(normal.dot(p) - w) < epsilon
    }
}

internal extension Plane {
    init(unchecked normal: Vector, w: Double) {
        assert(normal.isNormalized)
        self.normal = normal
        self.w = w
    }

    init(unchecked normal: Vector, pointOnPlane: Vector) {
        self.init(unchecked: normal, w: normal.dot(pointOnPlane))
    }
}

// An enum of planes along the X, Y and Z axes
// Used internally for flattening 3D paths and polygons
enum FlatteningPlane: RawRepresentable {
    case xy, xz, yz

    var rawValue: Plane {
        switch self {
        case .xy: return .xy
        case .xz: return .xz
        case .yz: return .yz
        }
    }

    init(bounds: Bounds) {
        let size = bounds.size
        if size.x > size.y {
            self = size.z > size.y ? .xz : .xy
        } else {
            self = size.z > size.x ? .yz : .xy
        }
    }

    init(normal: Vector) {
        switch (abs(normal.x), abs(normal.y), abs(normal.z)) {
        case let (x, y, z) where x > y && x > z:
            self = .yz
        case let (x, y, z) where y > x && y > z:
            self = .xz
        default:
            self = .xy
        }
    }

    init(points: [Vector]) {
        self.init(bounds: Bounds(points: points))
    }

    init?(rawValue: Plane) {
        switch rawValue {
        case .xy: self = .xy
        case .xz: self = .xz
        case .yz: self = .yz
        default: return nil
        }
    }

    func flattenPoint(_ point: Vector) -> Vector {
        switch self {
        case .yz: return Vector(point.y, point.z)
        case .xz: return Vector(point.x, point.z)
        case .xy: return Vector(point.x, point.y)
        }
    }
}