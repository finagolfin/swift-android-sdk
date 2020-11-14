# Swift cross-compilation SDKs for Android

To build with an SDK, first download [the latest Android NDK 21d](https://developer.android.com/ndk/downloads)
and [Swift compiler](https://swift.org/download/#releases). Unpack these archives
and the SDK.

The SDK will need to be modified with the path to your NDK and Swift compiler
in the following ways:

1. Change all paths in `swift-android-aarch64-24-sdk/usr/lib/swift/android/aarch64/glibc.modulemap`
from `/home/butta/swift/android-ndk-r21d` to the path to your NDK.

2. Change the symbolic link at `swift-android-aarch64-24-sdk/usr/lib/swift/clang`
to point to the clang headers next to your swift compiler, ie

```
ln -sf /home/yourname/swift-5.3.1-RELEASE-ubuntu20.04/usr/lib/clang/10.0.0
swift-android-aarch64-24-sdk/usr/lib/swift/clang
```
Finally, modify the cross-compilation JSON file in this repo similarly:

1. All paths to the NDK should change from `/home/butta/swift/android-ndk-r21d`
to the path to your NDK.

2. The path to the compiler should change from `/home/butta/swift/swift-5.3.1-RELEASE-ubuntu20.04`
to the path to your Swift compiler.

3. The path to the Android SDK should change from `/home/butta/swift/swift-android-aarch64-24-sdk`
to the path to where you unpacked the Android SDK.

Now you're ready to cross-compile a Swift package with the cross-compilation
JSON config:
```
swift build --build-tests --enable-test-discovery --destination ~/swift-android-sdk/android-aarch64.json
```
