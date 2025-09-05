import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as excel;
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:shimmer/shimmer.dart';

class ManagerActivityReport extends StatefulWidget {
  const ManagerActivityReport({super.key});

  @override
  _ManagerActivityReportState createState() => _ManagerActivityReportState();
}

class _ManagerActivityReportState extends State<ManagerActivityReport> {
  String? _empId;
  final List<Map<String, dynamic>> _records = [];
  final List<String> _columns = [
    'Activity Date',
    'Status of Work',
    'Camp Name',
    'Camp Nature of Work',
    'Name of SE GC GL',
    'Product Names',
    'Customer Name',
    'Customer Address',
    'Customer Phone No',
    'Result',
    'Order No',
    'Booking Unit',
    'Booking Advance',
    'Office Name',
    'Office Nature of Work',
    'Spot Picture',
    'Location',
    'Remarks',
    'Verification Status',
    'Actions',
  ];
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    _setDefaultDates();
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _loadSessionData().then((_) {
      _fetchData();
    });
  }

  void _setDefaultDates() {
    String today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _fromDateController.text = today;
    _toDateController.text = today;
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

    String fromDate = _fromDateController.text;
    String toDate = _toDateController.text;
    String apiFromDate = DateFormat('yyyy-MM-dd')
        .format(DateFormat('dd/MM/yyyy').parse(fromDate));
    String apiToDate =
        DateFormat('yyyy-MM-dd').format(DateFormat('dd/MM/yyyy').parse(toDate));
    const String baseUrl =
        'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/managerActivityReport.php';

    final Map<String, String> parameters = {
      'emp_id': _empId!,
      'from_date': apiFromDate,
      'to_date': apiToDate,
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _records.clear();
          for (var item in data) {
            final Map<String, dynamic> record = {};
            for (var column in _columns) {
              String key = column.toLowerCase().replaceAll(' ', '_');
              record[column] = item[key] != null ? item[key].toString() : '';
              if (column == 'Activity Date' && item[key] != null) {
                try {
                  DateTime activityDateTime = DateTime.parse(item[key]);
                  record[column] =
                      DateFormat('dd/MM/yyyy hh:mm a').format(activityDateTime);
                } catch (e) {
                  record[column] = item[key];
                }
              }
            }
            record['Latitude'] = item['latitude']?.toString() ?? '';
            record['Longitude'] = item['longitude']?.toString() ?? '';
            record['activity_id'] = item['activity_id']?.toString() ?? '';
            record['Location'] =
                item['location']?.toString() ?? 'Not Available';
            record['submit_date'] = item['submit_date']?.toString() ?? '';
            record['raw_activity_date'] = item['activity_date']?.toString() ??
                ''; // Store raw activity_date
            _records.add(record);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Data Found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch data')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
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
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
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
    if (activityId == null || activityId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Missing activity ID')),
      );
      return;
    }

    const String deleteUrl =
        'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/deleteActivity.php';

    final Map<String, dynamic> parameters = {'activity_id': activityId};
    final Uri uri = Uri.parse(deleteUrl).replace(queryParameters: parameters);
    print('Deleting record with ID: $activityId');
    try {
      final response = await http.delete(uri);
      if (response.statusCode == 200) {
        setState(() {
          _records.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Record deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete record')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete record $e')),
      );
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      Permission permission = Permission.storage;
      if (await Permission.manageExternalStorage.isGranted) {
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
          .value = excel.TextCellValue('Manager Activity Report');
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
        final record = _records[row];
        for (int col = 0; col < headers.length; col++) {
          String column = headers[col];
          String value;

          if (column == 'Location') {
            value = record[column] ?? 'Not Available';
          } else if (column == 'Product Names') {
            final rawValue = record[column];
            if (rawValue == null || rawValue.toString().trim().isEmpty) {
              value = 'N/A';
            } else {
              List<String> products = rawValue
                  .toString()
                  .split(',')
                  .map((product) => product.trim())
                  .where((product) => product.isNotEmpty)
                  .toList();
              value = products.isEmpty ? 'N/A' : products.join('\n');
            }
          } else {
            value = record[column]?.isEmpty ?? true
                ? 'N/A'
                : record[column].toString();
          }

          var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: row + 5));
          cell.value = excel.TextCellValue(value);

          if (column == 'Order No' ||
              column == 'Booking Unit' ||
              column == 'Booking Advance') {
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
          final products =
              record['Product Names'].toString().split('\n').length;
          final productLines = products > 0 ? products : 1;
          sheet.setRowHeight(
              row + 5, 30.0 * (productLines > 5 ? 5 : productLines));
        }
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(
            i, headers[i] == 'Activity Date' ? 25 : headers[i].length * 1.5);
      }

      final outputDirectory = await _getSaveDirectory();
      final fileName =
          'manager_activity_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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
                  'Excel saved to $filePath but couldn’t open: ${openResult.message}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel saved and opened from $filePath')),
        );
      }
    } catch (e) {
      debugPrint('Error generating Excel: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchActivityLogs(
      String activityId, String _empId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/fetchActivityLogsByEmp.php?activity_id=$activityId&emp_id=$_empId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _showLogsPopup(data);
        return data.cast<Map<String, dynamic>>();
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        throw Exception('Failed to fetch activity logs');
      }
    } catch (e) {
      return [];
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
                const Text(
                  'Activity Logs',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(40, 167, 70, 1)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: logs.map((log) {
                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLogRow(
                                  icon: Icons.calendar_today,
                                  label: 'Log Date Time',
                                  value: _formatDateTime(log['log_date_time']),
                                ),
                                const SizedBox(height: 8),
                                _buildLogRow(
                                  icon: Icons.verified_user,
                                  label: 'Verification Status',
                                  value: log['verification_status'] ?? 'N/A',
                                ),
                                const SizedBox(height: 8),
                                _buildLogRow(
                                  icon: Icons.person,
                                  label: 'Checked By',
                                  value: log['activity_checked_by'] ?? 'N/A',
                                ),
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

  void _showImagePopup(String imageUrl) {
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
                            'https://www.nabeenkishan.net.in/manager_activity_spot_image/$imageUrl',
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

  Widget _buildLogRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color.fromRGBO(40, 167, 70, 1)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getVerificationStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'incorrect':
        return Colors.red;
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.transparent;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter Records'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fromDateController,
                  decoration: const InputDecoration(
                    labelText: 'From Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () => _selectDate(context, _fromDateController),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _toDateController,
                  decoration: const InputDecoration(
                    labelText: 'To Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  readOnly: true,
                  onTap: () => _selectDate(context, _toDateController),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                backgroundColor: const Color(0xFF28A746),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _fetchData();
              },
              child: const Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // bool _canShowDeleteButton(String activityDate) {
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
  bool _canShowDeleteButton(String activityDate) {
    if (activityDate.isEmpty) return false;
    try {
      DateTime parsedActivityDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').parse(activityDate, true).toLocal();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF28A746),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]).then((_) {
              Navigator.pop(context);
            });
          },
        ),
        title: const Text(
          'Activity Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.white),
            tooltip: 'Download Excel',
            onPressed: _downloadExcel,
          ),
          SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28A746)))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_records.length} records found",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'From Date: ${_fromDateController.text}  |  To Date: ${_toDateController.text}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              MaterialStateProperty.all(Colors.green[600]),
                          headingTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          headingRowHeight: 50,
                          dataRowMinHeight: 50,
                          dataRowMaxHeight: double.infinity,
                          columns: _columns
                              .map((column) => DataColumn(label: Text(column)))
                              .toList(),
                          rows: _records.map((record) {
                            final index = _records.indexOf(record);
                            final activityDate =
                                record['raw_activity_date'] ?? '';

                            return DataRow(
                              cells: _columns.map((column) {
                                if (column == 'Location') {
                                  return DataCell(
                                    Text(
                                      record[column]?.isEmpty ?? true
                                          ? '__'
                                          : record[column]!,
                                    ),
                                  );
                                }
                                if (column == 'Verification Status') {
                                  final status = record[column]?.isEmpty ?? true
                                      ? '__'
                                      : record[column]!;
                                  return DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            _getVerificationStatusColor(status),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  );
                                }
                                if (column == 'Spot Picture') {
                                  final imageUrl =
                                      record[column]?.isEmpty ?? true
                                          ? 'N/A'
                                          : record[column]!;
                                  return DataCell(
                                    GestureDetector(
                                      onTap: () => _showImagePopup(imageUrl),
                                      child: Text(
                                        imageUrl == 'N/A'
                                            ? 'No Image'
                                            : 'View Image',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                if (column == 'Product Names') {
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
                                        .where((product) => product.isNotEmpty)
                                        .toList();
                                    if (products.isEmpty) products = ['__'];
                                  }
                                  return DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: products
                                              .map((product) => Text(
                                                    product,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return DataCell(
                                  column == 'Actions'
                                      ? Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.list,
                                                  color: Colors.blue),
                                              onPressed: () =>
                                                  fetchActivityLogs(
                                                      record['activity_id'],
                                                      _empId!),
                                            ),
                                            if (_canShowDeleteButton(activityDate))
                                              IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _confirmDelete(index),
                                              ),
                                          ],
                                        )
                                      : Text(
                                          record[column]?.isEmpty ?? true
                                              ? '__'
                                              : record[column]!,
                                        ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
