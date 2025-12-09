import Foundation

// The Termux packages to download and unpack
// libxml2 needs liblzma and libiconv
// libcurl needs zlib, libnghttp3, libnghttp2, libssh2, and openssl
// Testing needs backtrace() from libandroid-execinfo
var termuxPackages = ["libandroid-execinfo", "libandroid-spawn", "libandroid-spawn-static", "libcurl", "zlib", "libxml2", "libnghttp3", "libnghttp2", "libssh2", "openssl", "liblzma", "libiconv"]
let termuxURL = "https://packages.termux.dev/apt/termux-main"

var swiftRepos = ["llvm-project", "swift", "swift-experimental-string-processing", "swift-corelibs-libdispatch",
                  "swift-corelibs-foundation", "swift-corelibs-xctest", "swift-syntax", "swift-collections",
                  "swift-foundation", "swift-foundation-icu", "swift-testing"]

let extraSwiftRepos = ["swift-llbuild", "swift-package-manager", "swift-driver",
                       "swift-tools-support-core", "swift-argument-parser", "swift-crypto",
                       "indexstore-db", "sourcekit-lsp", "swift-system", "swift-lmdb",
                       "swift-certificates", "swift-asn1", "swift-toolchain-sqlite",
                       "swift-build", "swift-tools-protocols"]
let appleRepos = ["swift-argument-parser", "swift-crypto", "swift-system", "swift-collections", "swift-certificates", "swift-asn1"]
let renameRepos = ["swift-llbuild" : "llbuild", "swift-package-manager" : "swiftpm"]
var repoTags = ["swift-system" : "1.5.0", "swift-collections" : "1.1.6", "swift-asn1" : "1.3.2",
                "swift-certificates" : "1.10.1", "swift-argument-parser" : "1.5.1",
                "swift-crypto" : "3.12.5", "swift-toolchain-sqlite" : "1.0.1", "swift-tools-protocols" : "0.0.9"]
if ProcessInfo.processInfo.environment["BUILD_SWIFT_PM"] != nil {
  swiftRepos += extraSwiftRepos
  termuxPackages += ["ncurses", "libsqlite"]
}

guard let SWIFT_TAG = ProcessInfo.processInfo.environment["SWIFT_TAG"] else {
  fatalError("You must specify a SWIFT_TAG environment variable.")
}

guard let ANDROID_ARCH = ProcessInfo.processInfo.environment["ANDROID_ARCH"] else {
  fatalError("You must specify an ANDROID_ARCH environment variable.")
}

var sdkDir = "", swiftVersion = "", swiftBranch = "", swiftSnapshotDate = ""

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
  sdkDir = "swift-release-android-\(ANDROID_ARCH)-24-sdk"
  repoTags["swift-collections"] = "1.1.3"
  repoTags["swift-argument-parser"] = "1.4.0"
  repoTags["swift-crypto"] = "3.0.0"
  repoTags["swift-certificates"] = "1.0.1"
  repoTags["swift-asn1"] = "1.0.0"
} else {
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
  guard let packagePathRange = packages.range(of: "Filename: \\S+/\(termuxPackage)_\\S+", options: .regularExpression) else {
    fatalError("couldn't find \(termuxPackage) in Packages list")
  }
  let packagePath = packages[packagePathRange].dropFirst("Filename: ".count).description

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
  try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/lib/ossl-modules"))
  try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/lib/engines-3"))
  try fmd.removeItem(atPath: sdkPath.appendingPathComponent("usr/etc"))
}

let libPath = sdkPath.appendingPathComponent("usr/lib")

// flatten each of the shared object file links, since Android APKs do not support version-suffixed .so.x.y.z paths
var renamedSharedObjects: [String: String] = [:]
for soFile in try fmd.contentsOfDirectory(atPath: libPath) {
  let parts = soFile.split(separator: ".")
  guard let soIndex = parts.firstIndex(of: "so") else { continue }

  // e.g., for "libtinfo.so.6.5": soBase="libtinfo.so" soVersion="6.5"
  let soBase = parts[0...soIndex].joined(separator: ".")
  let soVersion = parts.dropFirst(soIndex + 1).joined(separator: ".")

  if !soVersion.isEmpty {
    renamedSharedObjects[soFile] = soBase // libtinfo.so.6.5->libtinfo.so
  }

  let soPath = libPath.appendingPathComponent(soFile)
  let soBasePath = libPath.appendingPathComponent(soBase)
  if (try? fmd.destinationOfSymbolicLink(atPath: soPath)) != nil {
    try fmd.removeItem(atPath: soPath) // clear links
  } else if !soVersion.isEmpty {
    // otherwise move the version-suffixed path to the un-versioned destination
    if (try? fmd.destinationOfSymbolicLink(atPath: soBasePath)) != nil {
      // need to remove the destination before we can move
      try fmd.removeItem(atPath: soBasePath)
    }
    try fmd.moveItem(atPath: soPath, toPath: soBasePath)
  }
}

if ProcessInfo.processInfo.environment["BUILD_SWIFT_PM"] != nil {
  // Rename ncurses for llbuild and add a symlink for SwiftPM
  try fmd.moveItem(atPath: libPath.appendingPathComponent("libncursesw.so"), toPath: libPath.appendingPathComponent("libcurses.so"))
  try fmd.createSymbolicLink(atPath: libPath.appendingPathComponent("libncurses.so"), withDestinationPath: "libcurses.so")
}

// update the rpath to be $ORIGIN, set the soname, and update all the "needed" sections for each of the peer libraries
for soFile in try fmd.contentsOfDirectory(atPath: libPath).filter({ $0.hasSuffix(".so")} ) {
  let soPath = libPath.appendingPathComponent(soFile)
  // fix the soname (e.g., libtinfo.so.6.5->libtinfo.so)
  _ = runCommand("patchelf", with: ["--set-soname", soFile, soPath])
  _ = runCommand("patchelf", with: ["--set-rpath", "$ORIGIN", soPath])

  let needed = Set(runCommand("patchelf", with: ["--print-needed", soPath]).split(separator: "\n").map(\.description))
  for needs in needed {
    if let unversioned = renamedSharedObjects[needs] {
      _ = runCommand("patchelf", with: ["--replace-needed", needs, unversioned, soPath])
    }
  }
}

for repo in swiftRepos {
  print("Checking for \(repo) source")
  if !fmd.fileExists(atPath: cwd.appendingPathComponent(renameRepos[repo] ?? repo)) {
    print("Downloading and extracting \(repo) source")
    let tag = repoTags[repo] ?? SWIFT_TAG
    var repoOrg = "swiftlang"
    if appleRepos.contains(repo) {
      repoOrg = "apple"
    }
    _ = runCommand("curl", with: ["-f", "-L", "-O",
              "https://github.com/\(repoOrg)/\(repo)/archive/refs/tags/\(tag).tar.gz"])
    _ = runCommand("tar", with: ["xf", "\(tag).tar.gz"])
    try fmd.moveItem(atPath: cwd.appendingPathComponent("\(repo)-\(tag)"),
                     toPath: cwd.appendingPathComponent(renameRepos[repo] ?? repo))
    try fmd.removeItem(atPath: cwd.appendingPathComponent("\(tag).tar.gz"))
  }
}
