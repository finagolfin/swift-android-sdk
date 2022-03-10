# Swift cross-compilation SDKs for Android

All patches used to build these SDKs are open source and listed below. I
maintain [a daily CI](https://github.com/buttaface/swift-android-sdk/actions?query=event%3Aschedule)
on [github Actions that cross-compiles the SDK from the three main source branches
of the Swift toolchain for AArch64, armv7, and x86_64, builds several Swift packages
against those SDKs, and then runs their tests in the Android x86_64
emulator](https://github.com/buttaface/swift-android-sdk/blob/main/.github/workflows/sdks.yml).

To build with a Swift 5.5.2 SDK, first download [the latest Android LTS NDK
23b](https://developer.android.com/ndk/downloads) and [Swift 5.5.3
compiler](https://swift.org/download/#releases) (make sure to install the Swift
compiler's dependencies listed there). Unpack these archives and the SDK.

I will write up a Swift script to do this SDK configuration, but you will need
to do it manually for now. [You can see how I do it on the CI for a concrete
example](https://github.com/buttaface/swift-android-sdk/blob/5.5.2/.github/workflows/sdks.yml#L156).

The SDK will need to be modified with the path to your NDK and Swift compiler
in the following ways (I'll show aarch64 below, the same will need to be done
for the armv7 or x86_64 SDKs):

1. Change all paths in `swift-5.5.2-android-aarch64-24-sdk/usr/lib/swift/android/aarch64/glibc.modulemap`
from `/home/butta/android-ndk-r23b` to the path to your NDK, ie something
like `/home/yourname/android-ndk-r23b`.

2. There's a single line pointing to a header in the SDK itself, so change it
from `/home/butta/swift-5.5.2-android-aarch64-24-sdk` in `glibc.modulemap` to the
path where you unpacked this SDK, such as `/home/yourname/swift-5.5.2-android-aarch64-24-sdk`.

3. Change the symbolic link at `swift-5.5.2-android-aarch64-24-sdk/usr/lib/swift/clang`
to point to the clang headers next to your swift compiler, eg

```
ln -sf /home/yourname/swift-5.5.3-RELEASE-ubuntu20.04/usr/lib/clang/10.0.0
swift-5.5.2-android-aarch64-24-sdk/usr/lib/swift/clang
```

Finally, modify the cross-compilation JSON file in this repo similarly:

1. All paths to the NDK should change from `/home/butta/android-ndk-r23b`
to the path to your NDK, `/home/yourname/android-ndk-r23b`.

2. The path to the compiler should change from `/home/butta/swift-5.5.3-RELEASE-ubuntu20.04`
to the path to your Swift compiler, `/home/yourname/swift-5.5.3-RELEASE-centos8`.

3. The path to the Android SDK should change from `/home/butta/swift-5.5.2-android-aarch64-24-sdk`
to the path where you unpacked the Android SDK, `/home/yourname/swift-5.5.2-android-aarch64-24-sdk`.

Now you're ready to cross-compile a Swift package with the cross-compilation
configuration JSON file, android-aarch64.json, and run its tests on Android.
I'll demonstrate with the swift-argument-parser package:
```
git clone --depth 1 https://github.com/apple/swift-argument-parser.git
cd swift-argument-parser/
/home/yourname/swift-5.5.3-RELEASE-ubuntu20.04/usr/bin/swift build --build-tests
--enable-test-discovery --destination ~/swift-android-sdk/android-aarch64.json
-Xlinker -rpath -Xlinker \$ORIGIN/swift-5.5.2-android-aarch64-24-sdk/usr/lib/swift/android
```
This will cross-compile the package for Android aarch64 and produce a test
runner executable with the `.xctest` extension, in this case at
`.build/aarch64-unknown-linux-android/debug/swift-argument-parserPackageTests.xctest`.
It adds a rpath for where it expects the SDK libraries to be relative to the
test runner when run on Android.

Sometimes the test runner will depend on additional files or executables: this
one depends on the example executables `math`, `repeat`, and `roll` in the
same build directory. Other packages use `#file` to point at test data in the
repo: I've had success moving this data with the test runner, after modifying
the test source so it has the path to this test data in the Android test
environment. See the example of [swift-crypto on the
CI](https://github.com/buttaface/swift-android-sdk/blob/5.5.2/.github/workflows/sdks.yml#L308).

You can copy these executables and the SDK to [an emulator or a USB
debugging-enabled device with adb](https://github.com/apple/swift/blob/release/5.5/docs/Android.md#4-deploying-the-build-products-to-the-device),
or put them on an Android device with [a terminal emulator app like Termux](https://termux.com).
I test aarch64 with Termux so I'll show how to run the test runner there, but
the process is similar with adb, [as can be seen on the CI](https://github.com/buttaface/swift-android-sdk/blob/5.5.2/.github/workflows/sdks.yml#L342).

Copy the test executables to the same directory as the SDK:
```
cp .build/aarch64-unknown-linux-android/debug/{swift-argument-parserPackageTests.xctest,math,repeat,roll} ..
```
You can copy the SDK and test executables to Termux using scp from OpenSSH, run
these commands in Termux on the Android device:
```
uname -m # check if you're running on the right architecture, should say `aarch64`
cd       # move to the Termux app's home directory
pkg install openssh

scp yourname@192.168.1.1:{swift-5.5.2-android-aarch64-24-sdk.tar.xz,
swift-argument-parserPackageTests.xctest,math,repeat,roll} .

tar xf swift-5.5.2-android-aarch64-24-sdk.tar.xz

./swift-argument-parserPackageTests.xctest
```
I tried a handful of Swift packages, including some mostly written in C or C++,
and all the cross-compiled tests passed.

You can even run armv7 tests on an aarch64 device, though Termux may require
running `unset LD_PRELOAD` before invoking an armv7 test runner on aarch64.
Revert that with `export LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec.so`
when you're done running armv7 tests and want to go back to the normal aarch64
mode.

# Building the Android SDKs

Download the Swift 5.5.3 compiler and Android NDK 23b as above. Check out this
repo and run
`SWIFT_TAG=swift-5.5.3-RELEASE ANDROID_ARCH=aarch64 swift get-packages-and-swift-source.swift`
to get some prebuilt Android libraries and the Swift source to build the SDK. If
you pass in a different tag like `swift-DEVELOPMENT-SNAPSHOT-2021-12-23-a`
for the latest Swift trunk snapshot and pass in the path to the corresponding
official prebuilt Swift toolchain to `build-script` below, you can build a Swift
trunk SDK too, as seen on the CI.

Next, apply some patches to the Swift source, `swift-android-release.patch` from
this repo, which has build configuration tweaks specific to building this
Android SDK, and two patches that have been merged into trunk upstream:
```
git apply swift-android-release.patch
wget -q https://patch-diff.githubusercontent.com/raw/apple/swift/pull/40633.diff
wget -q https://patch-diff.githubusercontent.com/raw/apple/swift/pull/40707.diff
cd swift
patch -p1 < ../40633.diff
patch -p1 < ../40707.diff
cd ..
```

After making sure [needed build tools like python 3, CMake, and ninja](https://github.com/apple/swift/blob/release/5.5/docs/HowToGuides/GettingStarted.md#ubuntu-linux)
are installed, run the following `build-script` command with your local paths
substituted instead:
```
./swift/utils/build-script -RA --skip-build-cmark --build-llvm=0 --android
--android-ndk /home/butta/android-ndk-r23b/ --android-arch aarch64 --android-api-level 24
--android-icu-uc /home/butta/swift-5.5.3-android-aarch64-24-sdk/usr/lib/libicuuc.so
--android-icu-uc-include /home/butta/swift-5.5.3-android-aarch64-24-sdk/usr/include/
--android-icu-i18n /home/butta/swift-5.5.3-android-aarch64-24-sdk/usr/lib/libicui18n.so
--android-icu-i18n-include /home/butta/swift-5.5.3-android-aarch64-24-sdk/usr/include/
--android-icu-data /home/butta/swift-5.5.3-android-aarch64-24-sdk/usr/lib/libicudata.so
--build-swift-tools=0 --native-swift-tools-path=/home/butta/swift-5.5.3-RELEASE-ubuntu20.04/usr/bin/
--native-clang-tools-path=/home/butta/swift-5.5.3-RELEASE-ubuntu20.04/usr/bin/
--host-cc=/usr/bin/clang-11 --host-cxx=/usr/bin/clang++-11
--cross-compile-hosts=android-aarch64 --cross-compile-deps-path=/home/butta/swift-5.5.3-android-aarch64-24-sdk
--skip-local-build --xctest --swift-install-components='clang-resource-dir-symlink;license;stdlib;sdk-overlay'
--install-swift --install-libdispatch --install-foundation --install-xctest
--install-destdir=/home/butta/swift-5.5.3-android-aarch64-24-sdk
--cross-compile-append-host-target-to-destdir=False -j9
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
cp /home/yourname/android-ndk-r23b/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so swift-5.5.3-android-aarch64-24-sdk/usr/lib
patchelf --set-rpath \$ORIGIN/../..:\$ORIGIN swift-5.5.3-android-aarch64-24-sdk/usr/lib/swift/android/lib*.so
```

Here is a description of what the above Swift script is doing:

These prebuilt SDKs were compiled against Android API 24, because the Swift
stdlib and corelibs require some libraries like libicu, that are pulled from the
prebuilt library packages used by the Termux app which are built against Android
API 24. Specifically, it downloads the libicu, libicu-static, libandroid-spawn,
libcurl, and libxml2 packages from the [Termux package
repository](https://packages.termux.org/apt/termux-main/pool/main/).

Each one is unpacked with `ar x libicu_70.1_aarch64.deb; tar xf data.tar.xz` and
the resulting files moved to a newly-created Swift 5.5.3 SDK directory:
```
mkdir swift-5.5.3-android-aarch64-24-sdk
mv data/data/com.termux/files/usr swift-5.5.3-android-aarch64-24-sdk
```
It removes two config scripts in `usr/bin`, runs `patchelf` to remove the
Termux rpath from all Termux shared libraries, and modifies the ICU libraries
to get rid of the versioning and symlinks (three libicu libraries are removed
since they're unused by Swift):
```
rm swift-5.5.3-android-aarch64-24-sdk/usr/bin/*-config
cd swift-5.5.3-android-aarch64-24-sdk/usr/lib

rm libicu{io,test,tu}*
patchelf --set-rpath \$ORIGIN libandroid-spawn.so libcurl.so libicu*so.70.1 libxml2.so

# repeat the following for libicui18n.so and libicudata.so, as needed
rm libicuuc.so libicuuc.so.70
readelf -d libicuuc.so.70.1
mv libicuuc.so.70.1 libicuuc.so
patchelf --set-soname libicuuc.so libicuuc.so
patchelf --replace-needed libicudata.so.70 libicudata.so libicuuc.so
```
The libcurl and libxml2 packages are [only needed for the FoundationNetworking
and FoundationXML libraries respectively](https://github.com/apple/swift-corelibs-foundation/blob/release/5.5/Docs/ReleaseNotes_Swift5.md),
so you don't have to deploy them on the Android device if you don't use those
extra Foundation libraries.

I simply include all four libraries since there's currently no way to disable
building them in the CMake configuration, but they won't actually run on
Android with this SDK, as libcurl and libxml2 have other library dependencies
that aren't included. If you want to use either of these separate Foundation
libraries, you will have to track down those other libcurl/xml2 dependencies and
include them yourself.

The libicu dependency can be [cross-compiled for Android from scratch using
these instructions](https://github.com/apple/swift/blob/release/5.5/docs/Android.md#1-downloading-or-building-the-swift-android-stdlib-dependencies)
instead, so this Swift SDK for Android could be built without using
any prebuilt Termux packages, if you're willing to put in the effort to
cross-compile them yourself, for example, against a different Android API.

Finally, it gets [the 5.5.3 source](https://github.com/apple/swift/releases/tag/swift-5.5.3-RELEASE)
tarballs for five Swift repos and renames them to `llvm-project/`, `swift/`,
`swift-corelibs-libdispatch`, `swift-corelibs-foundation`, and
`swift-corelibs-xctest`, as required by the Swift `build-script`, and creates
an empty directory, `mkdir cmark`.
