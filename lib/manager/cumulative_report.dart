import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as excel;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class Employee {
  final String empId;
  final String eCode;
  final String firstName;
  final String middleName;
  final String lastName;
  final String shortDesignation;
  final String designationCategory;

  Employee({
    required this.empId,
    required this.eCode,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.shortDesignation,
    required this.designationCategory,
  });

  @override
  String toString() {
    return '$eCode - $firstName $middleName $lastName - $designationCategory';
  }
}

class CumulativeReportPage extends StatefulWidget {
  final String selectedEmpId;
  final String selectedEmpName;
  final String fromDate;
  final String toDate;
  final String returnOrientation; // New parameter

  const CumulativeReportPage({
    required this.selectedEmpId,
    required this.selectedEmpName,
    required this.fromDate,
    required this.toDate,
    this.returnOrientation = 'portrait', // Default to portrait
    Key? key,
  }) : super(key: key);

  @override
  _CumulativeReportPageState createState() => _CumulativeReportPageState();
}

class _CumulativeReportPageState extends State<CumulativeReportPage> {
  List<Employee> employees = [];
  List<dynamic> reportData = [];
  String? selectedEmpId;
  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  bool isLoading = false;
  bool isEmployeeLoading = true;
  bool isVerifying = false;
  String? sessionEmpId;
  Map<String, Map<String, dynamic>> employeeDetailsCache = {};
  Map<String, List<dynamic>> logsCache = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
     if (widget.selectedEmpId != null) {
      selectedEmpId = widget.selectedEmpId;
    }
    selectedEmpId = widget.selectedEmpId;
    fromDateController.text = widget.fromDate;
    toDateController.text = widget.toDate;
    _loadSessionEmpId();
  }

  @override
  void dispose() {
    fromDateController.dispose();
    toDateController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionEmpId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      sessionEmpId = prefs.getString('emp_id');
    });
    if (sessionEmpId != null) {
      await fetchEmployeeDetails(sessionEmpId!);
      await fetchEmployees();
      await fetchCumulativeReport();
      setState(() {
        isEmployeeLoading = false;
      });
    } else {
      setState(() {
        isEmployeeLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No employee ID found in session')),
      );
    }
  }

  Future<void> fetchEmployees() async {
    if (sessionEmpId == null) return;

    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/getEmployeesUnderSupervisor.php?emp_id=$sessionEmpId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          employees = data.map((employee) {
            return Employee(
              empId: employee['emp_id'].toString(),
              eCode: employee['e_code'].toString(),
              firstName: employee['first_name'].toString(),
              middleName: employee['middle_name'].toString(),
              lastName: employee['last_name'].toString(),
              shortDesignation: employee['short_designation'].toString(),
              designationCategory: employee['designation_category'].toString(),
            );
          }).toList();
        });
      } else {
        throw Exception('Failed to load employee data');
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    }
  }

  Future<void> fetchEmployeeDetails(String empId) async {
    if (employeeDetailsCache.containsKey(empId)) {
      return;
    }

    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/EmployeeController/getEmployeeDetails.php?emp_id=$empId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          employeeDetailsCache[empId] = data;
        });
      } else {
        throw Exception('Failed to load employee details for emp_id: $empId');
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
      print('Error fetching employee details: $e');
    }
  }

  Future<void> fetchCumulativeReport() async {
    if (selectedEmpId == null ||
        fromDateController.text.isEmpty ||
        toDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select employee and dates')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/getCumulativeDetailReport.php'
          '?emp_id=$selectedEmpId'
          '&from_date=${DateFormat('yyyy-MM-dd').format(DateFormat('dd/MM/yyyy').parse(fromDateController.text))}'
          '&to_date=${DateFormat('yyyy-MM-dd').format(DateFormat('dd/MM/yyyy').parse(toDateController.text))}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            reportData = data['data'];
            logsCache.clear();
          });
          for (var item in reportData) {
            await fetchEmployeeDetails(item['emp_id'].toString());
            await fetchEmployeeDetails(item['submitted_emp_id'].toString());
            await fetchActivityLogs(item['cumulative_detail_id'].toString());
          }
        } else {
          throw Exception('API returned error: ${data['message']}');
        }
      } else {
        throw Exception('Failed to load report data');
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
      print('Error fetching report data: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<dynamic>> fetchActivityLogs(String cumulativeDetailId) async {
    if (logsCache.containsKey(cumulativeDetailId)) {
      return logsCache[cumulativeDetailId]!;
    }

    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/getCumulativeDetailLogReport.php?cumulative_detail_id=$cumulativeDetailId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final logs = data['data'] as List<dynamic>;
          logsCache[cumulativeDetailId] = logs;
          return logs;
        } else {
          throw Exception('API returned error: ${data['message']}');
        }
      } else {
        throw Exception('Failed to load activity logs: ${response.body}');
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error fetching logs: $e')),
      // );
      print('Error fetching logs: $e');
      logsCache[cumulativeDetailId] = [];
      return [];
    }
  }

  String getVerificationStatus(String cumulativeDetailId) {
    final logs = logsCache[cumulativeDetailId] ?? [];
    if (logs.isEmpty) {
      return 'Pending';
    }
    final sortedLogs = List.from(logs)
      ..sort((a, b) => DateTime.parse(b['log_date_time'])
          .compareTo(DateTime.parse(a['log_date_time'])));
    final latestLog = sortedLogs.first;
    final status = latestLog['verification_status']?.toString().toLowerCase();
    if (status == 'verified' || status == 'incorrect') {
      return status ?? 'Pending';
    }
    return 'Pending';
  }

  Color? getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'incorrect':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return null;
    }
  }

  Future<void> verifyActivity(
      String cumulativeDetailId, String verificationStatus) async {
    if (sessionEmpId == null ||
        !employeeDetailsCache.containsKey(sessionEmpId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session employee details not found.')),
      );
      return;
    }

    final employeeDetails = employeeDetailsCache[sessionEmpId];
    if (employeeDetails == null ||
        employeeDetails['e_code'] == null ||
        employeeDetails['first_name'] == null ||
        employeeDetails['last_name'] == null ||
        employeeDetails['short_designation'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incomplete session employee details.')),
      );
      return;
    }

    final activityCheckedBy =
        '(${employeeDetails['e_code']}) ${employeeDetails['first_name']} ${employeeDetails['last_name']} (${employeeDetails['short_designation']})';

    if (cumulativeDetailId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid cumulative detail ID.')),
      );
      return;
    }

    final payload = {
      'cumulative_detail_id': cumulativeDetailId,
      'verification_status': verificationStatus,
      'verified_by': activityCheckedBy,
    };
    setState(() {
      isVerifying = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Verifying...'),
            ],
          ),
        ),
      ),
    );
    print('Sending payload to verifyActivity: $payload');

    try {
      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/insertCumulativeDetailLog.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: payload,
      );

      print('API response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activity $verificationStatus successfully!'),
            backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
          ),
        );
        logsCache.remove(cumulativeDetailId);
        await fetchCumulativeReport();
      } else {
        throw Exception('Failed to verify activity: ${response.body}');
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
      print('Error verifying activity: $e');
    } finally {
      setState(() {
        isVerifying = false;
      });
      Navigator.of(context).pop();
    }
  }

  String getEmployeeName(String empId) {
    final details = employeeDetailsCache[empId];
    if (details == null) {
      return empId;
    }
    final firstName = details['first_name']?.toString() ?? '';
    final middleName = details['middle_name']?.toString() ?? '';
    final lastName = details['last_name']?.toString() ?? '';
    return [firstName, middleName, lastName]
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  Widget _buildLogRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color.fromRGBO(40, 167, 70, 1), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      controller.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      return await getExternalStorageDirectory() ??
          await getTemporaryDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _downloadExcel() async {
    if (reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data to export')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      var excelWorkbook = excel.Excel.createExcel();
      var sheet = excelWorkbook['Sheet1'];

      var headerStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );

      var textStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
        verticalAlign: excel.VerticalAlign.Center,
      );

      var numberStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Right,
        verticalAlign: excel.VerticalAlign.Center,
      );

      var dateStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
      );

      final selectedEmployee = employees.firstWhere(
        (e) => e.empId == selectedEmpId,
        orElse: () => Employee(
          empId: '',
          eCode: '',
          firstName: '',
          middleName: '',
          lastName: '',
          shortDesignation: '',
          designationCategory: '',
        ),
      );

      final headers = [
        'ID',
        'From Date',
        'To Date',
        'Employee',
        'PMD',
        'DA',
        'Submitted By',
        'Submitted Date',
        'Status'
      ];

      sheet.merge(
          excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          excel.CellIndex.indexByColumnRow(
              columnIndex: headers.length - 1, rowIndex: 0));
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = excel.TextCellValue('Cumulative Detail Report');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle = excel.CellStyle(
        bold: true,
        fontSize: 18,
        horizontalAlign: excel.HorizontalAlign.Center,
      );

      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          .value = excel.TextCellValue('Employee: ${selectedEmployee.toString()}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
          .value = excel.TextCellValue('From Date: ${fromDateController.text}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
          .value = excel.TextCellValue('To Date: ${toDateController.text}');

      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 5));
        cell.value = excel.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      for (int row = 0; row < reportData.length; row++) {
        final data = reportData[row];
        final values = [
          data['cumulative_detail_id'].toString(),
          formatDate(data['from_date']),
          formatDate(data['to_date']),
          getEmployeeName(data['emp_id'].toString()),
          data['pmd'].toString(),
          data['da'].toString(),
          getEmployeeName(data['submitted_emp_id'].toString()),
          formatDateTime(data['submitted_date']),
          getVerificationStatus(data['cumulative_detail_id'].toString()),
        ];

        for (int col = 0; col < headers.length; col++) {
          var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: row + 6));
          cell.value = excel.TextCellValue(values[col]);

          if (headers[col] == 'ID' ||
              headers[col] == 'PMD' ||
              headers[col] == 'DA') {
            cell.cellStyle = numberStyle;
          } else if (headers[col] == 'From Date' ||
              headers[col] == 'To Date' ||
              headers[col] == 'Submitted Date') {
            cell.cellStyle = dateStyle;
          } else {
            cell.cellStyle = textStyle;
          }
        }
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, headers[i].length * 1.5);
      }

      final outputDirectory = await _getSaveDirectory();
      final fileName =
          'Cumulative_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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
          const SnackBar(content: Text('Excel report generated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating Excel: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showFilterDialog() {
  final double screenHeight = MediaQuery.of(context).size.height;
  final double screenWidth = MediaQuery.of(context).size.width;

  if (widget.selectedEmpId != null && selectedEmpId == null) {
    selectedEmpId = widget.selectedEmpId;
  }

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter dialogSetState) {
          return AlertDialog(
            title: const Text('Filter Options'),
            content: Container(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16.0,
                  right: 16.0,
                  top: 4.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 1.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: DropdownButton2<Employee>(
                        isExpanded: true,
                        hint: Text(
                          'Select Employee',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        value: employees.isNotEmpty && selectedEmpId != null
                            ? employees.firstWhere(
                                (e) => e.empId == selectedEmpId,
                                orElse: () => employees.first,
                              )
                            : null,
                        onChanged: (Employee? selectedEmployee) {
                          dialogSetState(() {
                            selectedEmpId = selectedEmployee?.empId;
                          });
                          setState(() {
                            selectedEmpId = selectedEmployee?.empId;
                          });
                        },
                        items: employees.map((employee) {
                          return DropdownMenuItem<Employee>(
                            value: employee,
                            child: Text(
                              employee.toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        buttonStyleData: ButtonStyleData(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: screenHeight * 0.13,
                          width: screenWidth * 0.5,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: screenHeight * 0.6,
                        ),
                        menuItemStyleData: MenuItemStyleData(
                          height: screenHeight * 0.07,
                        ),
                        dropdownSearchData: DropdownSearchData(
                          searchController: searchController,
                          searchInnerWidgetHeight: screenHeight * 0.1,
                          searchInnerWidget: Container(
                            height: screenHeight * 0.13,
                            padding: const EdgeInsets.all(5),
                            child: TextFormField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by name or employee code...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                  },
                                ),
                              ),
                            ),
                          ),
                          searchMatchFn: (item, searchValue) {
                            String fullName =
                                "${item.value!.firstName} ${item.value!.middleName} ${item.value!.lastName}"
                                    .trim()
                                    .replaceAll(RegExp(r'\s+'), ' ');
                            String employeeCode = item.value!.eCode ?? '';
                            return fullName
                                    .toLowerCase()
                                    .contains(searchValue.toLowerCase()) ||
                                employeeCode
                                    .toLowerCase()
                                    .contains(searchValue.toLowerCase());
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: fromDateController,
                      decoration: const InputDecoration(
                        labelText: 'From Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context, fromDateController),
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: toDateController,
                      decoration: const InputDecoration(
                        labelText: 'To Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context, toDateController),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03,
                    vertical: screenHeight * 0.015,
                  ),
                  backgroundColor: const Color(0xFF28A746),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  fetchCumulativeReport();
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Apply',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

  String _getSelectedEmployeeName() {
    if (selectedEmpId == null) return 'Not Selected';
    final employee = employees.firstWhere(
      (e) => e.empId == selectedEmpId,
      orElse: () => Employee(
        empId: '',
        eCode: '',
        firstName: 'Not',
        middleName: '',
        lastName: 'Selected',
        shortDesignation: '',
        designationCategory: '',
      ),
    );
    return employee.toString();
  }

 @override
Widget build(BuildContext context) {
  bool hideVerificationColumn = reportData.any((data) =>
      data['submitted_emp_id'].toString() == sessionEmpId);

  return Scaffold(
    appBar: AppBar(
      title: const Text(
        'PMD Approval Report',
        style: TextStyle(
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () {
          // Set orientation based on returnOrientation
          if (widget.returnOrientation == 'landscape') {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]).then((_) {
              Navigator.pop(context);
            });
          } else {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]).then((_) {
              Navigator.pop(context);
            });
          }
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list_alt, color: Colors.white, size: 28),
          tooltip: 'Filter',
          onPressed: _showFilterDialog,
        ),
        IconButton(
          icon: const Icon(Icons.table_chart, color: Colors.white),
          tooltip: 'Download Excel',
          onPressed: _downloadExcel,
        ),
        const SizedBox(width: 10),
      ],
      backgroundColor: const Color(0xFF28A746),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 16.0,
            runSpacing: 8.0,
            children: [
              Text(
                'Employee: ${_getSelectedEmployeeName()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'From Date: ${fromDateController.text}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'To Date: ${toDateController.text}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: isEmployeeLoading
                ? const Center(child: CircularProgressIndicator())
                : isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : reportData.isEmpty
                        ? const Center(child: Text('No data available'))
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateColor.resolveWith(
                                    (states) => const Color(0xFF28A746)),
                                columns: [
                                  const DataColumn(
                                      label: Text('ID',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  const DataColumn(
                                      label: Text('From Date',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  const DataColumn(
                                      label: Text('To Date',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  const DataColumn(
                                      label: Text('Employee',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  const DataColumn(
                                      label: Text('PMD',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  const DataColumn(
                                      label: Text('DA',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  const DataColumn(
                                      label: Text('Submitted By',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  const DataColumn(
                                      label: Text('Submitted Date',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  const DataColumn(
                                      label: Text('Status',
                                          style:
                                              TextStyle(color: Colors.white))),
                                  if (!hideVerificationColumn)
                                    const DataColumn(
                                        label: Text('Approve Verification',
                                            style:
                                                TextStyle(color: Colors.white))),
                                  const DataColumn(
                                      label: Text('Action',
                                          style:
                                              TextStyle(color: Colors.white))),
                                ],
                                rows: reportData.map((data) {
                                  final status = getVerificationStatus(
                                      data['cumulative_detail_id'].toString());
                                  return DataRow(cells: [
                                    DataCell(Text(data['cumulative_detail_id']
                                        .toString())),
                                    DataCell(
                                        Text(formatDate(data['from_date']))),
                                    DataCell(Text(formatDate(data['to_date']))),
                                    DataCell(Text(getEmployeeName(
                                        data['emp_id'].toString()))),
                                    DataCell(Text(data['pmd'])),
                                    DataCell(Text(data['da'])),
                                    DataCell(Text(getEmployeeName(
                                        data['submitted_emp_id'].toString()))),
                                    DataCell(Text(
                                        formatDateTime(data['submitted_date']))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: getStatusBackgroundColor(status),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(status,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    if (!hideVerificationColumn)
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ElevatedButton(
                                              onPressed: isVerifying
                                                  ? null
                                                  : () => verifyActivity(
                                                      data[
                                                              'cumulative_detail_id']
                                                          .toString(),
                                                      'verified'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                shape: const CircleBorder(),
                                                elevation: 2,
                                                minimumSize:
                                                    const Size(20, 20),
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            ElevatedButton(
                                              onPressed: isVerifying
                                                  ? null
                                                  : () => verifyActivity(
                                                      data[
                                                              'cumulative_detail_id']
                                                          .toString(),
                                                      'incorrect'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                shape: const CircleBorder(),
                                                elevation: 2,
                                                minimumSize:
                                                    const Size(20, 20),
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.list,
                                            color: Colors.blue),
                                        tooltip: 'View Logs',
                                        onPressed: () async {
                                          final logs = await fetchActivityLogs(
                                              data['cumulative_detail_id']
                                                  .toString());
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return Dialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Container(
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.5,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.7,
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text(
                                                        'Activity Logs',
                                                        style: TextStyle(
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color.fromRGBO(
                                                                40,
                                                                167,
                                                                70,
                                                                1)),
                                                      ),
                                                      const SizedBox(height: 16),
                                                      Expanded(
                                                        child:
                                                            SingleChildScrollView(
                                                          child: Column(
                                                            children: logs
                                                                .map((log) {
                                                              return Card(
                                                                elevation: 4,
                                                                margin: const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        8),
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12),
                                                                ),
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          16),
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      _buildLogRow(
                                                                        icon: Icons
                                                                            .calendar_today,
                                                                        label:
                                                                            'Log Date Time',
                                                                        value:
                                                                            formatDateTime(log['log_date_time']),
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              8),
                                                                      _buildLogRow(
                                                                        icon: Icons
                                                                            .verified_user,
                                                                        label:
                                                                            'Verification Status',
                                                                        value: log['verification_status']
                                                                                ?.toString() ??
                                                                            'N/A',
                                                                      ),
                                                                      const SizedBox(
                                                                          height:
                                                                              8),
                                                                      _buildLogRow(
                                                                        icon: Icons
                                                                            .person,
                                                                        label:
                                                                            'Checked By',
                                                                        value: log['verified_by']
                                                                                ?.toString() ??
                                                                            'N/A',
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
                                        },
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
          ),
        ),
      ],
    ),
    );
  }
}