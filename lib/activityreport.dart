
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:excel/excel.dart' as excel;
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
class ActivityReport extends StatefulWidget {
  const ActivityReport({super.key});

  @override
  _ActivityReportState createState() => _ActivityReportState();
}

class _ActivityReportState extends State<ActivityReport> {
  String? _empId;
  bool _isLoading = false;
  final Map<String, bool> _locationLoadingStates = {};

  final List<Map<String, dynamic>> _records = [];
  final List<String> _columns = [
    'Activity Date',
    'Nature of Work',
    'Product Names',
    'Customer Name',
    'Customer Address',
    'Customer Phone No',
    'Result',
    'Order No',
    'Order Unit',
    'Booking Advance',
    'Remarks',
    'Location Name',
    'Office Name',
    'Total Customer',
    'Collection Amount',
    'Delivery Unit',
    'Spot Picture',
    'Verification Status',
    'Actions',
  ];

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _fromDateController.text = DateFormat('dd/MM/yyyy').format(_fromDate);
    _toDateController.text = DateFormat('dd/MM/yyyy').format(_toDate);

    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _loadSessionData().then((_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empId = prefs.getString('emp_id');
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    if (_empId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee ID not found in session')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    const String baseUrl =
        'https://www.nabeenkishan.net.in/newproject/api/routes/ActivityController/activityReport.php';

    try {
      final Map<String, String> parameters = {
        'emp_id': _empId!,
        'from_date': DateFormat('yyyy-MM-dd').format(_fromDate),
        'to_date': DateFormat('yyyy-MM-dd').format(_toDate),
      };

      final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);
      print('API Request: $uri');
      final response = await http.get(uri);
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (responseBody.containsKey('data') && responseBody['data'].isNotEmpty) {
          final List<dynamic> data = responseBody['data'];
          print('API Response Data: $data');

          setState(() {
            _records.clear();
            for (var item in data) {
              final Map<String, dynamic> record = {};
              for (var column in _columns) {
                String key = column.toLowerCase().replaceAll(' ', '_');
                if (key == 'activity_date' && item[key] != null) {
                  try {
                    DateTime parsedDate = DateTime.parse(item[key]);
                    record[column] = DateFormat('dd/MM/yyyy hh:mm a').format(parsedDate);
                  } catch (e) {
                    record[column] = item[key]?.toString() ?? '';
                  }
                } else if ((key == 'time_from' || key == 'time_to') &&
                    item[key] != null) {
                  DateTime parsedTime =
                      DateTime.parse("1970-01-01 ${item[key]}");
                  record[column] = DateFormat('hh:mm a').format(parsedTime);
                } else {
                  record[column] =
                      item[key] != null ? item[key].toString() : '';
                }
              }
              record['latitude'] = item['latitude']?.toString();
              record['longitude'] = item['longitude']?.toString();
              record['activity_id'] = item['activity_id']?.toString() ?? '';
              record['Location Name'] =
                  item['location']?.toString() ?? 'Unknown Location';
              record['submit_date'] = item['submit_date']?.toString() ?? '';
              record['raw_activity_date'] = item['activity_date']?.toString() ?? ''; // Store raw activity_date
              _records.add(record);
            }
          });
        } else {
          setState(() {
            _records.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No records found for ${_fromDateController.text} to ${_toDateController.text}',
              ),
              action: SnackBarAction(
                label: 'Show Today',
                onPressed: () {
                  setState(() {
                    _fromDate = DateTime.now();
                    _toDate = DateTime.now();
                    _fromDateController.text =
                        DateFormat('dd/MM/yyyy').format(_fromDate);
                    _toDateController.text =
                        DateFormat('dd/MM/yyyy').format(_toDate);
                  });
                  _fetchData();
                },
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data found')),
        );
      }
    } catch (e) {
      print('Failed to fetch data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _selectDate(BuildContext context,
      TextEditingController controller, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          _fromDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          _toDate = picked;
          _toDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        }
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
          _toDateController.text = DateFormat('dd/MM/yyyy').format(_toDate);
        }
      });
    }
  }

  Future<void> _confirmDelete(int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this record?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deleteRecord(index);
    }
  }

  Future<void> _deleteRecord(int index) async {
    final activityId = _records[index]['activity_id'];
    if (_empId == null || activityId == null || activityId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error: Missing employee ID or activity ID')),
      );
      return;
    }

    const String deleteUrl =
        'https://www.nabeenkishan.net.in/newproject/api/routes/ActivityController/deleteActivity.php';

    final Map<String, dynamic> parameters = {
      'emp_id': _empId!,
      'activity_id': activityId,
    };
    final Uri uri = Uri.parse(deleteUrl).replace(queryParameters: parameters);
    try {
      final response = await http.delete(uri);
      final responseBody = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _records.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to delete record: ${responseBody['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete record')),
      );
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      Permission permission = Permission.storage;
      if (await Permission.manageExternalStorage.request().isGranted) {
        permission = Permission.manageExternalStorage;
      }

      var status = await permission.status;
      if (!status.isGranted) {
        status = await permission.request();
        if (status.isDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
          return false;
        } else if (status.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Storage permission permanently denied. Please enable it in settings.'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () async {
                  await openAppSettings();
                },
              ),
            ),
          );
          return false;
        }
      }
      return status.isGranted;
    }
    return true;
  }

  Future<Directory> _getSaveDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      if (await _requestStoragePermission()) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Downloads folder unavailable, using alternative directory')),
          );
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Permission denied, saving to app directory')),
        );
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return directory;
  }

  Future<void> _downloadExcel() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No activity data to export')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var excelWorkbook = excel.Excel.createExcel();
      var sheet = excelWorkbook['Sheet1'];

      var headerStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );

      var numberStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Right,
        verticalAlign: excel.VerticalAlign.Center,
      );

      var centerStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );

      var textStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
        verticalAlign: excel.VerticalAlign.Center,
      );

      var productNameStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
        verticalAlign: excel.VerticalAlign.Top,
      );

      sheet.merge(
          excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          excel.CellIndex.indexByColumnRow(
              columnIndex: _columns.length - 2, rowIndex: 0));
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = excel.TextCellValue('Activity Report');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle = excel.CellStyle(
        bold: true,
        fontSize: 18,
        horizontalAlign: excel.HorizontalAlign.Center,
      );

      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          .value = excel.TextCellValue('From Date: ${_fromDateController.text}');

      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
          .value = excel.TextCellValue('To Date: ${_toDateController.text}');

      final headers = _columns.where((column) => column != 'Actions').toList();

      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4));
        cell.value = excel.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      for (int row = 0; row < _records.length; row++) {
        var record = _records[row];

        for (int col = 0; col < headers.length; col++) {
          String column = headers[col];
          dynamic value;

          if (column == 'Spot Picture') {
            value = record[column]?.isEmpty ?? true
                ? 'No Image'
                : 'https://www.nabeenkishan.net.in/activity_spot_image/${record[column]}';
          } else if (column == 'Product Names') {
            if (record[column] is List) {
              value = (record[column] as List)
                  .where((p) => p != null && p.toString().trim().isNotEmpty)
                  .join('\n');
            } else if (record[column] is String) {
              value = (record[column] as String)
                  .split(',')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty)
                  .join('\n');
            } else {
              value = 'N/A';
            }
          } else if (column == 'Customer Name' ||
              column == 'Customer Address') {
            value = (record[column]?.toString() ?? 'N/A')
                .replaceAll('\n', ' ')
                .trim();
          } else if (column == 'Nature of Work') {
            value = (record[column]?.toString() ?? 'N/A').toUpperCase();
          } else {
            value = record[column]?.toString() ?? 'N/A';
          }

          var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: row + 5));
          cell.value = excel.TextCellValue(value.toString());

          if (column == 'Order No' ||
              column == 'Order Unit' ||
              column == 'Booking Advance' ||
              column == 'Total Customer' ||
              column == 'Collection Amount' ||
              column == 'Delivery Unit') {
            cell.cellStyle = numberStyle;
          } else if (column == 'Customer Phone No') {
            cell.cellStyle = centerStyle;
          } else if (column == 'Product Names') {
            cell.cellStyle = productNameStyle;
          } else {
            cell.cellStyle = textStyle;
          }
        }

        if (record['Product Names'] != null) {
          final products = record['Product Names'] is List
              ? (record['Product Names'] as List).length
              : record['Product Names'].toString().split('\n').length;
          final productLines = products > 0 ? products : 1;
          sheet.setRowHeight(
              row + 5, 20.0 * (productLines > 5 ? 5 : productLines));
        }
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(
            i, headers[i] == 'Activity Date' ? 25 : headers[i].length * 1.5);
      }

      final outputDirectory = await _getSaveDirectory();
      final fileName =
          'activity_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${outputDirectory.path}/$fileName';
      final file = File(filePath);
      await file.create(recursive: true);
      final excelBytes = excelWorkbook.encode();

      if (excelBytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      await file.writeAsBytes(excelBytes);

      final openResult = await OpenFile.open(filePath);
      if (openResult.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Excel saved but couldn\'t open: ${openResult.message}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel report generated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating Excel: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl:
                            'https://www.nabeenkishan.net.in/activity_spot_image/$imagePath',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text('Loading...',
                                  style: TextStyle(
                                      color: Colors.black, fontSize: 16)),
                            ],
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image,
                              size: 50, color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _verificationStatusWidget(String? status) {
    String displayText;
    Color displayColor;

    if (status == 'verified') {
      displayText = 'Verified';
      displayColor = const Color.fromRGBO(40, 167, 70, 1);
    } else if (status == 'incorrect') {
      displayText = 'Incorrect';
      displayColor = Colors.red;
    } else {
      displayText = 'Pending';
      displayColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: displayColor, borderRadius: BorderRadius.circular(4)),
      child: Text(displayText, style: const TextStyle(color: Colors.white)),
    );
  }

  Future<void> _showActivityLogs(String activityId) async {
    setState(() {
      _isLoading = true;
    });

    const String fetchLogsUrl =
        'https://www.nabeenkishan.net.in/newproject/api/routes/ActivityController/fetchActivityLogs.php';

    final Map<String, String> parameters = {'activity_id': activityId};
    final uri = Uri.parse(fetchLogsUrl).replace(queryParameters: parameters);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _showLogsPopup(data);
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Message'),
              content: const Text(
                  'Failed to fetch activity logs because your Verification Status is Pending.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch activity logs')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return 'N/A';
    }

    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
    } catch (e) {
      print('Error formatting date-time: $e');
      return 'Invalid Date';
    }
  }

  void _showLogsPopup(List<dynamic> logs) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Activity Logs',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(40, 167, 70, 1))),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: logs.map((log) {
                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLogRow(
                                    icon: Icons.calendar_today,
                                    label: 'Log Date Time',
                                    value:
                                        _formatDateTime(log['log_date_time'])),
                                const SizedBox(height: 8),
                                _buildLogRow(
                                    icon: Icons.verified_user,
                                    label: 'Verification Status',
                                    value: log['verification_status'] ?? 'N/A'),
                                const SizedBox(height: 8),
                                _buildLogRow(
                                    icon: Icons.person,
                                    label: 'Checked By',
                                    value: log['activity_checked_by'] ?? 'N/A'),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogRow(
      {required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color.fromRGBO(40, 167, 70, 1)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double screenHeight = MediaQuery.of(context).size.height;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: screenWidth * 0.4,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter Activities',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02),
                SizedBox(
                  width: screenWidth * 0.35,
                  height: screenHeight * 0.1,
                  child: TextFormField(
                    controller: _fromDateController,
                    decoration: InputDecoration(
                      labelText: 'From Date',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      suffixIcon: const Icon(Icons.calendar_today,
                          color: Color(0xFF28A746)),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                    ),
                    readOnly: true,
                    onTap: () =>
                        _selectDate(context, _fromDateController, true),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                SizedBox(
                  width: screenWidth * 0.35,
                  height: screenHeight * 0.1,
                  child: TextFormField(
                    controller: _toDateController,
                    decoration: InputDecoration(
                      labelText: 'To Date',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      suffixIcon: const Icon(Icons.calendar_today,
                          color: Color(0xFF28A746)),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                    ),
                    readOnly: true,
                    onTap: () => _selectDate(context, _toDateController, false),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.red))),
                    SizedBox(width: screenWidth * 0.02),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.03,
                            vertical: screenHeight * 0.015),
                        backgroundColor: const Color(0xFF28A746),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_fromDate.isAfter(_toDate)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'From Date cannot be after To Date')),
                          );
                          return;
                        }
                        _fetchData();
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Filter',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSummaryPopup() {
    Map<String, Map<String, dynamic>> summary = {
      'DEMO': {
        'total': 0,
        'verified': 0,
        'days': <String>{},
        'collection_amount': 0.0
      },
      'DELIVERY & COLLECTION': {
        'total': 0,
        'verified': 0,
        'days': <String>{},
        'collection_amount': 0.0
      },
      'SUBMISSION': {
        'total': 0,
        'verified': 0,
        'days': <String>{},
        'collection_amount': 0.0
      },
      'MEETING': {
        'total': 0,
        'verified': 0,
        'days': <String>{},
        'collection_amount': 0.0
      },
      'LEAVE': {
        'total': 0,
        'verified': 0,
        'days': <String>{},
        'collection_amount': 0.0
      },
      'OTHERS': {
        'total': 0,
        'verified': 0,
        'days': <String>{},
        'collection_amount': 0.0
      },
    };

    for (var record in _records) {
      String natureOfWork = record['Nature of Work']?.toUpperCase() ?? 'OTHERS';
      String verificationStatus =
          record['Verification Status']?.toLowerCase() ?? '';
      String activityDate = record['Activity Date'] ?? '';
      String activityDateOnly = '';
      if (activityDate.isNotEmpty) {
        try {
          DateTime parsedDate =
              DateFormat('dd/MM/yyyy hh:mm a').parse(activityDate);
          activityDateOnly = DateFormat('dd/MM/yyyy').format(parsedDate);
        } catch (e) {
          activityDateOnly = activityDate;
        }
      }
      double collectionAmount = 0.0;

      if (record['Collection Amount'] != null &&
          record['Collection Amount'].toString().isNotEmpty) {
        try {
          collectionAmount = double.parse(
              record['Collection Amount'].toString().replaceAll(',', ''));
        } catch (e) {
          print('Error parsing collection amount: $e');
          collectionAmount = 0.0;
        }
      }

      String key = natureOfWork.contains('DEMO')
          ? 'DEMO'
          : natureOfWork.contains('DELIVERY') ||
                  natureOfWork.contains('COLLECTION')
              ? 'DELIVERY & COLLECTION'
              : natureOfWork.contains('SUBMISSION')
                  ? 'SUBMISSION'
                  : natureOfWork.contains('MEETING')
                      ? 'MEETING'
                      : natureOfWork.contains('LEAVE')
                          ? 'LEAVE'
                          : 'OTHERS';

      summary[key]!['total'] = (summary[key]!['total'] as int) + 1;
      if (verificationStatus == 'verified') {
        summary[key]!['verified'] = (summary[key]!['verified'] as int) + 1;
      }
      if (activityDateOnly.isNotEmpty) {
        summary[key]!['days'].add(activityDateOnly);
      }
      summary[key]!['collection_amount'] =
          (summary[key]!['collection_amount'] as double) + collectionAmount;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF28A746),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    child: Table(
                      border: TableBorder.all(color: Colors.grey),
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1.5),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.blue[800]),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Result',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Total',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Verified Total',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Total Days',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Collection Amount',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        ...summary.entries
                            .map((entry) => _buildSummaryRow(
                                  entry.key,
                                  entry.value['total'] as int,
                                  entry.value['verified'] as int,
                                  entry.value['days'].length,
                                  entry.value['collection_amount'] as double,
                                ))
                            .toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close',
                          style: TextStyle(color: Color(0xFF28A746))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TableRow _buildSummaryRow(String title, int total, int verified, int days,
      double collectionAmount) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            total.toString(),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            verified.toString(),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            days.toString(),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            NumberFormat.currency(symbol: '₹', decimalDigits: 2)
                .format(collectionAmount),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
  bool _canShowDeleteButton(String activityDate) {
    if (activityDate.isEmpty) return false;
    try {
      DateTime parsedActivityDate = DateTime.parse(activityDate).toLocal();
      DateTime now = DateTime.now();
      // Only allow delete if the activity date is today
      return parsedActivityDate.year == now.year &&
          parsedActivityDate.month == now.month &&
          parsedActivityDate.day == now.day;
    } catch (e) {
      print('Error parsing activity date: $e');
      return false;
    }
  }
  //   bool _canShowDeleteButton(String activityDate) {
  //   if (activityDate.isEmpty) return false;
  //   try {
  //     DateTime parsedActivityDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(activityDate, true).toLocal();
  //     DateTime now = DateTime.now();
  //     print('Parsed Activity Date: $parsedActivityDate, Now: $now, Days Difference: ${now.difference(parsedActivityDate).inDays}');
  //     return now.difference(parsedActivityDate).inDays <= 7;
  //   } catch (e) {
  //     print('Error parsing activity date: $e');
  //     return false;
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF28A746),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]).then((_) {
              Navigator.pop(context);
            });
          },
        ),
        title: const Text('Activity Report',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.white),
            onPressed: _downloadExcel,
            tooltip: 'Download Excel',
          ),
          SizedBox(width: screenWidth * 0.01),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(screenWidth * 0.017),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'From Date: ${_fromDateController.text}  |  To Date: ${_toDateController.text}',
                        style: TextStyle(
                            fontSize: screenWidth * 0.015,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.summarize,
                            size: 20, color: Color(0xFF28A746)),
                        label: const Text('View Summary',
                            style: TextStyle(color: Color(0xFF28A746))),
                        onPressed: _showSummaryPopup,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Expanded(
                    child: Center(
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: screenHeight * 0.1,
                              dataRowMinHeight: 50,
                              dataRowMaxHeight: double.infinity,
                              headingRowColor: MaterialStateProperty.all(
                                  const Color(0xFF28A746).withOpacity(0.9)),
                              headingTextStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: screenWidth * 0.014),
                              dataRowColor:
                                  MaterialStateProperty.all(Colors.white),
                              border: TableBorder.all(
                                  color: Colors.grey[300]!,
                                  borderRadius: BorderRadius.circular(2)),
                              columns: _columns
                                  .map((column) => DataColumn(
                                      label: Center(
                                          child: Text(column,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize:
                                                      screenWidth * 0.015)))))
                                  .toList(),
                              rows: _records.map((record) {
                                final index = _records.indexOf(record);
                                String activityId = record['activity_id'];
                                String activityDate = record['raw_activity_date'] ?? '';

                                return DataRow(
                                  cells: _columns.map((column) {
                                    String value = (record[column] == null ||
                                            record[column]!
                                                .toString()
                                                .trim()
                                                .isEmpty)
                                        ? '__'
                                        : record[column].toString();

                                    if (column == 'Spot Picture') {
                                      String? imagePath = record[column];
                                      if (imagePath == null ||
                                          imagePath.isEmpty) {
                                        return const DataCell(
                                            Center(child: Text('__')));
                                      }
                                      return DataCell(Center(
                                          child: TextButton(
                                              onPressed: () =>
                                                  _showImageDialog(imagePath),
                                              child: const Text('View Image',
                                                  style: TextStyle(
                                                      color:
                                                          Color(0xFF28A746))))));
                                    } else if (column ==
                                        'Verification Status') {
                                      return DataCell(Center(
                                          child: _verificationStatusWidget(
                                              record[column])));
                                    } else if (column == 'Location Name') {
                                      return DataCell(
                                          Center(child: Text(value)));
                                    } else if (column == 'Actions') {
                                      return DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                                icon: const Icon(Icons.list,
                                                    color: Color(0xFF28A746)),
                                                onPressed: () =>
                                                    _showActivityLogs(
                                                        record['activity_id'])),
                                            if (_canShowDeleteButton(activityDate))
                                              IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      color: Colors.red),
                                                  onPressed: () =>
                                                      _confirmDelete(index)),
                                          ],
                                        ),
                                      );
                                    } else if (column == 'Product Names') {
                                      final rawValue = record[column];
                                      List<String> products;
                                      if (rawValue == null ||
                                          rawValue.toString().trim().isEmpty) {
                                        products = ['__'];
                                      } else {
                                        products = rawValue
                                            .toString()
                                            .split(',')
                                            .map((product) => product.trim())
                                            .where((product) =>
                                                product.isNotEmpty)
                                            .toList();
                                        if (products.isEmpty)
                                          products = [rawValue.toString()];
                                      }
                                      return DataCell(
                                        Container(
                                          width: screenWidth * 0.2,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: products
                                                .map((product) => Text(
                                                      product,
                                                      textAlign: TextAlign.center,
                                                    ))
                                                .toList(),
                                          ),
                                        ),
                                      );
                                    }
                                    return DataCell(Center(
                                        child: Text(value,
                                            style: TextStyle(
                                                fontSize:
                                                    screenWidth * 0.013))));
                                  }).toList(),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF28A746))),
              ),
          ],
        ),
      ),
    );
  }
}
