//
//  FlxAnimation.swift
//  Flexatar
//
//  Created by Matey Vislouh on 05.05.2024.
//

import Foundation

class BlinkGenerator{
    var pattern:[Float] = MetalResProviderFlx.getBlinkPattern()
    var segment:[Float] = []
    var isBlink:Bool = true
    var segmentPosition:Int = 0
    
    
    
    func makeSegment(){
        
        if isBlink {
            
            segment = pattern.map{$0}
        }else{
            let randomInt = Int.random(in: 60..<180)
            segment = [Float](repeating: 0, count: randomInt)
        }
    }
    
    func next() -> Float{
        segmentPosition+=1
        if segmentPosition >= segment.count {
            isBlink = !isBlink
            makeSegment()
            segmentPosition = 0
        }
//        print(segment[segmentPosition])
        return segment[segmentPosition]
    }
    
}

public class AnimatorFlx{
    private var animationPattern:[[Float]]
    private var blinkGenerator = BlinkGenerator()
    
    public static var sharedInstance = AnimatorFlx()
    
    private var counter = 0
    
    public init(){
        self.animationPattern = MetalResProviderFlx.getAnimation()
    }
    
    public func getAnim(idx:Int)->(tx:Float,ty:Float,sc:Float,rx:Float,ry:Float,rz:Float,eb:Float,bl:Float){
        let scaleFactor:Float = 0.5
        let yShift:Float = 0.5
        let scaleCorrection:Float = -0.04
        let blink = blinkGenerator.next()
        let patternVec = animationPattern[idx]
        
        return (
            tx:patternVec[0],
            ty:patternVec[1] - yShift,
            sc:patternVec[2] * scaleFactor + scaleCorrection,
            rx:patternVec[3],
            ry:patternVec[4],
            rz:-patternVec[5],
            eb:patternVec[6],
            bl:blink
        )
    }
    public func getNext()->(tx:Float,ty:Float,sc:Float,rx:Float,ry:Float,rz:Float,eb:Float,bl:Float){
        let anim = self.getAnim(idx: self.counter)
        self.counter+=1
        if self.counter == self.animationPattern.count {self.counter = 0}
        return anim
        
    }
}


class MandalaOperations{
    
    static func findIntersection(line1: (start1: CGPoint, end1: CGPoint), line2: (start2: CGPoint, end2: CGPoint)) -> CGPoint? {
        let slope1 = (line1.end1.y - line1.start1.y) / (line1.end1.x - line1.start1.x)
        let yIntercept1 = line1.start1.y - slope1 * line1.start1.x

        let slope2 = (line2.end2.y - line2.start2.y) / (line2.end2.x - line2.start2.x)
        let yIntercept2 = line2.start2.y - slope2 * line2.start2.x

        if slope1 == slope2 {
            // The two line segments are parallel, so they never intersect.
            return nil
        }

        let x = (yIntercept2 - yIntercept1) / (slope1 - slope2)
        let y = slope1 * x + yIntercept1

        let xRange1 = min(line1.start1.x, line1.end1.x)...max(line1.start1.x, line1.end1.x)
        let yRange1 = min(line1.start1.y, line1.end1.y)...max(line1.start1.y, line1.end1.y)

        let xRange2 = min(line2.start2.x, line2.end2.x)...max(line2.start2.x, line2.end2.x)
        let yRange2 = min(line2.start2.y, line2.end2.y)...max(line2.start2.y, line2.end2.y)

        if xRange1.contains(x) && yRange1.contains(y) &&
           xRange2.contains(x) && yRange2.contains(y) {
            // The intersection point is within both line segments.
            return CGPoint(x: x, y: y)
        }
        else {
            // The intersection point is outside of at least one of the line segments.
            return nil
        }
    }
    
}

