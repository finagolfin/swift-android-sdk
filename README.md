# Swift cross-compilation SDKs for Android

To build with an SDK, first download
[the latest Android NDK 21d](https://developer.android.com/ndk/downloads)
and [Swift 5.3.1 compiler](https://swift.org/download/#releases) (make sure to
install the Swift compiler's dependencies listed there). Unpack these archives
and the SDK.

The SDK will need to be modified with the path to your NDK and Swift compiler
in the following ways (I'll show aarch64 below, the same will need to be done
for the armv7 or x86_64 SDKs):

1. Change all paths in `swift-android-aarch64-24-sdk/usr/lib/swift/android/aarch64/glibc.modulemap`
from `/home/butta/swift/android-ndk-r21d` to the path to your NDK, ie something
like `/home/yourname/android-ndk-r21d`.

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

You can copy these executables and the SDK to an emulator or
[a USB debugging-enabled device with adb](https://github.com/apple/swift/blob/release/5.3/docs/Android.md#4-deploying-the-build-products-to-the-device),
or put them on an Android device with a terminal emulator app like
[Termux](https://termux.com). I only test with Termux so I'll show how to run
the test binary there, but the process is similar with adb.

The test runner and its example executables will need to have the right runtime
path for the SDK, so run `patchelf`, which is available as a package on most
linux distros or in Termux, to add the SDK to their rpath:
```
patchelf --set-rpath \$ORIGIN/swift-android-aarch64-24-sdk/usr/lib/swift/android
swift-argument-parserPackageTests.xctest math repeat roll
```
You can copy the SDK and test executables to Termux using scp from OpenSSH, run
these commands in Termux on the Android device:
```
uname -m # check if you're running on the right architecture, should say `aarch64`
cd       # move to the Termux app's home directory
pkg install openssh

scp -r yourname@192.168.1.1:{swift-android-aarch64-24-sdk,swift-argument-parserPackageTests.xctest,math,repeat,roll} .

./swift-argument-parserPackageTests.xctest
```
I tried a handful of Swift packages, including some mostly written in C or C++,
and all the cross-compiled tests passed.

You can even run armv7 tests on an aarch64 device, though Termux requires
running `unset LD_PRELOAD` before invoking an armv7 test runner on aarch64.
Revert that with `export LD_PRELOAD=/data/data/com.termux/files/usr/lib/libtermux-exec.so`
when you're done running armv7 tests and want to go back to the normal aarch64
mode.
