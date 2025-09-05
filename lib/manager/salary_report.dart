import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class SalaryReportPage extends StatefulWidget {
  const SalaryReportPage({Key? key}) : super(key: key);

  @override
  _SalaryReportPageState createState() => _SalaryReportPageState();
}

class _SalaryReportPageState extends State<SalaryReportPage> {
  String? _empId;
  List<dynamic>? _salaryData;
  bool _isLoading = true;
  bool _hasStoragePermission = false;

  static const String _baseFileUrl = 'https://www.nabeenkishan.net.in/salary_uploads/';

  @override
  void initState() {
    super.initState();
    _loadEmpIdAndFetchData();
    _checkStoragePermission();
  }

  Future<void> _checkStoragePermission() async {
    final prefs = await SharedPreferences.getInstance();
    _hasStoragePermission = prefs.getBool('storage_permission_granted') ?? false;

    if (!_hasStoragePermission) {
      PermissionStatus status;
      if (Platform.isAndroid && await _isAndroid11OrHigher()) {
        status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
        }
      } else {
        status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      }

      if (status.isGranted) {
        _hasStoragePermission = true;
        await prefs.setBool('storage_permission_granted', true);
      } else if (status.isPermanentlyDenied) {
        _hasStoragePermission = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable storage permission in app settings.'),
          ),
        );
        await openAppSettings();
      } else if (status.isDenied) {
        _hasStoragePermission = false;
      }
    }
  }

  Future<bool> _isAndroid11OrHigher() async {
    if (Platform.isAndroid) {
      var version = await DeviceInfoPlugin().androidInfo;
      return version.version.sdkInt >= 30; // Android 11 (API 30)
    }
    return false;
  }

  Future<void> _loadEmpIdAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empId = prefs.getString('emp_id');
    });
    if (_empId != null) {
      await _fetchSalaryData();
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee ID not found')),
      );
    }
  }

  Future<void> _fetchSalaryData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/SalaryUploadsController/getSalaryUploads.php?uploaded_by_emp_id=$_empId',
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          setState(() {
            _salaryData = jsonData['data'];
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No data found')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSalaryRecord(int uploadId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/SalaryUploadsController/deleteSalaryUploads.php?upload_id=$uploadId',
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Record deleted successfully')),
          );
          await _fetchSalaryData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${jsonData['message'] ?? 'Unknown error'}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _confirmDelete(int uploadId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this salary record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSalaryRecord(uploadId);
    }
  }

  Future<void> _downloadAndOpenFile(String fileName) async {
    try {
      if (!_hasStoragePermission) {
        await _checkStoragePermission();
        if (!_hasStoragePermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required to download files')),
          );
          return;
        }
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final fileUrl = '$_baseFileUrl$fileName';
      final response = await http.get(Uri.parse(fileUrl));

      if (response.statusCode == 200) {
        // Use a safer directory for downloads
        final directory = await getApplicationDocumentsDirectory(); // For broader compatibility
        final downloadDirectory = Directory('${directory.path}/Download');
        if (!await downloadDirectory.exists()) {
          await downloadDirectory.create(recursive: true);
        }

        final filePath = '${downloadDirectory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        Navigator.of(context).pop();
        await OpenFile.open(filePath);
      } else {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download file: ${response.statusCode}')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: ${e.toString()}')),
      );
    }
  }

  String _formatDateTime(String dateTime) {
    try {
      final parsedDate = DateTime.parse(dateTime);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      return dateTime;
    }
  }

  String _formatDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return DateFormat('dd/MM/yyyy').format(parsedDate);
    } catch (e) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
         leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
        title: const Text(
          'Salary Report',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_empId == null)
                const Center(child: CircularProgressIndicator())
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                 
                ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _salaryData == null || _salaryData!.isEmpty
                        ? const Center(
                            child: Text(
                              'No salary uploads found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _salaryData!.length,
                            itemBuilder: (context, index) {
                              final item = _salaryData![index];
                              return _buildSalaryCard(item);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryCard(dynamic item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['salary_month'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(40, 167, 70, 1),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '#${item['upload_id']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(item['upload_id']),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'From Date', _formatDate(item['from_date'])),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'To Date', _formatDate(item['to_date'])),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 20, color: Color.fromRGBO(40, 167, 70, 1)),
                const SizedBox(width: 8),
                Text(
                  'File: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _downloadAndOpenFile(item['salary_list_file']),
                    child: Text(
                      item['salary_list_file'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: Color.fromRGBO(40, 167, 70, 1)),
                  onPressed: () => _downloadAndOpenFile(item['salary_list_file']),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uploaded:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  _formatDateTime(item['uploaded_date']),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color.fromRGBO(40, 167, 70, 1)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}