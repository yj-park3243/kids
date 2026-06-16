fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android build

```sh
[bundle exec] fastlane android build
```

Flutter AAB 빌드

### android internal

```sh
[bundle exec] fastlane android internal
```

Google Play Internal Testing 배포

### android production

```sh
[bundle exec] fastlane android production
```

Google Play 프로덕션 심사 제출 (정식 출시)

### android promote_to_closed

```sh
[bundle exec] fastlane android promote_to_closed
```

내부 테스트에 올라간 빌드를 비공개 테스트(Closed)로 승격 — 재빌드/재업로드 없음

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
