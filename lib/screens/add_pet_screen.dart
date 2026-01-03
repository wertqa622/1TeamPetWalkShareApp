import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/pet.dart';
import '../services/firestore_service.dart';

class AddPetScreen extends StatefulWidget {
  final String userId;
  final Pet? pet; // 수정 모드일 때 기존 Pet 데이터

  const AddPetScreen({
    super.key,
    required this.userId,
    this.pet,
  });

  @override
  State<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends State<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _imagePicker = ImagePicker();

  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isNeutered = false;
  bool _isLoading = false;
  XFile? _selectedImage;
  String? _existingImageUrl; // 기존 이미지 URL 저장

  bool get _isEditMode => widget.pet != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode && widget.pet != null) {
      final pet = widget.pet!;
      _nameController.text = pet.name;
      _breedController.text = pet.breed;
      _weightController.text = pet.weight?.toString() ?? '';
      _selectedDate = pet.dateOfBirth;
      _selectedGender = pet.gender;
      _isNeutered = pet.isNeutered;
      _existingImageUrl = pet.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 선택 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('갤러리에서 선택'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('카메라로 촬영'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              if (_selectedImage != null || (_isEditMode && _existingImageUrl != null))
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('이미지 제거', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      if (_isEditMode) {
                        _existingImageUrl = null;
                      }
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    // rootNavigator를 사용하여 MaterialApp의 Localizations에 접근
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
      useRootNavigator: true,
      builder: (BuildContext dialogContext, Widget? child) {
        return Theme(
          data: Theme.of(dialogContext).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  int _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생년월일을 선택해주세요.')),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final age = _calculateAge(_selectedDate);
      final weight = _weightController.text.isNotEmpty
          ? double.tryParse(_weightController.text)
          : null;

      // TODO: 이미지를 Firebase Storage에 업로드하고 URL을 가져오는 로직 추가
      // 현재는 이미지 파일 경로만 저장 (추후 Firebase Storage 업로드 구현 필요)
      String? imageUrl;
      if (_selectedImage != null) {
        // 새 이미지가 선택된 경우
        imageUrl = _selectedImage!.path;
        // TODO: Firebase Storage 업로드
        // imageUrl = await FirebaseStorageService.uploadImage(_selectedImage!);
      } else if (_isEditMode) {
        // 수정 모드이고 이미지가 변경되지 않은 경우 기존 이미지 URL 유지
        imageUrl = _existingImageUrl;
      }

      if (_isEditMode && widget.pet != null) {
        // 수정 모드
        final updateData = {
          'name': _nameController.text.trim(),
          'breed': _breedController.text.trim(),
          'age': age,
          'imageUrl': imageUrl,
          'dateOfBirth': _selectedDate?.toIso8601String(),
          'gender': _selectedGender,
          'weight': weight,
          'isNeutered': _isNeutered,
        };

        await FirestoreService.updatePet(widget.pet!.id, updateData);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('반려동물 정보가 수정되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 추가 모드
        final pet = Pet(
          id: '', // FirestoreService에서 자동 생성
          userId: widget.userId,
          name: _nameController.text.trim(),
          species: '강아지', // 기본값, 추후 수정 가능
          breed: _breedController.text.trim(),
          age: age,
          imageUrl: imageUrl,
          createdAt: DateTime.now().toIso8601String(),
          dateOfBirth: _selectedDate,
          gender: _selectedGender,
          weight: weight,
          isNeutered: _isNeutered,
        );

        await FirestoreService.addPet(pet);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('반려동물이 등록되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '수정 실패: $e' : '등록 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.viewInsets.bottom;

    return Container(
      height: mediaQuery.size.height * 0.95,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    _isEditMode ? '반려동물 수정' : '반려동물 등록',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // 닫기 버튼과 균형 맞추기
              ],
            ),
          ),
          // 본문
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: bottomPadding + 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이름 필드
                    _buildTextField(
                      label: '이름 *',
                      controller: _nameController,
                      hintText: '반려동물 이름을 입력하세요',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '이름을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 품종 필드
                    _buildTextField(
                      label: '품종',
                      controller: _breedController,
                      hintText: '품종을 입력하세요',
                    ),
                    const SizedBox(height: 16),

                    // 생년월일 필드
                    _buildDateField(),
                    const SizedBox(height: 16),

                    // 성별 필드
                    _buildGenderField(),
                    const SizedBox(height: 16),

                    // 몸무게 필드
                    _buildTextField(
                      label: '몸무게 (kg)',
                      controller: _weightController,
                      hintText: '몸무게를 입력하세요',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final weight = double.tryParse(value);
                          if (weight == null || weight <= 0) {
                            return '올바른 몸무게를 입력해주세요';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 중성화 여부 필드
                    _buildNeuteredField(),
                    const SizedBox(height: 16),

                    // 프로필 사진 선택 필드
                    _buildImagePickerField(),
                    const SizedBox(height: 16),

                    // 이미지 미리보기
                    if (_selectedImage != null)
                      _buildImagePreview(_selectedImage!.path)
                    else if (_isEditMode && _existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                      _buildImagePreview(_existingImageUrl!),

                    const SizedBox(height: 32),

                    // 등록하기/수정하기 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          _isEditMode ? '수정하기' : '등록하기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '생년월일',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                        : '생년월일을 선택하세요',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? Colors.black87
                          : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '성별',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              isExpanded: true,
              hint: Text(
                '성별을 선택하세요',
                style: TextStyle(color: Colors.grey[600]),
              ),
              items: const [
                DropdownMenuItem(
                  value: '수컷',
                  child: Text('수컷'),
                ),
                DropdownMenuItem(
                  value: '암컷',
                  child: Text('암컷'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNeuteredField() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '중성화 여부',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Switch(
          value: _isNeutered,
          onChanged: (value) {
            setState(() {
              _isNeutered = value;
            });
          },
          activeColor: const Color(0xFF2563EB),
        ),
      ],
    );
  }

  Widget _buildImagePickerField() {
    final hasImage = _selectedImage != null || (_isEditMode && _existingImageUrl != null && _existingImageUrl!.isNotEmpty);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '프로필 사진',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showImageSourceDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  hasImage ? Icons.check_circle : Icons.add_photo_alternate,
                  color: hasImage ? Colors.green : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasImage
                        ? '이미지가 선택되었습니다'
                        : '이미지를 선택하세요',
                    style: TextStyle(
                      color: hasImage
                          ? Colors.black87
                          : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(String imagePath) {
    final bool isNetworkImage = imagePath.startsWith('http');
    final bool isLocalFile = !isNetworkImage && imagePath.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isNetworkImage
                ? Image.network(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  )
                : isLocalFile
                    ? Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}
