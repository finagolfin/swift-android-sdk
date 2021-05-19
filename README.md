# Swift cross-compilation SDKs for Android

All patches used to build these SDKs are open source and listed below.

To build with an SDK, first download
[the latest Android NDK 21d](https://developer.android.com/ndk/downloads)
and [Swift 5.3.1 compiler](https://swift.org/download/#releases) (make sure to
install the Swift compiler's dependencies listed there). Unpack these archives
and the SDK.

I will write up a Swift script to do this SDK configuration next, but you will
need to manually do it for now.

The SDK will need to be modified with the path to your NDK and Swift compiler
in the following ways (I'll show aarch64 below, the same will need to be done
for the armv7 or x86_64 SDKs):

1. Change all paths in `swift-android-aarch64-24-sdk/usr/lib/swift/android/aarch64/glibc.modulemap`
from `/home/butta/swift/android-ndk-r21d` to the path to your NDK, ie something
like `/home/yourname/android-ndk-r21d` (for Swift 5.4, change the one line from
`/home/butta/swift-5.4-android-aarch64-24-sdk` to the path to the Android SDK).

2. Change the symbolic link at `swift-android-aarch64-24-sdk/usr/lib/swift/clang`
to point to the clang headers next to your swift compiler, eg

```
ln -sf /home/yourname/swift-5.3.1-RELEASE-ubuntu20.04/usr/lib/clang/10.0.0
swift-android-aarch64-24-sdk/usr/lib/swift/clang
```
Finally, modify the cross-compilation JSON file in this repo similarly:

1. All paths to the NDK should change from `/home/butta/swift/android-ndk-r21d`
to the path to your NDK, `/home/yourname/android-ndk-r21d`.

2. The path to the compiler should change from `/home/butta/swift/swift-5.3.1-RELEASE-ubuntu20.04`
to the path to your Swift compiler, `/home/yourname/swift-5.3.1-RELEASE-ubuntu20.04`.

3. The path to the Android SDK should change from `/home/butta/swift/swift-android-aarch64-24-sdk`
to the path where you unpacked the Android SDK, `/home/yourname/swift-android-aarch64-24-sdk`.

Now you're ready to cross-compile a Swift package with the cross-compilation
configuration JSON file, android-aarch64.json, and run its tests on Android.
I'll demonstrate with the swift-argument-parser package:
```
git clone https://github.com/apple/swift-argument-parser.git
cd swift-argument-parser/
/home/yourname/swift-5.3.1-RELEASE-ubuntu20.04/usr/bin/swift build --build-tests
--enable-test-discovery --destination ~/swift-android-sdk/android-aarch64.json
```
This will build the package and produce a test runner executable with the
`.xctest` extension, in this case at `.build/aarch64-unknown-linux-android/debug/swift-argument-parserPackageTests.xctest`.
Sometimes the test runner will depend on additional files or executables: this
one depends on the example executables `math`, `repeat`, and `roll` in the
same build directory. Other packages use `#file` to point at test data in the
repo, I've had success moving this data with the test runner, after modifying
the test source so it has the path to this test data in the Android test
environment.

You can copy these executables and the SDK to an emulator or [a USB
debugging-enabled device with adb](https://github.com/apple/swift/blob/release/5.3/docs/Android.md#4-deploying-the-build-products-to-the-device),
or put them on an Android device with [a terminal emulator app like Termux](https://termux.com).
I only test with Termux so I'll show how to run the test runner there, but the
process is similar with adb.

The test runner and its example executables will need to have the right runtime
path for the SDK, so run `patchelf`, which is available as a package on most
linux distros or in Termux, to add the SDK to their rpath:
```
cp .build/aarch64-unknown-linux-android/debug/{swift-argument-parserPackageTests.xctest,math,repeat,roll} ..
cd ../

patchelf --set-rpath \$ORIGIN/swift-android-aarch64-24-sdk/usr/lib/swift/android
swift-argument-parserPackageTests.xctest math repeat roll
```
You can copy the SDK and test executables to Termux using scp from OpenSSH, run
these commands in Termux on the Android device:
```
uname -m # check if you're running on the right architecture, should say `aarch64`
cd       # move to the Termux app's home directory
pkg install openssh

scp yourname@192.168.1.1:{swift-android-aarch64-24-sdk.tar.xz,
swift-argument-parserPackageTests.xctest,math,repeat,roll} .

tar xf swift-android-aarch64-24-sdk.tar.xz

./swift-argument-parserPackageTests.xctest
```
I tried a handful of Swift packages, including some mostly written in C or C++,
and all the cross-compiled tests passed.

You can even run armv7 tests on an aarch64 device, though Termux requires
running `unset LD_PRELOAD` before invoking an armv7 test runner on aarch64.
Revert that with `export LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec.so`
when you're done running armv7 tests and want to go back to the normal aarch64
mode.

# Building the Android SDKs

I will put together a Swift script to automate building these SDKs, but here's
a description of the commands I used to manually put them together this first
time, which you could use in the meantime to build these SDKs yourself or for a
different Android API.

These prebuilt SDKs were compiled against Android API 24, because the Swift
stdlib and corelibs require some libraries like libicu, that I pulled from the
prebuilt library packages used by the Termux app which are built against Android
API 24. Specifically, I downloaded the libicu, libicu-static, libc++, libcurl,
and libxml2 packages from the [Termux package
repository](http://dl.bintray.com/termux/termux-packages-24/) (the package URLs
are obfuscated with an extra colon before the filename, remove it and you should
be able to download them).

I unpacked each one with `ar x libicu_67.1_aarch64.deb; tar xf data.tar.xz` and
moved the resulting files to a newly-created SDK directory:
```
mkdir swift-android-aarch64-24-sdk
mv data/data/com.termux/files/usr swift-android-aarch64-24-sdk
```
I removed two config scripts in `usr/bin` and ran `patchelf` to remove the
Termux rpath from all Termux shared libraries:
```
rm swift-android-aarch64-24-sdk/usr/bin/*-config
cd swift-android-aarch64-24-sdk/usr/lib
patchelf --set-rpath \$ORIGIN libcurl.so libicu*so.67.1 libxml2.so
cd ../../../
```
The libcurl and libxml2 packages are [only needed for the FoundationNetworking
and FoundationXML libraries respectively](https://github.com/apple/swift-corelibs-foundation/blob/release/5.3/Docs/ReleaseNotes_Swift5.md),
so you don't have to deploy them on the Android device if you don't use those
extra Foundation libraries.

I simply include all four libraries since there's currently no way to disable
building them in the CMake configuration, but they won't actually run on
Android with this SDK, as libcurl and libxml2 have other library dependencies
that aren't included. If you want to use either of these separate Foundation
libraries, you will have to track down those other library dependencies and
include them.

The libicu dependency can be [cross-compiled for Android from scratch using
these instructions](https://github.com/apple/swift/blob/release/5.3/docs/Android.md#1-downloading-or-building-the-swift-android-stdlib-dependencies)
instead and the libc++ package simply copies the prebuilt `libc++_shared.so`
over from the NDK, so this Swift SDK for Android could be built without using
any prebuilt Termux packages, if you're willing to put in the effort to
cross-compile them yourself.

Next, I got [the 5.3.1 source](https://github.com/apple/swift/releases/tag/swift-5.3.1-RELEASE)
tarballs for five Swift repos and renamed them to `llvm-project/`, `swift/`,
`swift-corelibs-libdispatch`, `swift-corelibs-foundation`, and
`swift-corelibs-xctest`, as required by the Swift `build-script`. After creating
an empty directory, `mkdir cmark`, I downloaded seven patches that have been
backported to build the Termux package for Swift 5.3.1 (all Termux patches are
available under the [same license as the Termux package, the Apache license used
by Swift in this case](https://github.com/termux/termux-packages/blob/master/LICENSE.md#license-for-package-patches)):

- [Android ARMv7](https://github.com/termux/termux-packages/blob/master/packages/swift/swift-armv7.patch)
- [XCTest rpath](https://github.com/termux/termux-packages/blob/master/packages/swift/swift-corelibs-xctest-CMakeLists.txt.patch)
- [Native clang path](https://github.com/termux/termux-packages/blob/master/packages/swift/swift-native-tools.patch)
- [Build the stdlib with NDK clang](https://github.com/termux/termux-packages/blob/master/packages/swift/swift-runtime-flag.patch)
- [Build with prebuilt Swift toolchain](https://github.com/termux/termux-packages/blob/master/packages/swift/swift-utils-build-script-impl-build.patch)
- [Pass cross-compilation Swift flags to the corelibs](https://github.com/termux/termux-packages/blob/master/packages/swift/swift-utils-build-script-impl-cross.patch)
- [Android x86_64](https://github.com/termux/termux-packages/blob/master/packages/swift/swift-x86_64.patch)

In addition, I applied the [NDK patch from that repo](https://github.com/termux/termux-packages/blob/master/packages/swift/swift-ndk.patch),
but it had to be modified a little because of interactions with other patches so
I put the modified version of that patch in this repo, `swift-ndk-531.patch`.
The eight patches have to be applied in alphabetical order by patch name.

All eight patches have been submitted upstream, with the ARMv7, prebuilt Swift
toolchain, and x86_64 patches already merged in the main branch and the
remaining under review.

Last, apply the `swift-android-531.patch` from this repo: I will submit the
parts of this patch that make sense to be upstreamed to the main branch next.

After making sure [needed build tools like python, CMake, and ninja](https://github.com/apple/swift/tree/release/5.3/#linux)
are installed, I ran the following `build-script` command:
```
PATH=/home/butta/.termux-build/_cache/cmake-3.18.4/bin:$PATH ./swift/utils/build-script
-R --no-assertions --skip-build-cmark --skip-build-llvm --android
--android-ndk /home/butta/swift/android-ndk-r21d/ --android-arch aarch64 --android-api-level 24
--android-icu-uc /home/butta/swift/swift-android-aarch64-24-sdk/usr/lib/libicuuc.so
--android-icu-uc-include /home/butta/swift/swift-android-aarch64-24-sdk/usr/include/
--android-icu-i18n /home/butta/swift/swift-android-aarch64-24-sdk/usr/lib/libicui18n.so
--android-icu-i18n-include /home/butta/swift/swift-android-aarch64-24-sdk/usr/include/
--android-icu-data /home/butta/swift/swift-android-aarch64-24-sdk/usr/lib/libicudata.so
--build-swift-tools=0 --native-swift-tools-path=/home/butta/swift/swift-5.3.1-RELEASE-ubuntu20.04/usr/bin/
--native-clang-tools-path=/home/butta/swift/android-ndk-r21d/toolchains/llvm/prebuilt/linux-x86_64/bin
--host-cc=/usr/bin/clang-10 --host-cxx=/usr/bin/clang++-10
--cross-compile-hosts=android-aarch64 --cross-compile-deps-path=/home/butta/swift/swift-android-aarch64-24-sdk
--skip-local-build --xctest --swift-install-components='clang-resource-dir-symlink;license;stdlib;sdk-overlay'
--install-swift --install-libdispatch --install-foundation --install-xctest
--install-destdir=/home/butta/swift/swift-android-aarch64-24-sdk -j9
```
The first CMake directory is added to my `PATH` to have a more up-to-date CMake
than the Ubuntu 20.04 package. The `--host-cc` and `--host-cxx` flags are not
needed if you have a `clang` and `clang++` in your `PATH` already, but I don't
and they're unused for this build anyway but required by `build-script`.
Substitute armv7 or x86_64 for aarch64 into this command to build for those
architectures instead.

Finally, I had to modify the cross-compiled `libdispatch.so` to include
`$ORIGIN` in its rpath:
```
patchelf --set-rpath \$ORIGIN swift-android-aarch64-24-sdk/usr/lib/swift/android/libdispatch.so
```
