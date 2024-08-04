import Foundation

// The Termux packages to download and unpack
var termuxPackages = ["libicu", "libicu-static", "libandroid-spawn", "libcurl", "libxml2"]
let termuxURL = "https://packages.termux.dev/apt/termux-main"

let swiftRepos = ["llvm-project", "swift", "swift-experimental-string-processing", "swift-corelibs-libdispatch",
                  "swift-corelibs-foundation", "swift-corelibs-xctest", "swift-syntax"]

let extraSwiftRepos = ["swift-llbuild", "swift-package-manager", "swift-driver",
                       "swift-tools-support-core", "swift-argument-parser", "swift-crypto",
                       "Yams", "indexstore-db", "sourcekit-lsp", "swift-system",
                       "swift-collections", "swift-certificates", "swift-asn1"]
let renameRepos = ["swift-llbuild" : "llbuild", "swift-package-manager" : "swiftpm", "Yams" : "yams"]
var repoTags = ["swift-system" : "1.3.0", "swift-collections" : "1.1.2", "swift-asn1" : "1.0.0",
                "swift-certificates" : "1.0.1", "Yams" : "5.0.6", "swift-argument-parser" : "1.2.3",
                "swift-crypto" : "3.0.0"]
if ProcessInfo.processInfo.environment["BUILD_SWIFT_PM"] != nil {
  termuxPackages += ["ncurses", "libsqlite"]
}

guard let SWIFT_TAG = ProcessInfo.processInfo.environment["SWIFT_TAG"] else {
  fatalError("You must specify a SWIFT_TAG environment variable.")
}

guard let ANDROID_ARCH = ProcessInfo.processInfo.environment["ANDROID_ARCH"] else {
  fatalError("You must specify an ANDROID_ARCH environment variable.")
}

var sdkDir = "", icuVersion = "", icuMajorVersion = "", swiftVersion = "",
    swiftBranch = "", swiftSnapshotDate = ""

let tagRange = NSRange(SWIFT_TAG.startIndex..., in: SWIFT_TAG)
let tagExtract = try NSRegularExpression(pattern: "swift-([5-9]\\.[0-9]+)?\\.?[1-9]*-?([A-Z-]+)([0-9-]+[0-9])?")

if tagExtract.numberOfMatches(in: SWIFT_TAG, range: tagRange) == 1 {
  let match = tagExtract.firstMatch(in: SWIFT_TAG, range: tagRange)
  if match!.range(at: 1).location != NSNotFound {
    swiftVersion = (SWIFT_TAG as NSString).substring(with: match!.range(at: 1))
  }

  swiftBranch = (SWIFT_TAG as NSString).substring(with: match!.range(at: 2))

  if match!.range(at: 3).location != NSNotFound {
    swiftSnapshotDate = (SWIFT_TAG as NSString).substring(with: match!.range(at: 3))
  }
} else {
  fatalError("Something went wrong with extracting data from the SWIFT_TAG environment variable: \(SWIFT_TAG)")
}

if swiftBranch == "RELEASE" {
  repoTags["swift-collections"] = "1.0.5"
  repoTags["swift-system"] = "1.1.1"
  repoTags["Yams"] = "5.0.1"
  sdkDir = "swift-release-android-\(ANDROID_ARCH)-24-sdk"
} else {
  if swiftVersion == "" {
    repoTags["swift-argument-parser"] = "1.4.0"
  }
  sdkDir = "swift-\(swiftVersion == "" ? "trunk" : "devel")-android-\(ANDROID_ARCH)-\(swiftSnapshotDate)-24-sdk"
}

// takes the name of a command-line executable and the arguments to pass to it
func runCommand(_ name: String, with args: [String]) -> String {

  let command = Process()
 #if os(Android)
  command.executableURL = URL(fileURLWithPath: "/system/bin/which")
 #else
  command.executableURL = URL(fileURLWithPath: "/usr/bin/which")
 #endif

  command.arguments = [name]
  let output = Pipe()
  let error = Pipe()
  command.standardOutput = output
  command.standardError = error
  do {
    try command.run()
  } catch {
    fatalError("couldn't find \(name) with error: \(error)")
  }

  guard let result = String(data: output.fileHandleForReading.availableData, encoding: .utf8) else {
    fatalError("couldn't read `which` output")
  }
  guard let errorResult = String(data: error.fileHandleForReading.availableData, encoding: .ascii) else {
    fatalError("couldn't read `which` stderr")
  }

  if result != "" {
    let chompResult = result.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
    let command = Process()
    command.executableURL = URL(fileURLWithPath: chompResult)
    command.arguments = args
    let output = Pipe()
    let error = Pipe()
    command.standardOutput = output
    command.standardError = error
    do {
      print("running command: \(([command.executableURL!.path] + args).joined(separator: " "))")
      fflush(stdout)
      try command.run()
    } catch {
      fatalError("couldn't run \(name) \(args) with error: \(error)")
    }

    command.waitUntilExit()
    guard let commandResult = String(data: output.fileHandleForReading.availableData, encoding: .utf8) else {
      fatalError("couldn't read `\(name)` output")
    }
    guard let errorResult = String(data: error.fileHandleForReading.availableData, encoding: .ascii) else {
      fatalError("couldn't read `\(name)` stderr")
    }

    if command.terminationStatus == 0 {
      return commandResult.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
    } else {
      fatalError("couldn't run \(name) \(args) because of \(errorResult)")
    }
  } else {
    if errorResult != "" {
      fatalError("couldn't find \(name) because of \(errorResult)")
    } else {
      fatalError("couldn't find \(name), maybe a problem with `\(command.executableURL!.path)`?")
    }
  }
}

