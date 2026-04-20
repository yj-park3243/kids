import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';

// Simplified region data for demo - in production, fetch from API
class RegionData {
  static const Map<String, Map<String, List<String>>> regions = {
    '서울특별시': {
      '강남구': ['역삼동', '삼성동', '대치동', '신사동', '논현동', '압구정동', '청담동', '개포동'],
      '강동구': ['천호동', '성내동', '길동', '둔촌동', '암사동', '명일동', '고덕동', '강일동'],
      '강북구': ['미아동', '번동', '수유동', '우이동', '삼양동'],
      '강서구': ['화곡동', '등촌동', '가양동', '발산동', '마곡동', '내발산동', '외발산동'],
      '관악구': ['신림동', '봉천동', '남현동'],
      '광진구': ['자양동', '구의동', '광장동', '능동', '화양동', '군자동', '중곡동'],
      '구로구': ['구로동', '고척동', '개봉동', '오류동', '항동', '신도림동'],
      '금천구': ['가산동', '독산동', '시흥동'],
      '노원구': ['상계동', '중계동', '하계동', '월계동', '공릉동'],
      '도봉구': ['쌍문동', '방학동', '창동', '도봉동'],
      '동대문구': ['용두동', '제기동', '전농동', '답십리동', '장안동', '이문동', '회기동', '휘경동'],
      '동작구': ['노량진동', '상도동', '사당동', '대방동', '신대방동', '흑석동'],
      '마포구': ['합정동', '망원동', '연남동', '상암동', '성산동', '중동', '서교동', '홍대입구'],
      '서대문구': ['연희동', '홍은동', '남가좌동', '북가좌동', '충현동', '신촌동'],
      '서초구': ['서초동', '반포동', '잠원동', '방배동', '양재동', '내곡동'],
      '성동구': ['성수동', '왕십리동', '행당동', '응봉동', '금호동', '옥수동', '마장동'],
      '성북구': ['성북동', '삼선동', '동선동', '돈암동', '안암동', '보문동', '정릉동', '길음동', '종암동'],
      '송파구': ['잠실동', '신천동', '방이동', '오금동', '가락동', '문정동', '장지동', '위례동'],
      '양천구': ['목동', '신정동', '신월동'],
      '영등포구': ['여의도동', '영등포동', '당산동', '문래동', '양평동', '신길동', '대림동'],
      '용산구': ['이태원동', '한남동', '용산동', '서빙고동', '보광동', '효창동', '원효로동'],
      '은평구': ['불광동', '갈현동', '녹번동', '응암동', '역촌동', '신사동', '증산동', '진관동'],
      '종로구': ['종로동', '삼청동', '부암동', '평창동', '무악동', '교남동', '혜화동'],
      '중구': ['명동', '을지로동', '충무로동', '신당동', '황학동', '회현동'],
      '중랑구': ['면목동', '상봉동', '중화동', '묵동', '망우동', '신내동'],
    },
    '경기도': {
      '성남시 분당구': ['정자동', '서현동', '야탑동', '이매동', '수내동', '판교동'],
      '수원시 영통구': ['영통동', '매탄동', '원천동', '광교동'],
      '용인시 수지구': ['죽전동', '풍덕천동', '성복동', '상현동'],
      '고양시 일산서구': ['주엽동', '대화동', '탄현동'],
      '고양시 일산동구': ['마두동', '장항동', '백석동', '풍동'],
      '하남시': ['미사동', '풍산동', '감북동', '감일동'],
    },
  };

  static List<String> getSidos() => regions.keys.toList();
  static List<String> getSigungus(String sido) =>
      regions[sido]?.keys.toList() ?? [];
  static List<String> getDongs(String sido, String sigungu) =>
      regions[sido]?[sigungu] ?? [];
}

class RegionPicker extends StatefulWidget {
  final String? initialSido;
  final String? initialSigungu;
  final String? initialDong;
  final void Function(String sido, String sigungu, String dong) onSelected;

  const RegionPicker({
    super.key,
    this.initialSido,
    this.initialSigungu,
    this.initialDong,
    required this.onSelected,
  });

  @override
  State<RegionPicker> createState() => _RegionPickerState();
}

class _RegionPickerState extends State<RegionPicker> {
  late String? _selectedSido;
  late String? _selectedSigungu;
  late String? _selectedDong;

  @override
  void initState() {
    super.initState();
    _selectedSido = widget.initialSido;
    _selectedSigungu = widget.initialSigungu;
    _selectedDong = widget.initialDong;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('지역 선택', style: AppTextStyles.body2Bold),
        const SizedBox(height: 8),
        // Sido
        _buildDropdown(
          hint: '시/도 선택',
          value: _selectedSido,
          items: RegionData.getSidos(),
          onChanged: (value) {
            setState(() {
              _selectedSido = value;
              _selectedSigungu = null;
              _selectedDong = null;
            });
          },
        ),
        const SizedBox(height: 8),
        // Sigungu
        _buildDropdown(
          hint: '시/군/구 선택',
          value: _selectedSigungu,
          items:
              _selectedSido != null ? RegionData.getSigungus(_selectedSido!) : [],
          onChanged: (value) {
            setState(() {
              _selectedSigungu = value;
              _selectedDong = null;
            });
          },
        ),
        const SizedBox(height: 8),
        // Dong
        _buildDropdown(
          hint: '읍/면/동 선택',
          value: _selectedDong,
          items: _selectedSido != null && _selectedSigungu != null
              ? RegionData.getDongs(_selectedSido!, _selectedSigungu!)
              : [],
          onChanged: (value) {
            setState(() {
              _selectedDong = value;
            });
            if (_selectedSido != null &&
                _selectedSigungu != null &&
                value != null) {
              widget.onSelected(_selectedSido!, _selectedSigungu!, value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: AppTextStyles.body1.copyWith(color: AppColors.textHint)),
          value: value,
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, style: AppTextStyles.body1),
                  ))
              .toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
