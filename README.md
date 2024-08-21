# Swift cross-compilation SDK for Android

The patch used to build this SDK is open source and listed below. I
maintain [a daily CI on github Actions](https://github.com/finagolfin/swift-android-sdk/actions?query=event%3Aschedule)
that [cross-compiles the SDK from the release and development source branches of
the Swift toolchain for AArch64, armv7, and x86_64, builds several Swift
packages against those SDKs, and then runs their tests in the Android x86_64
emulator](https://github.com/finagolfin/swift-android-sdk/blob/main/.github/workflows/sdks.yml).

Now that Swift 5.10 supports [the new SDK bundle
format](https://github.com/apple/swift-evolution/blob/main/proposals/0387-cross-compilation-destinations.md),
I plan to distribute an Android SDK bundle in the coming months.

## Cross-compiling and testing Swift packages with the Android SDK

To build with the Swift 5.10 SDK, first download [the latest Android LTS NDK
27](https://developer.android.com/ndk/downloads) and [Swift 5.10.1
compiler](https://swift.org/download/#releases) (make sure to install the Swift
compiler's dependencies linked there). Unpack these archives and the SDK.

Change the symbolic link at `swift-5.10-android-24-sdk/usr/lib/swift/clang`
to point to the clang headers that come with your swift compiler, eg

```
ln -sf /home/yourname/swift-5.10.1-RELEASE-ubuntu22.04/usr/lib/clang/15.0.0
swift-5.10-android-24-sdk/usr/lib/swift/clang
```

Next, modify the cross-compilation JSON file `android-aarch64.json` in this repo
similarly:

1. All paths to the NDK should change from `/home/finagolfin/android-ndk-r27`
to the path to your NDK, `/home/yourname/android-ndk-r27`.

2. The path to the compiler should change from `/home/finagolfin/swift-5.10.1-RELEASE-ubuntu22.04`
to the path to your Swift compiler, `/home/yourname/swift-5.10.1-RELEASE-ubi9`.

3. The paths to the Android SDK should change from `/home/finagolfin/swift-5.10-android-24-sdk`
to the path where you unpacked the Android SDK, `/home/yourname/swift-5.10-android-24-sdk`.

Now you're ready to cross-compile a Swift package with the cross-compilation
configuration JSON file, `android-aarch64.json`, and run its tests on Android.
I'll demonstrate with the swift-argument-parser package:
```
git clone --depth 1 https://github.com/apple/swift-argument-parser.git

cd swift-argument-parser/

/home/yourname/swift-5.10.1-RELEASE-ubuntu22.04/usr/bin/swift build --build-tests
--destination ~/swift-android-sdk/android-aarch64.json
-Xlinker -rpath -Xlinker \$ORIGIN/swift-5.10-android-24-sdk/usr/lib/aarch64-linux-android
```
This will cross-compile the package for Android aarch64 and produce a test
runner executable with the `.xctest` extension, in this case at
`.build/aarch64-unknown-linux-android24/debug/swift-argument-parserPackageTests.xctest`.
It adds a rpath for where it expects the SDK libraries to be relative to the
test runner when run on Android.

Sometimes the test runner will depend on additional files or executables: this
one depends on the example executables `generate-manual`, `math`, `repeat`, and
`roll` in the same build directory. Other packages use `#file` to point at test
data in the repo: I've had success moving this data with the test runner, after
modifying the test source so it has the path to this test data in the Android
test environment. See the example of [swift-crypto on the
CI](https://github.com/finagolfin/swift-android-sdk/blob/5.10/.github/workflows/sdks.yml#L317).

You can copy these executables and the SDK to [an emulator or a USB
debugging-enabled device with adb](https://github.com/apple/swift/blob/release/5.10/docs/Android.md#3-deploying-the-build-products-to-the-device),
or put them on an Android device with [a terminal emulator app like Termux](https://termux.dev/en/).
I test aarch64 with Termux so I'll show how to run the test runner there, but
the process is similar with adb, [as can be seen on the CI](https://github.com/finagolfin/swift-android-sdk/blob/5.10/.github/workflows/sdks.yml#L355).

Copy the test executables to the same directory as the SDK:
```
cp .build/aarch64-unknown-linux-android24/debug/{swift-argument-parserPackageTests.xctest,generate-manual,math,repeat,roll} ..
```
You can copy the SDK and test executables to Termux using scp from OpenSSH, run
these commands in Termux on the Android device:
```
uname -m # check if you're running on the right architecture, should say `aarch64`
cd       # move to the Termux app's home directory
pkg install openssh

scp yourname@192.168.1.1:{swift-5.10-android-24-sdk.tar.xz,
swift-argument-parserPackageTests.xctest,generate-manual,math,repeat,roll} .

tar xf swift-5.10-android-24-sdk.tar.xz

./swift-argument-parserPackageTests.xctest
```
I've tried several Swift packages, including some mostly written in C or C++,
and all the cross-compiled tests passed.

You can even run armv7 tests on an aarch64 device, though Termux may require
running `unset LD_PRELOAD` before invoking an armv7 test runner on aarch64.
Revert that with `export LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec.so`
when you're done running armv7 tests and want to go back to the normal aarch64
mode.

## Porting Swift packages to Android

The most commonly needed change is to simply import Glibc for Android too (while
Bionic is the name of the C library on Android, currently Swift uses the name
`Glibc` as a placeholder for most non-Darwin, non-Windows C libraries), so add
or change these two lines for Android:
```
#if canImport(Glibc)
import Glibc
```
For example, that is all I had to do [to port swift-argument-parser to
Android](https://github.com/apple/swift-argument-parser/pull/14/files).

You may also need to add some Android-specific support using `#if os(Android)`,
for example, since FILE is an opaque struct since Android 7, you will [have to
refer to any FILE pointers like this](https://github.com/apple/swift-tools-support-core/pull/243/files):
```
#if os(Android)
typealias FILEPointer = OpaquePointer
```

## Building an Android app with Swift

Some people have reported an issue with using the libraries from this SDK in
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

Note that the FoundationNetworking and FoundationXML libraries won't actually
run on Android with this SDK, as their dependencies libcurl and libxml2 have other
library dependencies that aren't included. If you want to use either of these
separate Foundation libraries, you will have to track down those other libcurl/xml2
dependencies and include them yourself.

## Building the Android SDKs from source

Download the Swift 5.10.1 compiler and Android NDK 27 as above. Check out this
repo and run
`SWIFT_TAG=swift-5.10.1-RELEASE ANDROID_ARCH=aarch64 swift get-packages-and-swift-source.swift`
to get some prebuilt Android libraries and the Swift source to build the SDK. If
you pass in a different tag like `swift-DEVELOPMENT-SNAPSHOT-2024-03-30-a`
for the latest Swift trunk snapshot and pass in the path to the corresponding
prebuilt Swift toolchain to `build-script` below, you can build a Swift trunk
SDK too, as seen on the CI.

Next, apply a patch to the Swift source, `swift-android.patch` from this repo,
which adds a dependency for the Foundation core library in this Android SDK, and
four more patches that make modifications for the nullability annotations newly
added in NDK 26:
```
git apply swift-android.patch swift-android-both-ndks.patch swift-android-foundation-ndk26.patch swift-android-stdlib-ndk26.patch swift-android-stdlib-except-trunk.patch
```

After making sure [needed build tools like python 3, CMake, and ninja](https://github.com/apple/swift/blob/release/5.10/docs/HowToGuides/GettingStarted.md#linux)
are installed, run the following `build-script` command with your local paths
substituted instead:
```
./swift/utils/build-script -RA --skip-build-cmark --build-llvm=0 --android
--android-ndk /home/finagolfin/android-ndk-r27/ --android-arch aarch64 --android-api-level 24
--build-swift-tools=0 --native-swift-tools-path=/home/finagolfin/swift-5.10.1-RELEASE-ubuntu22.04/usr/bin/
--native-clang-tools-path=/home/finagolfin/swift-5.10.1-RELEASE-ubuntu22.04/usr/bin/
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
into these commands to build for those architectures instead.

Finally, copy `libc++_shared.so` from the NDK and modify the cross-compiled
`libdispatch.so` and Swift corelibs to include `$ORIGIN` and other relative
directories in their rpaths:
```
cp /home/yourname/android-ndk-r27/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so swift-release-android-aarch64-24-sdk/usr/lib
patchelf --set-rpath \$ORIGIN/../..:\$ORIGIN swift-release-android-aarch64-24-sdk/usr/lib/swift/android/lib*.so
```

Here is a description of what the above Swift script is doing:

This prebuilt SDK was compiled against Android API 24, because the Swift
stdlib and corelibs require some libraries like libicu, that are pulled from the
prebuilt library packages used by the Termux app, which are built against Android
API 24. Specifically, it downloads the libicu, libicu-static, libandroid-spawn,
libcurl, and libxml2 packages from the [Termux package
repository](https://packages.termux.dev/apt/termux-main/pool/main/).

Each one is unpacked with `ar x libicu_74.2_aarch64.deb; tar xf data.tar.xz` and
the resulting files moved to a newly-created Swift release SDK directory:
```
mkdir swift-release-android-aarch64-24-sdk
mv data/data/com.termux/files/usr swift-release-android-aarch64-24-sdk
```
It removes two config scripts in `usr/bin`, runs `patchelf` to remove the
Termux rpath from all Termux shared libraries, and modifies the ICU libraries
to get rid of the versioning and symlinks (three libicu libraries are removed
since they're unused by Swift):
```
rm swift-release-android-aarch64-24-sdk/usr/bin/*-config
cd swift-release-android-aarch64-24-sdk/usr/lib

rm libicu{io,test,tu}*
patchelf --set-rpath \$ORIGIN libandroid-spawn.so libcurl.so libicu*so.74.2 libxml2.so

# repeat the following for libicui18n.so and libicudata.so, as needed
rm libicuuc.so libicuuc.so.74
readelf -d libicuuc.so.74.2
mv libicuuc.so.74.2 libicuuc.so
patchelf --set-soname libicuuc.so libicuuc.so
patchelf --replace-needed libicudata.so.74 libicudata.so libicuuc.so
```
The libcurl and libxml2 packages are [only needed for the FoundationNetworking
and FoundationXML libraries respectively](https://github.com/apple/swift-corelibs-foundation/blob/release/5.10/Docs/ReleaseNotes_Swift5.md),
so you don't have to deploy them on the Android device if you don't use those
extra Foundation libraries. I simply include all four libraries since there's
currently no way to disable building them in the CMake configuration.

The libicu dependency can be [cross-compiled for Android from scratch using
these instructions](https://github.com/apple/swift/blob/release/5.5/docs/Android.md#1-downloading-or-building-the-swift-android-stdlib-dependencies)
instead, so this Swift SDK for Android could be built without using
any prebuilt Termux packages, if you're willing to put in the effort to
cross-compile them yourself, for example, against a different Android API.

Finally, it gets [the 5.10.1 source](https://github.com/apple/swift/releases/tag/swift-5.10.1-RELEASE)
tarballs for seven Swift repos and renames them to `llvm-project/`, `swift/`,
`swift-syntax`, `swift-experimental-string-processing`, `swift-corelibs-libdispatch`,
`swift-corelibs-foundation`, and `swift-corelibs-xctest`, as required by the Swift
`build-script`.
