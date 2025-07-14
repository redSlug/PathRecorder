extension Double {
    func isEqual(to other: Double, accuracy: Double) -> Bool {
        return abs(self - other) < accuracy
    }
} 