print("Checking if needed system utilities are installed...")
print(runCommand("cmake", with: ["--version"]))
print("ninja \(runCommand("ninja", with: ["--version"]))")

#if os(macOS)
print(runCommand("python3", with: ["--version"]))
#else
print(runCommand("python", with: ["--version"]))
#endif
print(runCommand("patchelf", with: ["--version"]))
#if !os(macOS)
// ar does not take a "--version" arg on macOS
print(runCommand("ar", with: ["--version"]))
#endif
print(runCommand("tar", with: ["--version"]))
print(runCommand("xz", with: ["--version"]))
print(runCommand("curl", with: ["--version"]))
print(runCommand("gzip", with: ["--version"]))

#if os(macOS)
extension String {
    func appendingPathComponent(_ path: String) -> String {
        (self as NSString).appendingPathComponent(path)
    }
} 
#endif

let fmd = FileManager.default
let cwd = fmd.currentDirectoryPath
let termuxArchive = cwd.appendingPathComponent("termux")
if !fmd.fileExists(atPath: termuxArchive) {
  try fmd.createDirectory(atPath: termuxArchive, withIntermediateDirectories: false)
}

if !fmd.fileExists(atPath: termuxArchive.appendingPathComponent("Packages-\(ANDROID_ARCH)")) {
  _ = runCommand("curl", with: ["-o", "termux/Packages-\(ANDROID_ARCH)",
      "\(termuxURL)/dists/stable/main/binary-\(ANDROID_ARCH == "armv7" ? "arm" : ANDROID_ARCH)/Packages"])
}

let packages = try String(contentsOfFile: termuxArchive.appendingPathComponent("Packages-\(ANDROID_ARCH)"), encoding: .utf8)

for termuxPackage in termuxPackages {
  guard let packagePathRange = packages.range(of: "\\S+\(termuxPackage)_\\S+", options: .regularExpression) else {
    fatalError("couldn't find \(termuxPackage) in Packages list")
  }
  let packagePath = packages[packagePathRange]

  guard let packageNameRange = packagePath.range(of: "\(termuxPackage)_\\S+", options: .regularExpression) else {
    fatalError("couldn't extract \(termuxPackage) .deb package from package path")
  }
  let packageName = packagePath[packageNameRange]

  print("Checking for \(packageName)")
  if !fmd.fileExists(atPath: termuxArchive.appendingPathComponent(String(packageName))) {
    print("Downloading \(packageName)")
    _ = runCommand("curl", with: ["-f", "-o", "termux/\(packageName)",
        "\(termuxURL)/\(packagePath)"])
  }

  if termuxPackage == "libicu" {
    guard let icuVersionRange = packageName.range(of: "([0-9]+)\\.[0-9]", options: .regularExpression) else {
      fatalError("couldn't extract ICU version from \(packageName)")
    }
    icuVersion = String(packageName[icuVersionRange])
    guard let icuMajorVersionRange = icuVersion.range(of: "^[0-9]+", options: .regularExpression) else {
      fatalError("couldn't extract ICU major version from \(icuVersion)")
    }
    icuMajorVersion = String(icuVersion[icuMajorVersionRange])
  }

  if !fmd.fileExists(atPath: cwd.appendingPathComponent(sdkDir)) {
    print("Unpacking \(packageName)")
#if os(macOS)
    _ = runCommand("tar", with: ["xf", "\(termuxArchive.appendingPathComponent(String(packageName)))"])
#else
    _ = runCommand("ar", with: ["x", "\(termuxArchive.appendingPathComponent(String(packageName)))"])
#endif
    _ = runCommand("tar", with: ["xf", "data.tar.xz"])
  }
}

