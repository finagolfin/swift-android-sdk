# Swift cross-compilation SDK bundle for Android

The patches used to build this SDK bundle are open source and listed below. I
maintain [a daily CI on github Actions](https://github.com/finagolfin/swift-android-sdk/actions?query=event%3Aschedule)
that [cross-compiles the SDK bundle from the release and development source branches of
the Swift toolchain for AArch64, armv7, and x86_64, builds several Swift
packages against those SDKs, and then runs their tests in the Android x86_64
emulator](https://github.com/finagolfin/swift-android-sdk/blob/main/.github/workflows/sdks.yml).

## Cross-compiling and testing Swift packages with the Android SDK bundle

To build with the Swift 6.1.2 SDK bundle, first download [the official open-source
Swift 6.1.2 toolchain for linux or macOS](https://swift.org/install)
(make sure to install the Swift dependencies linked there). Install the OSS
toolchain on macOS as detailed in [the instructions for using the static linux
Musl SDK bundle at swift.org](https://www.swift.org/documentation/articles/static-linux-getting-started.html).
On linux, simply download the toolchain, unpack it, and add it to your `PATH`.

Next, install the Android SDK bundle by having the Swift toolchain directly
download it:
```
swift sdk install https://github.com/finagolfin/swift-android-sdk/releases/download/6.1.2/swift-6.1.2-RELEASE-android-24-0.1.artifactbundle.tar.gz --checksum 6d817c947870e8c85e6cab9a6ab6d7313b50fa5a20b890c396723c0b16ab32d9
```
or alternately, download the SDK bundle with your favorite downloader and install
it separately:
```
> wget https://github.com/finagolfin/swift-android-sdk/releases/download/6.1.2/swift-6.1.2-RELEASE-android-24-0.1.artifactbundle.tar.gz
> sha256sum swift-6.1.2-RELEASE-android-24-0.1.artifactbundle.tar.gz
6d817c947870e8c85e6cab9a6ab6d7313b50fa5a20b890c396723c0b16ab32d9 swift-6.1.2-RELEASE-android-24-0.1.artifactbundle.tar.gz
> swift sdk install swift-6.1.2-RELEASE-android-24-0.1.artifactbundle.tar.gz
```
You can check if it was properly installed by running `swift sdk list`.

Now you're ready to cross-compile a Swift package and run its tests on Android.
I'll demonstrate with the swift-argument-parser package:
```
git clone --depth 1 https://github.com/apple/swift-argument-parser.git

cd swift-argument-parser/

swift build --build-tests --swift-sdk aarch64-unknown-linux-android24
```

Note: On macOS, building for Android requires specifying an OSS toolchain like so:
```
swift build --build-tests --swift-sdk aarch64-unknown-linux-android24 --toolchain <PATH_TO_OSS_TOOLCHAIN>
```

This will cross-compile the package for Android aarch64 at API 24 and produce a
test runner executable with the `.xctest` extension, in this case at
`.build/aarch64-unknown-linux-android24/debug/swift-argument-parserPackageTests.xctest`.

Sometimes the test runner will depend on additional files or executables: this
one depends on the example executables `color`, `generate-manual`, `math`,
`repeat`, and `roll` in the same build directory. Other packages use `#file` to
point at test data in the repo: I've had success moving this data with the test
runner, after modifying the test source so it has the path to this test data in
the Android test environment. See the example of [swift-crypto on the
CI](https://github.com/finagolfin/swift-android-sdk/blob/6.1.2/.github/workflows/sdks.yml#L521).

You can copy these executables and the Swift runtime libraries to [an emulator
or a USB debugging-enabled device with adb](https://github.com/swiftlang/swift/blob/release/6.1/docs/Android.md#3-deploying-the-build-products-to-the-device),
or put them on an Android device with [a terminal emulator app like Termux](https://termux.dev/en/).
I test aarch64 with Termux so I'll show how to run the test runner there, but
the process is similar with adb, [as can be seen on the CI](https://github.com/finagolfin/swift-android-sdk/blob/6.1.2/.github/workflows/sdks.yml#L469).

Copy the test executables to the same directory as the Swift 6.1.2 runtime libraries:
```
cp .build/aarch64-unknown-linux-android24/debug/{swift-argument-parserPackageTests.xctest,color,generate-manual,math,repeat,roll} ..
cp ~/.swiftpm/swift-sdks/swift-6.1.2-RELEASE-android-24-0.1.artifactbundle/swift-6.1.2-release-android-24-sdk/android-27c-sysroot/usr/lib/aarch64-linux-android/lib*.so ..
```
You can copy the test executables and Swift 6.1.2 runtime libraries to Termux using
scp from OpenSSH, run these commands in Termux on the Android device:
```
uname -m # check if you're running on the right architecture, should say `aarch64`
cd       # move to the Termux app's home directory
pkg install openssh

scp yourname@192.168.1.1:"lib*.so" .
scp yourname@192.168.1.1:{swift-argument-parserPackageTests.xctest,color,generate-manual,math,repeat,roll} .

./swift-argument-parserPackageTests.xctest
```
I've tried several Swift packages, including some mostly written in C or C++,
and all the cross-compiled tests passed. Note that while this SDK bundle is
compiled against Android API 24, you can also specify an arbitrary later API to
compile against, eg `--swift-sdk aarch64-unknown-linux-android29`.

You can even run armv7 tests on an aarch64 device, though Termux may require
running `unset LD_PRELOAD` before invoking an armv7 test runner on aarch64.
Revert that with `export LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec.so`
when you're done running armv7 tests and want to go back to the normal aarch64
mode.

Two issues were recently introduced into the Swift toolchain that you may need
to work around:

1. If you have the `ANDROID_NDK_ROOT` environment variable set, as it is on
github Actions runners, this SDK bundle won't work, so unset it.

2. There is a bug when trying to [cross-compile `Testing` tests with the open-source
macOS toolchain alone](https://github.com/swiftlang/swift-package-manager/issues/8362)-
it works fine with the linux toolchain- use the `-plugin-path` workaround listed
there until it is fixed on macOS.

## Porting Swift packages to Android

The most commonly needed change is to import the new Android overlay, so add
these two lines for Android when calling Android's C APIs:
```
#if canImport(Android)
import Android
```
You may also need to add some Android-specific support using `#if canImport(Android)`,
for example, since FILE is an opaque struct since Android 7, you will [have to
refer to any FILE pointers like this](https://github.com/swiftlang/swift-tools-support-core/pull/243/files):
```
#if canImport(Android)
typealias FILEPointer = OpaquePointer
```
Those changes are all I had to make [to port swift-argument-parser to
Android](https://github.com/apple/swift-argument-parser/pull/651/files).

## Building an Android app with Swift

Some people have reported an issue with using previous libraries from this SDK in
their Android app, that the Android toolchain strips `libdispatch.so` and
complains that it has an `empty/missing DT_HASH/DT_GNU_HASH`. You can [work
around this issue by adding the following to your `build.gradle`](https://github.com/finagolfin/swift-android-sdk/issues/67#issuecomment-1227460068):
```
packagingOptions {
    doNotStrip "*/arm64-v8a/libdispatch.so"
    doNotStrip "*/armeabi-v7a/libdispatch.so"
    doNotStrip "*/x86_64/libdispatch.so"
}
```

## Building an Android SDK from source

Download the Swift 6.1.2 compiler as above and Android NDK 27c (only building
the Android SDKs on linux works for now). Check out this repo and run
`SWIFT_TAG=swift-6.1.2-RELEASE ANDROID_ARCH=aarch64 swift get-packages-and-swift-source.swift`
to get some prebuilt Android libraries and the Swift source to build an AArch64
SDK. If you pass in a different tag like `swift-DEVELOPMENT-SNAPSHOT-2025-04-03-a`
for the latest Swift trunk snapshot and pass in the path to the corresponding
prebuilt Swift toolchain to `build-script` below, you can build a Swift trunk
SDK too, as seen on the CI.

Next, apply two patches from this repo to the Swift source, which make
modifications for NDK 27 and [the Foundation rewrite in Swift 6 that was merged
last summer](https://www.swift.org/blog/foundation-preview-now-available/), and
substitute a string for NDK 27:
```
git apply swift-android.patch swift-android-testing-release.patch
perl -pi -e 's%r26%r27%' swift/stdlib/cmake/modules/AddSwiftStdlib.cmake
```

After making sure [needed build tools like python 3, CMake, and ninja](https://github.com/swiftlang/swift/blob/release/6.1/docs/HowToGuides/GettingStarted.md#linux)
are installed, run the following `build-script` command with your local paths
substituted instead:
```
./swift/utils/build-script -RA --skip-build-cmark --build-llvm=0 --android
--android-ndk /home/finagolfin/android-ndk-r27c/ --android-arch aarch64 --android-api-level 24
--build-swift-tools=0 --native-swift-tools-path=/home/finagolfin/swift-6.1.2-RELEASE-ubuntu22.04/usr/bin/
--native-clang-tools-path=/home/finagolfin/swift-6.1.2-RELEASE-ubuntu22.04/usr/bin/
--host-cc=/usr/bin/clang-13 --host-cxx=/usr/bin/clang++-13
--cross-compile-hosts=android-aarch64 --cross-compile-deps-path=/home/finagolfin/swift-release-android-aarch64-24-sdk
--skip-local-build --xctest --swift-install-components='clang-resource-dir-symlink;license;stdlib;sdk-overlay'
--install-swift --install-libdispatch --install-foundation --install-xctest
--install-destdir=/home/finagolfin/swift-release-android-aarch64-24-sdk --skip-early-swiftsyntax
--cross-compile-append-host-target-to-destdir=False --build-swift-static-stdlib -j9
```
Make sure you have an up-to-date CMake and not something old like 3.16. The
`--host-cc` and `--host-cxx` flags are not needed if you have a `clang` and
`clang++` in your `PATH` already, but I don't and they're unused for this build
anyway but required by `build-script`. Substitute armv7 or x86_64 for aarch64
into these commands to build SDKs for those architectures instead.

Finally, copy `libc++_shared.so` from the NDK and modify the cross-compiled
Swift corelibs to include `$ORIGIN` and other relative directories in their rpaths:
```
cp /home/yourname/android-ndk-r27c/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so swift-release-android-aarch64-24-sdk/usr/lib
patchelf --set-rpath \$ORIGIN/../..:\$ORIGIN swift-release-android-aarch64-24-sdk/usr/lib/swift/android/lib*.so
```

Here is a description of what the above Swift script is doing:

This prebuilt SDK was compiled against Android API 24, because the Swift
Foundation libraries require some libraries like libcurl, that are pulled from the
prebuilt library packages used by the Termux app, which are built against Android
API 24. Specifically, it downloads the libandroid-execinfo, libandroid-spawn,
libcurl, and libxml2 packages and their handful of dependencies from the [Termux
package repository](https://packages.termux.dev/apt/termux-main/pool/main/).

Each one is unpacked with `ar x libcurl_8.13.0_aarch64.deb; tar xf data.tar.xz` and
the resulting files moved to a newly-created Swift release SDK directory:
```
mkdir swift-release-android-aarch64-24-sdk
mv data/data/com.termux/files/usr swift-release-android-aarch64-24-sdk
```
It removes two config scripts in `usr/bin`, runs `patchelf` to remove the
Termux rpath from all Termux shared libraries, removes some unused libraries
and config files, and modifies the libraries to get rid of the versioning and
symlinks, which can't always be used on Android:
```
rm swift-release-android-aarch64-24-sdk/usr/bin/*-config
cd swift-release-android-aarch64-24-sdk/usr/lib

patchelf --set-rpath \$ORIGIN libandroid-spawn.so libcurl.so libxml2.so

# repeat the following for all versioned Termux libraries, as needed
rm libxml2.so libxml2.so.2
readelf -d libxml2.so.2.13.7
mv libxml2.so.2.13.7 libxml2.so
patchelf --set-soname libxml2.so libxml2.so
patchelf --replace-needed libz.so.1 libz.so libxml2.so
```
The libcurl and libxml2 packages are [only needed for the FoundationNetworking
and FoundationXML libraries respectively](https://github.com/swiftlang/swift-corelibs-foundation/blob/release/5.10/Docs/ReleaseNotes_Swift5.md),
so you don't have to deploy them on the Android device if you don't use those
extra Foundation libraries.

This Swift SDK for Android could be built without using any prebuilt Termux
packages, by compiling against a more recent Android API that doesn't need the
`libandroid-spawn` backport, and by cross-compiling libcurl/libxml2 and their
dependencies yourself or not using FoundationNetworking and FoundationXML.

Finally, it gets [the 6.1.2 source](https://github.com/swiftlang/swift/releases/tag/swift-6.1.2-RELEASE)
tarballs for eleven Swift repos and renames them to `llvm-project/`, `swift/`,
`swift-syntax`, `swift-experimental-string-processing`, `swift-corelibs-libdispatch`,
`swift-corelibs-foundation`, `swift-collections`, `swift-foundation`,
`swift-foundation-icu`, `swift-corelibs-xctest`, and `swift-testing`, as required
by the Swift `build-script`.
