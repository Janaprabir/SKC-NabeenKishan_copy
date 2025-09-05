import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalaryUploadPage extends StatefulWidget {
  const SalaryUploadPage({Key? key}) : super(key: key);

  @override
  _SalaryUploadPageState createState() => _SalaryUploadPageState();
}

class _SalaryUploadPageState extends State<SalaryUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _salaryMonthController = TextEditingController();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  File? _selectedFile;
  bool _isLoading = false;
  String? _fileName;
  String? _empId;

  // Date formats
  final DateFormat _displayFormat = DateFormat('dd/MM/yyyy'); // For UI display
  final DateFormat _apiFormat = DateFormat('yyyy-MM-dd'); // For API submission

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadEmpId();
  }

  Future<void> _loadEmpId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empId = prefs.getString('emp_id');
    });
  }

  Future<void> _selectFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedFile = File(photo.path);
          _fileName = 'salary_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        });
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error capturing photo: $e')),
      // );
      print('Error capturing photo: $e');
    }
  }

  Future<void> _uploadSalary() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file or capture a photo')),
      );
      return;
    }

    if (_empId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee ID not found')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/SalaryUploadsController/insertSalaryUploads.php'),
      );

      // Parse display dates and convert to API format
      DateTime fromDate = _displayFormat.parse(_fromDateController.text);
      DateTime toDate = _displayFormat.parse(_toDateController.text);

      request.fields.addAll({
        'uploaded_by_emp_id': _empId!,
        'salary_month': _salaryMonthController.text,
        'from_date': _apiFormat.format(fromDate), // Send in yyyy-MM-dd
        'to_date': _apiFormat.format(toDate), // Send in yyyy-MM-dd
      });

      request.files.add(
        await http.MultipartFile.fromPath(
          'salary_list_file',
          _selectedFile!.path,
          filename: _fileName,
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salary uploaded successfully')),
        );
        _resetForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $responseData')),
        );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
      print('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedFile = null;
      _fileName = null;
      _salaryMonthController.clear();
      _fromDateController.clear();
      _toDateController.clear();
    });
  }

  Future<void> _selectSalaryMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromRGBO(40, 167, 70, 1),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _salaryMonthController.text = DateFormat('MMMM yyyy').format(picked);
    }
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color.fromRGBO(40, 167, 70, 1),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = _displayFormat.format(picked); // Display as dd/MM/yyyy
    }
  }

  @override
  void dispose() {
    _salaryMonthController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
        title: const Text(
          'Salary Upload',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _salaryMonthController,
                            label: 'Salary Month',
                            icon: Icons.calendar_month,
                            readOnly: true,
                            onTap: () => _selectSalaryMonth(context),
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please select salary month'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _fromDateController,
                            label: 'From Date',
                            icon: Icons.calendar_today,
                            readOnly: true,
                            onTap: () => _selectDate(context, _fromDateController),
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please select from date'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _toDateController,
                            label: 'To Date',
                            icon: Icons.calendar_today,
                            readOnly: true,
                            onTap: () => _selectDate(context, _toDateController),
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Please select to date'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: _selectFile,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color.fromRGBO(40, 167, 70, 1)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.attach_file,
                                        color: Color.fromRGBO(40, 167, 70, 1)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _fileName ?? 'Select Salary File',
                                      style: TextStyle(
                                        color: _fileName != null
                                            ? Colors.black87
                                            : Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(),
                          InkWell(
                            onTap: _capturePhoto,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color.fromRGBO(40, 167, 70, 1)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.camera_alt,
                                        color: Color.fromRGBO(40, 167, 70, 1)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Capture Salary Photo',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _empId == null) ? null : _uploadSalary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Upload Salary',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color.fromRGBO(40, 167, 70, 1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color.fromRGBO(40, 167, 70, 1), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }
}