class FlxAnimation{
    static let cases = [[0,1,2],[1,0,2],[2,0,1]]
    static let cases4 = [[0,1,3],[1,0,2],[2,3,1],[3,0,2]]
    static let casesDict = [3:cases,4:cases4]
    

    
    static func checkTriangle(point: CGPoint, triangle: [CGPoint]) -> Bool
    {
        let d1 = FlxAnimation.triSign(triangle: [point,triangle[0],triangle[1]])
        let d2 = FlxAnimation.triSign(triangle: [point,triangle[1],triangle[2]])
        let d3 = FlxAnimation.triSign(triangle: [point,triangle[2],triangle[0]])
        let has_neg = (d1<0) || (d2<0) || (d3<0)
        let has_pos = (d1>0) || (d2>0) || (d3>0)
        return !(has_neg && has_pos)
    }
    static func triSign(triangle:[CGPoint]) -> CGFloat {
        let p1 = triangle[0]
        let p2 = triangle[1]
        let p3 = triangle[2]
        return (p1.x-p3.x)*(p2.y-p3.y) - (p2.x - p3.x)*(p1.y-p3.y)
    }
    
    static func findTriangleContainingPoint(triangles: [[CGPoint]], point: CGPoint) -> Int? {
        for (index, triangle) in triangles.enumerated() {
            if triangle.count == 3{
                if FlxAnimation.checkTriangle(point: point,triangle: triangle) {
                    return index
                }
            }else{
                let t1 = [triangle[0],triangle[1],triangle[2]]
                if FlxAnimation.checkTriangle(point: point,triangle: t1) {
                    return index
                }
                let t2 = [triangle[0],triangle[2],triangle[3]]
                if FlxAnimation.checkTriangle(point: point,triangle: t2) {
                    return index
                }
            }
        }
        return nil
    }
    
    static func createTriangles(from points: [CGPoint?], with indices: [[Int]]) -> [[CGPoint]] {
        var triangles: [[CGPoint]] = []
//        print("triangle")
        for indexArray in indices {
//            guard indexArray.count == 3 || indexArray.count == 4 else {
//                continue // Skip index arrays that are not length 3
//            }
            let triangle = indexArray.map{points[$0]!}
//            let triangle = [points[indexArray[0]]!,points[indexArray[1]]!,points[indexArray[2]]!]
//            print(triangle)
            triangles.append(triangle)
        }
        return triangles
    }
    

    static func inverse2x2Matrix(_ column1: CGPoint, _ column2: CGPoint) -> [CGPoint] {
        let a = column1.x
        let b = column1.y
        let c = column2.x
        let d = column2.y

        let det = a * d - b * c
        if det == 0 {
            // Matrix is not invertible, return nil or throw an error.
            return [CGPoint.zero, CGPoint.zero]
        }

        let invDet = 1.0 / det
        let invColumn1 = CGPoint(x: d * invDet, y: -b * invDet)
        let invColumn2 = CGPoint(x: -c * invDet, y: a * invDet)

        return [invColumn1, invColumn2]
    }
    
