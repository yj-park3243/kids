fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios check_app

```sh
[bundle exec] fastlane ios check_app
```

ASC에 앱 등록 여부 확인

### ios enable_push

```sh
[bundle exec] fastlane ios enable_push
```

Push Notifications capability 활성화 + 프로파일 재발급

### ios enable_apple_signin

```sh
[bundle exec] fastlane ios enable_apple_signin
```

Sign In with Apple capability 활성화 + 프로파일 재발급

### ios debug_signing

```sh
[bundle exec] fastlane ios debug_signing
```

팀/Bundle ID/인증서 매핑 디버그

### ios deploy

```sh
[bundle exec] fastlane ios deploy
```

TestFlight 배포

### ios upload

```sh
[bundle exec] fastlane ios upload
```

이미 빌드된 IPA 를 TestFlight 에 업로드 (flutter build 없이)

### ios submit_when_ready

```sh
[bundle exec] fastlane ios submit_when_ready
```

방금 올린 TestFlight 빌드 처리 완료까지 대기 후 App Store 심사 제출

### ios ensure_version

```sh
[bundle exec] fastlane ios ensure_version
```

ASC 에 현재 marketing version 의 편집(editable) 버전이 없으면 생성

### ios submit

```sh
[bundle exec] fastlane ios submit
```

App Store 심사 제출 (TestFlight 에 올라간 빌드 사용). `fastlane submit build:55` 로 빌드번호 지정 가능.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
