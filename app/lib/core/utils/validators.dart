class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해 주세요';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return '올바른 이메일 형식이 아닙니다';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해 주세요';
    }
    if (value.length < 8) {
      return '비밀번호는 8자 이상이어야 합니다';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return '영문을 포함해야 합니다';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return '숫자를 포함해야 합니다';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return '특수문자를 포함해야 합니다';
    }
    return null;
  }

  static String? nickname(String? value) {
    if (value == null || value.isEmpty) {
      return '닉네임을 입력해 주세요';
    }
    if (value.length < 2 || value.length > 10) {
      return '닉네임은 2~10자로 입력해 주세요';
    }
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return '특수문자는 사용할 수 없습니다';
    }
    return null;
  }

  static String? required(String? value, [String fieldName = '']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName을(를) 입력해 주세요';
    }
    return null;
  }

  static String? roomTitle(String? value) {
    if (value == null || value.isEmpty) {
      return '제목을 입력해 주세요';
    }
    if (value.length < 2 || value.length > 30) {
      return '제목은 2~30자로 입력해 주세요';
    }
    return null;
  }

  static String? roomDescription(String? value) {
    if (value == null || value.isEmpty) {
      return '설명을 입력해 주세요';
    }
    if (value.length < 10 || value.length > 500) {
      return '설명은 10~500자로 입력해 주세요';
    }
    return null;
  }
}