    static func pointOnLineBetweenPoints(point1: CGPoint, point2: CGPoint,_ percentCloserToFirstPoint: CGFloat) -> CGPoint {
        let x = point1.x + (point2.x - point1.x) * percentCloserToFirstPoint
        let y = point1.y + (point2.y - point1.y) * percentCloserToFirstPoint
        return CGPoint(x: x, y: y)
    }
    static func findTriangleFor(point:CGPoint,tiangles:[[CGPoint]],border:[(CGPoint,CGPoint)]) -> Int?{
        var triangleIndex = FlxAnimation.findTriangleContainingPoint(triangles:tiangles,point:point)
        
        var calculatedPoint = point
        if triangleIndex == nil {
            
            var borderPoint:CGPoint?
            for b in border{
                borderPoint = MandalaOperations.findIntersection(line1: b, line2: (point,CGPoint(x:0.5,y:0.5)))
//                print(borderPoint)
                if borderPoint != nil{break}
                
            }
            if borderPoint == nil {return nil}
            calculatedPoint = FlxAnimation.pointOnLineBetweenPoints(point1:CGPoint(x:0.5,y:0.45),point2:borderPoint!,0.98)
            triangleIndex = FlxAnimation.findTriangleContainingPoint(triangles:tiangles,point:calculatedPoint)
//            return FlxAnimation.findTriangleContainingPoint(triangles:tiangles,point:calculatedPoint)
        }
        
        
        return triangleIndex
    }
    static func findNewMandalaPosition(newPoint:CGPoint, point:CGPoint, tiangles:[[CGPoint]], border:[(CGPoint,CGPoint)]) -> CGPoint{
        
        func compareFloatArray(a1:[Float],a2:[Float])->Float{
            var sum:Float = 0
            for (e1,e2) in zip(a1, a2){
                sum+=pow(e1-e2,2)
            }
            return sum
        }
        
        let triangleIndex = findTriangleFor(point: point, tiangles: tiangles, border: border)
        
        var triangle = tiangles[triangleIndex!]
        let weightsBase:[Float] = findWeightsForPoly(triangle, point).map{Float($0)}
        var weightsNew:[Float] = findWeightsForPoly(triangle, newPoint).map{Float($0)}
        let indexOfKeyPoint = newPoint.indexOfClosestPoint(in: triangle)
        
        print(triangle[indexOfKeyPoint])
        print(weightsBase)
        let change = point - newPoint
       
        var findPoint = newPoint - change
        for _ in 0..<50{
            let d1 = CGPoint(x: 0.01, y: 0)
            let d2 = CGPoint(x: 0, y: 0.01)
            var grads:[Float] = []
           
            for d in [d1,d2]{
                var tmpPoint:CGPoint
                tmpPoint = findPoint + d
                triangle[indexOfKeyPoint] = tmpPoint
                weightsNew = findWeightsForPoly(triangle, newPoint).map{Float($0)}
                let compareResult1 = compareFloatArray(a1: weightsBase, a2: weightsNew)
                tmpPoint = findPoint - d
                triangle[indexOfKeyPoint] = tmpPoint
                weightsNew = findWeightsForPoly(triangle, newPoint).map{Float($0)}
                let compareResult2 = compareFloatArray(a1: weightsBase, a2: weightsNew)
                let grad = compareResult2-compareResult1
                grads.append(grad)
            }
            findPoint = findPoint + CGPoint(x: CGFloat(grads[0]), y: CGFloat(grads[1]))*1
            triangle[indexOfKeyPoint] = findPoint
            weightsNew = findWeightsForPoly(triangle, newPoint).map{Float($0)}
            let compare = compareFloatArray(a1: weightsBase, a2: weightsNew)
            print(compare)
            print(weightsNew)
//            print(findPoint)
        }
//        print(weightsBase)
//        print(weightsNew)
        return findPoint
    }
    
    static func makeInterUint(point:CGPoint,tiangles:[[CGPoint]],indices:[[Int]],border:[(CGPoint,CGPoint)]) -> ([Int32],[Float],CGPoint)?{
        var triangleIndex = FlxAnimation.findTriangleContainingPoint(triangles:tiangles,point:point)
        
        var calculatedPoint = point
        if triangleIndex == nil {
            
            var borderPoint:CGPoint?
            for b in border{
                borderPoint = MandalaOperations.findIntersection(line1: b, line2: (point,CGPoint(x:0.5,y:0.45)))
//                print(borderPoint)
                if borderPoint != nil{break}
                
            }
            if borderPoint == nil {return nil}
            calculatedPoint = FlxAnimation.pointOnLineBetweenPoints(point1:CGPoint(x:0.5,y:0.5),point2:borderPoint!,0.98)
            triangleIndex = FlxAnimation.findTriangleContainingPoint(triangles:tiangles,point:calculatedPoint)
//            return FlxAnimation.findTriangleContainingPoint(triangles:tiangles,point:calculatedPoint)
        }
        
        let rotation = CGPoint(x:point.x-calculatedPoint.x,y:point.y-calculatedPoint.y)
//        print("FLX_INJECT triangleIDx \(String(describing: triangleIndex))")
        
            
        if triangleIndex == nil {return nil}
        
        let triangle = tiangles[triangleIndex!]
        var idxs:[Int] = indices[triangleIndex!]
//        var idxs:[Int] = []
//        var weights:[Float] = []
        var weights:[Float] = findWeightsForPoly(triangle, calculatedPoint).map{Float($0)}
//        print(weights)
        if idxs.count == 3{
            idxs.append(0)
            weights.append(0)
        }
//        let weightsPowered = weights

        return (idxs.map{Int32($0)},weights,rotation)
    }
    