let sdkPath = cwd.appendingPathComponent(sdkDir)
if !fmd.fileExists(atPath: sdkPath) {
  try fmd.removeItem(atPath: cwd.appendingPathComponent("data.tar.xz"))
  try fmd.removeItem(atPath: cwd.appendingPathComponent("control.tar.xz"))
  try fmd.removeItem(atPath: cwd.appendingPathComponent("debian-binary"))

  try fmd.createDirectory(atPath: sdkPath, withIntermediateDirectories: false)
  try fmd.moveItem(atPath: cwd.appendingPathComponent("data/data/com.termux/files/usr"),
                   toPath: sdkPath.appendingPathComponent("usr"))

  try fmd.removeItem(atPath: cwd.appendingPathComponent("data"))
  try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/bin/curl-config"))
  try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/bin/xml2-config"))
  try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/share/man"))
}

for iculib in ["data", "i18n", "io", "test", "tu", "uc"] {
  if fmd.fileExists(atPath: sdkPath.appendingPathComponent("usr/lib/libicu\(iculib).so.\(icuMajorVersion)")) {
    try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/lib/libicu\(iculib).so"))
    try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/lib/libicu\(iculib).so.\(icuMajorVersion)"))

    if ["io", "test", "tu"].contains(iculib) {
      try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/lib/libicu\(iculib).a"))
      try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/lib/libicu\(iculib).so.\(icuVersion)"))
    } else {
      try fmd.moveItem(atPath: sdkPath.appendingPathComponent("usr/lib/libicu\(iculib).so.\(icuVersion)"),
                       toPath: sdkPath.appendingPathComponent("usr/lib/libicu\(iculib).so"))
      _ = runCommand("patchelf", with: ["--set-rpath", "$ORIGIN",
                "\(sdkPath.appendingPathComponent("usr/lib/libicu\(iculib).so"))"])
      _ = runCommand("patchelf", with: ["--set-soname", "libicu\(iculib).so",
                "\(sdkPath.appendingPathComponent("usr/lib/libicu\(iculib).so"))"])

      if iculib == "i18n" {
        _ = runCommand("patchelf", with: ["--replace-needed", "libicuuc.so.\(icuMajorVersion)",
                  "libicuuc.so", "\(sdkPath.appendingPathComponent("usr/lib/libicui18n.so"))"])
      }

      if iculib == "uc" {
        _ = runCommand("patchelf", with: ["--replace-needed", "libicudata.so.\(icuMajorVersion)",
                  "libicudata.so", "\(sdkPath.appendingPathComponent("usr/lib/libicuuc.so"))"])
      }
    }
  }
}

_ = runCommand("patchelf", with: ["--set-rpath", "$ORIGIN",
          "\(sdkPath.appendingPathComponent("usr/lib/libandroid-spawn.so"))",
          "\(sdkPath.appendingPathComponent("usr/lib/libcurl.so"))",
          "\(sdkPath.appendingPathComponent("usr/lib/libxml2.so"))"])

for repo in swiftRepos {
  print("Checking for \(repo) source")
  if !fmd.fileExists(atPath: cwd.appendingPathComponent(repo)) {
    print("Downloading and extracting \(repo) source")
    _ = runCommand("curl", with: ["-f", "-L", "-O",
              "https://github.com/apple/\(repo)/archive/refs/tags/\(SWIFT_TAG).tar.gz"])
    _ = runCommand("tar", with: ["xf", "\(SWIFT_TAG).tar.gz"])
    try fmd.moveItem(atPath: cwd.appendingPathComponent("\(repo)-\(SWIFT_TAG)"),
                     toPath: cwd.appendingPathComponent(repo))
    try fmd.removeItem(atPath: cwd.appendingPathComponent("\(SWIFT_TAG).tar.gz"))
  }
}

if ProcessInfo.processInfo.environment["BUILD_SWIFT_PM"] != nil {
  for repo in extraSwiftRepos {
    let tag = repoTags[repo] ?? SWIFT_TAG
    _ = runCommand("curl", with: ["-f", "-L", "-O",
              "https://github.com/\(repo == "Yams" ? "jpsim" : "apple")/\(repo)/archive/refs/tags/\(tag).tar.gz"])
    _ = runCommand("tar", with: ["xf", "\(tag).tar.gz"])
    try fmd.moveItem(atPath: cwd.appendingPathComponent("\(repo)-\(tag)"),
                     toPath: cwd.appendingPathComponent(renameRepos[repo] ?? repo))
    try fmd.removeItem(atPath: cwd.appendingPathComponent("\(tag).tar.gz"))
  }
}
