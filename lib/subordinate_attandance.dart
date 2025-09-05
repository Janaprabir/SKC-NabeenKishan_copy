import 'dart:convert';
import 'dart:io';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class SubordinateAttendanceReportPage extends StatefulWidget {
  final String? preSelectedEmpId;
  final String? preSelectedEmployeeName;

  const SubordinateAttendanceReportPage({
    this.preSelectedEmpId,
    this.preSelectedEmployeeName,
    super.key,
  });

  @override
  _SubordinateAttendanceReportPageState createState() =>
      _SubordinateAttendanceReportPageState();
}

class Employee {
  final String empId;
  final String eCode;
  final String firstName;
  final String middleName;
  final String lastName;
  final String designationCategory;

  Employee({
    required this.empId,
    required this.eCode,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.designationCategory,
  });

  @override
  String toString() {
    return '$eCode - $firstName $middleName $lastName - $designationCategory';
  }
}

class _SubordinateAttendanceReportPageState
    extends State<SubordinateAttendanceReportPage> {
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  List<Employee> employees = [];
  String? selectedEmpId;
  List<String> _columns = [];
  List<Map<String, dynamic>> _tableData = [];
  bool _isLoading = false;
  String? empId;
  Map<String, dynamic>? employeeDetails;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _setDefaultDates();

    if (widget.preSelectedEmpId != null) {
      selectedEmpId = widget.preSelectedEmpId;
    }

    fetchEmpIdAndEmployees();
  }

  void _setDefaultDates() {
    String today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    fromDateController.text = today;
    toDateController.text = today;
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    fromDateController.dispose();
    toDateController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchEmpIdAndEmployees() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      empId = prefs.getString('emp_id');
      if (empId == null) {
        throw Exception('Session expired. Please log in again.');
      }
      await fetchEmployeeDetails();
      await fetchEmployees();

      if (widget.preSelectedEmpId != null) {
        await fetchAndSetColumns();
      }
    } catch (e) {
      debugPrint('Error fetching employee data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> fetchEmployeeDetails() async {
    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/newproject/api/routes/EmployeeController/getEmployeeDetails.php?emp_id=$empId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          employeeDetails = data;
        });
      } else {
        throw Exception('Failed to load employee details');
      }
    } catch (e) {
      debugPrint('Error fetching employee details: $e');
    }
  }

  Future<void> fetchEmployees() async {
    if (empId == null) return;

    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/newproject/api/routes/ManagerActivitiesController/getEmployeesUnderSupervisor.php?emp_id=$empId'));

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
              designationCategory: employee['designation_category'].toString(),
            );
          }).toList();
        });
      } else {
        throw Exception('Failed to load employee data');
      }
    } catch (e) {
      // Handle error silently or log it
    }
  }

  Future<void> fetchAndSetColumns() async {
    if (selectedEmpId == null ||
        fromDateController.text.isEmpty ||
        toDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select an employee and date range.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      _columns = [
        'Attendance Date',
        'In Time',
        'In Location',
        'In Picture',
        'Out Time',
        'Out Location',
        'Out Picture',
        'Work Status',
        'Camp Name',
        'Office Name',
        'Remarks',
      ];

      String fromDate = fromDateController.text;
      String toDate = toDateController.text;
      String apiFromDate = DateFormat('yyyy-MM-dd')
          .format(DateFormat('dd/MM/yyyy').parse(fromDate));
      String apiToDate = DateFormat('yyyy-MM-dd')
          .format(DateFormat('dd/MM/yyyy').parse(toDate));
      final response = await http.get(
        Uri.parse(
            'https://www.nabeenkishan.net.in/newproject/api/routes/AttendanceController/attendanceReport.php'
            '?emp_id=${selectedEmpId!}&from_date=$apiFromDate&to_date=$apiToDate'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> data = jsonResponse['data'];

        setState(() {
          _tableData = data.map<Map<String, dynamic>>((attendance) {
            String formattedDate = '';
            if (attendance['attendance_date'] != null) {
              try {
                final date = DateTime.parse(attendance['attendance_date']);
                formattedDate = DateFormat('dd/MM/yyyy').format(date);
              } catch (e) {
                formattedDate = attendance['attendance_date']?.toString() ?? '';
              }
            }

            String workStatus = 'Field';
            if (attendance['status_of_work_camp'] == 1) {
              workStatus = 'Camp';
            } else if (attendance['status_of_work_office'] == 1) {
              workStatus = 'Office';
            } else if (attendance['status_of_work_leave'] == 1) {
              workStatus = 'Leave';
            }

            return {
              'Attendance Date': formattedDate,
              'In Time': attendance['in_time'] ?? 'N/A',
              'In Location':
                  attendance['in_location']?.toString() ?? 'Not Available',
              'In Picture': attendance['in_picture'] ?? '',
              'Out Time': attendance['out_time'] ?? 'N/A',
              'Out Location':
                  attendance['out_location']?.toString() ?? 'Not Available',
              'Out Picture': attendance['out_picture'] ?? '',
              'Work Status': workStatus,
              'Camp Name': attendance['camp_name'] ?? '',
              'Office Name': attendance['branch_name'] ?? '',
              'Remarks': attendance['remarks'] ?? '',
              'attendance_date': attendance['attendance_date'],
            };
          }).toList();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No attendance data found.')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
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
    if (_tableData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance data to export')),
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

      final selectedEmployee = employees.firstWhere(
        (e) => e.empId == selectedEmpId,
        orElse: () => Employee(
            empId: '',
            eCode: '',
            firstName: '',
            middleName: '',
            lastName: '',
            designationCategory: ''),
      );

      sheet.merge(
          excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          excel.CellIndex.indexByColumnRow(
              columnIndex: _columns.length - 1, rowIndex: 0));
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = excel.TextCellValue('Subordinate Attendance Report');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle = excel.CellStyle(
        bold: true,
        fontSize: 18,
        horizontalAlign: excel.HorizontalAlign.Center,
      );

      sheet
              .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
              .value =
          excel.TextCellValue('Employee: ${selectedEmployee.toString()}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
          .value = excel.TextCellValue('From Date: ${fromDateController.text}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
          .value = excel.TextCellValue('To Date: ${toDateController.text}');

      final headers = _columns;
      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 5));
        cell.value = excel.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      for (int row = 0; row < _tableData.length; row++) {
        final data = _tableData[row];
        for (int col = 0; col < headers.length; col++) {
          String column = headers[col];
          String value;

          if (column == 'In Location' || column == 'Out Location') {
            value = data[column] ?? 'Not Available';
          } else if (column == 'In Picture' || column == 'Out Picture') {
            value = data[column].isNotEmpty
                ? 'https://www.nabeenkishan.net.in/AttendancePicture/${data[column]}'
                : 'No Image';
          } else {
            value = data[column]?.toString() ?? 'N/A';
          }

          var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: row + 6));
          cell.value = excel.TextCellValue(value);

          if (column == 'In Time' || column == 'Out Time') {
            cell.cellStyle = centerStyle;
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
          'subordinate_attendance_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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

  void _showFilterDialog() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    if (widget.preSelectedEmpId != null && selectedEmpId == null) {
      selectedEmpId = widget.preSelectedEmpId;
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
                                  hintText:
                                      'Search by name or employee code...',
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
                                  "${item.value!.firstName} ${item.value!.lastName}";
                              String employeeCode = item.value!.eCode;
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
                    fetchAndSetColumns();
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

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    final selectedEmployee = employees.firstWhere(
      (e) => e.empId == selectedEmpId,
      orElse: () => Employee(
          empId: '',
          eCode: '',
          firstName: '',
          middleName: '',
          lastName: '',
          designationCategory: ''),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
            "Subordinate Attendance Report${widget.preSelectedEmployeeName != null ? ' - ${widget.preSelectedEmployeeName}' : ''}",
            style: const TextStyle(color: Colors.white)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_alt,
                color: Colors.white, size: 28),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28A746)))
          : Padding(
              padding: EdgeInsets.all(16.0)
                  .copyWith(bottom: isKeyboardVisible ? 8.0 : 16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_columns.isNotEmpty && _tableData.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Employee: ${selectedEmployee.toString()}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'From Date: ${fromDateController.text}  |  To Date: ${toDateController.text}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                    _columns.isEmpty
                        ? const Center(
                            child: Text(
                                'No columns to display. Please apply filter to fetch data.'))
                        : _tableData.isEmpty
                            ? const Center(
                                child: Text('No attendance data available.'))
                            : SizedBox(
                              
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(
                                        const Color(0xFF28A746)),
                                    headingTextStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    columns: _columns
                                        .map((column) =>
                                            DataColumn(label: Text(column)))
                                        .toList(),
                                    rows: _tableData.map((row) {
                                      return DataRow(
                                        cells: _columns.map((column) {
                                          if (column == 'In Picture' ||
                                              column == 'Out Picture') {
                                            final imagePath = row[column];
                                            if (imagePath != null &&
                                                imagePath.isNotEmpty) {
                                              return DataCell(
                                                TextButton(
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return AlertDialog(
                                                          content: SizedBox(
                                                            width: 200,
                                                            height: 300,
                                                            child:
                                                                Image.network(
                                                              'https://www.nabeenkishan.net.in/AttendancePicture/$imagePath',
                                                              fit: BoxFit.cover,
                                                              loadingBuilder:
                                                                  (context,
                                                                      child,
                                                                      loadingProgress) {
                                                                if (loadingProgress ==
                                                                    null)
                                                                  return child;
                                                                return const Center(
                                                                    child: Text(
                                                                        'Loading...'));
                                                              },
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                  child: const Text(
                                                    'View Image',
                                                    style: TextStyle(
                                                        color: Colors.blue),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              return const DataCell(
                                                  Text('No Image'));
                                            }
                                          } else if (column == 'In Location' ||
                                              column == 'Out Location') {
                                            return DataCell(
                                              Text(
                                                row[column]?.isEmpty ?? true
                                                    ? '__'
                                                    : row[column]!,
                                              ),
                                            );
                                          } else if (column == 'Work Status') {
                                            return DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: row[column] == 'Field'
                                                      ? Colors.blue
                                                      : row[column] == 'Camp'
                                                          ? Colors.green
                                                          : row[column] ==
                                                                  'Office'
                                                              ? Colors.orange
                                                              : Colors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  row[column] ?? 'N/A',
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                            );
                                          } else {
                                            final rawValue = row[column];
                                            final value = (rawValue == null ||
                                                    rawValue
                                                        .toString()
                                                        .trim()
                                                        .isEmpty)
                                                ? '__'
                                                : rawValue.toString();
                                            return DataCell(
                                                Text(value, maxLines: 2));
                                          }
                                        }).toList(),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                  ],
                ),
              ),
            ),
    );
  }
}