    static func findWeightsForPoly(_ poly:[CGPoint],_ point:CGPoint) -> [CGFloat]{
        
        var dists:[CGFloat] = []
        var weights:[CGFloat] = []
        for i in 0..<poly.count-1{
            let v1 = poly[i+1] - poly[i]
            let v0 = point - poly[i]
            let (dist,weight) = distAndWeight(v0: v0, v1: v1)
            dists.append(dist)
            weights.append(weight)
        }
        let v1 = poly[0] - poly[poly.count-1]
        let v0 = point - poly[poly.count-1]
        let (dist,weight) = distAndWeight(v0: v0, v1: v1)
        dists.append(dist)
        weights.append(weight)
        dists = dists.map{CGFloat(1)/($0+CGFloat(0.001))}
        dists = norm(dists)
//        dists = dists.map{pow($0,8)}
//        dists = norm(dists)
//        dists = dists.map{CGFloat(1)-$0}
//        dists = norm(dists)
        
        var pointWeights = [CGFloat](repeating: CGFloat(0), count: poly.count)
        for i in 0..<poly.count-1{
            let cWeight = weights[i]
            pointWeights[i]+=(CGFloat(1)-cWeight)*dists[i]
            pointWeights[i+1]+=cWeight*dists[i]
        }
        let cWeight = weights[poly.count-1]
        pointWeights[poly.count-1]+=(CGFloat(1)-cWeight)*dists[poly.count-1]
        pointWeights[0]+=cWeight*dists[poly.count-1]
//        pointWeights = pointWeights.map{pow($0,4)}
        pointWeights = norm(pointWeights)
        return pointWeights
    }
    static func distAndWeight(v0:CGPoint,v1:CGPoint)->(CGFloat,CGFloat){
        let v1len = v1.length() + CGFloat(0.0001)
        var proj = v0.dot(v1)/v1len
        let dist = sqrt(v0.length2() - pow(proj,2))
        let weight = proj/v1len
        if proj<0{
            proj=0
        }
        if proj>1{
            proj=1
        }
        return (dist,weight)
    }
    static func norm(_ x:[CGFloat]) -> [CGFloat]{
        let sum = x.reduce(0, +)
        
        return x.map{$0/sum}
        
    }
    
    static func norm(_ x:[Float]) -> [Float]{
        let sum = x.reduce(0, +)
        
        return x.map{$0/sum}
        
    }
}

extension CGPoint{
    
    
    func indexOfClosestPoint(in points: [CGPoint]) -> Int {
        var closestDistance: CGFloat = .greatestFiniteMagnitude
        var closestIndex: Int = 0

        for (index, point) in points.enumerated() {
            let distance = hypot(point.x - self.x, point.y - self.y)
            if distance < closestDistance {
                closestDistance = distance
                closestIndex = index
            }
        }

        return closestIndex
    }
   
    static func += (lhs: inout CGPoint, rhs: CGPoint) {
            lhs.x += rhs.x
            lhs.y += rhs.y
    }
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x:lhs.x+rhs.x,y:lhs.y+rhs.y)
    }
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x:lhs.x-rhs.x,y:lhs.y-rhs.y)
    }
    static func *(lhs: CGPoint, rhs: Float) -> CGPoint {
        return CGPoint(x:lhs.x*CGFloat(rhs),y:lhs.y*CGFloat(rhs))
    }
    static func *(lhs: Float, rhs: CGPoint) -> CGPoint {
        return CGPoint(x:rhs.x*CGFloat(lhs),y:rhs.y*CGFloat(lhs))
    }
    
    static func *(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x:rhs.x*lhs.x,y:rhs.y*lhs.y)
    }
    static func /(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x:lhs.x/rhs.x,y:lhs.y/rhs.y)
    }
    func dot(_ p:CGPoint)->CGFloat{
        let mul = self * p
        return mul.x+mul.y
    }
    func length()->CGFloat{
        return sqrt(pow(self.x,2)+pow(self.y,2))
    }
    func length2()->CGFloat{
        return pow(self.x,2)+pow(self.y,2)
    }
}
