import Foundation

let fm = FileManager.default
let path = NSTemporaryDirectory() + "testdir\(NSUUID().uuidString)"
print("creating temporary directory \(path)")
try fm.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
try? fm.removeItem(atPath: path)
print("removed temporary directory \(path)")
