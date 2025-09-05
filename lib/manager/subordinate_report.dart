import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:shimmer/shimmer.dart';

class SubordinateReportPage extends StatefulWidget {
  final String? preSelectedEmpId;
  final String? preSelectedEmployeeName;

  const SubordinateReportPage({
    this.preSelectedEmpId,
    this.preSelectedEmployeeName,
    super.key,
  });

  @override
  _SubordinateReportPageState createState() => _SubordinateReportPageState();
}

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

class _SubordinateReportPageState extends State<SubordinateReportPage> {
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController pmdController = TextEditingController();
  final TextEditingController daController = TextEditingController();
  List<Employee> employees = [];
  String? selectedEmpId;
  List<String> _columns = [];
  List<Map<String, dynamic>> _tableData = [];
  bool _isLoading = false;
  String? empId;
  Map<String, dynamic>? employeeDetails;
  static const String _seGcGlImageBaseUrl =
      'https://www.nabeenkishan.net.in/activity_spot_image/';
  static const String _defaultImageBaseUrl =
      'https://www.nabeenkishan.net.in/manager_activity_spot_image/';

  String _getImageBaseUrl() {
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
    final designationCategory = selectedEmployee.designationCategory;
    return (['SALES'].contains(designationCategory))
        ? _seGcGlImageBaseUrl
        : _defaultImageBaseUrl;
  }

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
    pmdController.dispose();
    daController.dispose();
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
      print('Error fetching employee ID and employees: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchActivityLogs(
      String activityId, String empId) async {
    try {
      final String activityIdStr = activityId.toString();
      final String empIdStr = empId.toString();

      final response = await http.get(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/fetchActivityLogsByEmp.php?activity_id=$activityIdStr&emp_id=$empIdStr'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((log) {
              return {
                'verification_status':
                    log['verification_status']?.toString() ?? 'N/A',
                'activity_checked_by':
                    log['activity_checked_by']?.toString() ?? 'N/A',
                'checked_date': log['checked_date']?.toString() ?? 'N/A',
                'log_date_time': log['log_date_time']?.toString() ??
                    'N/A', // Added log_date_time
              };
            })
            .toList()
            .cast<Map<String, dynamic>>();
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
        return [];
      }
    } catch (e) {
      print('Error fetching activity logs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching activity logs: $e')),
      );
      return [];
    }
  }

  Future<void> fetchEmployeeDetails() async {
    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/EmployeeController/getEmployeeDetails.php?emp_id=$empId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          employeeDetails = data;
        });
      } else {
        throw Exception('Failed to load employee details');
      }
    } catch (e) {
      print('Error fetching employee details: $e');
    }
  }

  Future<void> fetchEmployees() async {
    if (empId == null) return;

    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/getEmployeesUnderSupervisor.php?emp_id=$empId'));

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
      print('Error fetching employees: $e');
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
    setState(() {
      _columns = []; // Clear columns
      _tableData = []; // Clear table data
    });
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final selectedEmployee = employees.firstWhere(
      (e) => e.empId == selectedEmpId,
      orElse: () => employees.isNotEmpty
          ? employees.first
          : Employee(
              empId: '',
              eCode: '',
              firstName: '',
              middleName: '',
              lastName: '',
              shortDesignation: '',
              designationCategory: '',
            ),
    );

    final designationCategory = selectedEmployee.designationCategory;

    _columns = (['SALES'].contains(designationCategory))
        ? [
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
            'Office Name',
            'Total Customer',
            'Collection Ammount',
            'Delivery Unit',
            'Remarks',
            'Location',
            'Spot Picture',
            'Status',
            'Approve Verification',
            'Action',
          ]
        : [
            'Activity Date',
            'Status of Work',
            'Camp Name',
            'Camp Nature of Work',
            'Name of SE GC GL',
            'Customer Name',
            'Customer Address',
            'Customer Phone No',
            'Result',
            'Order No',
            'Booking Unit',
            'Booking Advance',
            'Office Name',
            'Office Nature of Work',
            'Product Names',
            'Spot Picture',
            'Location',
            'Remarks',
            'Status',
            'Approve Verification',
            'Action',
          ];

    String fromDate = fromDateController.text;
    String toDate = toDateController.text;
    String apiFromDate = DateFormat('yyyy-MM-dd')
        .format(DateFormat('dd/MM/yyyy').parse(fromDate));
    String apiToDate = DateFormat('yyyy-MM-dd')
        .format(DateFormat('dd/MM/yyyy').parse(toDate));
    final response = await http.get(
      Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/employeeActivities.php'
          '?emp_id=${selectedEmpId!}&from_date=$apiFromDate&to_date=$apiToDate'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      if (data.isEmpty) {
        setState(() {
          _tableData = []; // Clear table data
          _columns = []; // Clear columns
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data found.')),
        );
      } else {
        setState(() {
          _tableData = data.map<Map<String, dynamic>>((activity) {
            String formattedDate = '';
            if (activity['activity_date'] != null) {
              try {
                final date = DateTime.parse(activity['activity_date']);
                formattedDate = DateFormat('dd/MM/yyyy hh:mm a').format(date);
              } catch (e) {
                formattedDate = activity['activity_date']?.toString() ?? '';
              }
            }
            return {
              'Customer Name': activity['customer_name']?.toString() ?? '',
              'Customer Address': activity['customer_address']?.toString() ?? '',
              'Customer Phone No': activity['customer_phone_no']?.toString() ?? '',
              'Activity Date': formattedDate,
              'Nature of Work': activity['nature_of_work']?.toString() ?? '',
              'Product Names': activity['product_names']?.toString() ?? '',
              'Order No': activity['order_no']?.toString() ?? '',
              'Result': activity['result']?.toString() ?? '',
              'Remarks': activity['remarks']?.toString() ?? '',
              'Order Unit': activity['order_unit']?.toString() ?? '',
              'Booking Advance': activity['booking_advance']?.toString() ?? '',
              'Total Customer': activity['total_customer']?.toString() ?? '',
              'Collection Ammount': activity['collection_amount']?.toString() ?? '',
              'Delivery Unit': activity['delivery_unit']?.toString() ?? '',
              'Status': activity['verification_status']?.toString() ?? '',
              'Latitude': activity['latitude']?.toString() ?? '',
              'Longitude': activity['longitude']?.toString() ?? '',
              'Spot Picture': activity['spot_picture']?.toString() ?? '',
              'Camp Name': activity['camp_name']?.toString() ?? '',
              'Camp Nature of Work': activity['camp_nature_of_work']?.toString() ?? '',
              'Status of Work': activity['status_of_work']?.toString() ?? '',
              'Office Name': activity['office_name']?.toString() ?? '',
              'Office Nature of Work':
                  activity['office_nature_of_work']?.toString() ?? '',
              'Name of SE GC GL': activity['name_of_se_gc_gl']?.toString() ?? '',
              'Booking Unit': activity['booking_unit']?.toString() ?? '',
              'activity_id': activity['activity_id']?.toString() ?? '',
              'Location': activity['location']?.toString() ?? 'Not Available',
            };
          }).toList();
        });
      }
    } else {
      setState(() {
        _tableData = []; // Clear table data
        _columns = []; // Clear columns
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data found.')),
      );
    }
  } catch (e) {
    print('Error: $e');
    setState(() {
      _tableData = []; // Clear table data
      _columns = []; // Clear columns
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fetching data: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return 'N/A';
    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      return DateFormat('dd/MM/yy hh:mm a').format(dateTime);
    } catch (e) {
      print('Error formatting date-time: $e');
      return 'Invalid Date';
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

  Future<void> verifyActivity(
      String activityId, String verificationStatus) async {
    if (employeeDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee details not found.')),
      );
      return;
    }

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm ${verificationStatus.toUpperCase()}'),
          content: Text(
              'Are you sure you want to mark this activity as $verificationStatus?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28A746),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return; // User canceled, do nothing
    }

    final activityCheckedBy =
        '(${employeeDetails!['e_code']}) ${employeeDetails!['first_name']} ${employeeDetails!['last_name']} (${employeeDetails!['short_designation']})';

    try {
      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/verifyActivityByEmp.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'activity_id': activityId,
          'emp_id': selectedEmpId,
          'verification_status': verificationStatus,
          'activity_checked_by': activityCheckedBy,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Activity $verificationStatus successfully!'),
            backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
          ),
        );
        await fetchAndSetColumns();
      } else {
        throw Exception('Failed to verify activity');
      }
    } catch (e) {
      print('Error verifying activity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying activity: $e')),
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
    if (_tableData.isEmpty) {
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

      final headers = _columns
          .where((column) =>
              column != 'Approve Verification' && column != 'Action')
          .toList();

      sheet.merge(
          excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          excel.CellIndex.indexByColumnRow(
              columnIndex: headers.length - 1, rowIndex: 0));
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = excel.TextCellValue('Subordinate Activity Report');
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

      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 5));
        cell.value = excel.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      final imageBaseUrl = _getImageBaseUrl();
      for (int row = 0; row < _tableData.length; row++) {
        final data = _tableData[row];
        for (int col = 0; col < headers.length; col++) {
          String column = headers[col];
          dynamic value;

          if (column == 'Location') {
            value = data[column] ?? 'Not Available';
          } else if (column == 'Spot Picture') {
            value = data[column]?.isNotEmpty == true
                ? '$imageBaseUrl${data[column]}'
                : 'No Image';
          } else if (column == 'Product Names') {
            if (data[column] is List) {
              value = (data[column] as List)
                  .where((p) => p != null && p.toString().trim().isNotEmpty)
                  .join('\n');
            } else if (data[column] is String) {
              value = (data[column] as String)
                  .split(',')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty)
                  .join('\n');
            } else {
              value = 'N/A';
            }
          } else if (column == 'Customer Name' ||
              column == 'Customer Address') {
            value = (data[column]?.toString() ?? 'N/A')
                .replaceAll('\n', ' ')
                .trim();
          } else if (column == 'Nature of Work') {
            value = (data[column]?.toString() ?? 'N/A').toUpperCase();
          } else {
            value = data[column]?.toString() ?? 'N/A';
          }

          var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: row + 6));
          cell.value = excel.TextCellValue(value.toString());

          if (column == 'Order No' ||
              column == 'Order Unit' ||
              column == 'Booking Advance' ||
              column == 'Collection Ammount' ||
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

        if (data['Product Names'] != null) {
          final products = data['Product Names'] is List
              ? (data['Product Names'] as List).length
              : data['Product Names'].toString().split('\n').length;
          final productLines = products > 0 ? products : 1;
          sheet.setRowHeight(
              row + 6, 40.0 * (productLines > 5 ? 5 : productLines));
        }
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, headers[i].length * 1.5);
      }

      final outputDirectory = await _getSaveDirectory();
      final fileName =
          'Subordinate_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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

  Future<List<Map<String, dynamic>>> fetchSummaryData() async {
    if (selectedEmpId == null ||
        fromDateController.text.isEmpty ||
        toDateController.text.isEmpty) {
      print(
          'fetchSummaryData: Invalid input - empId: $selectedEmpId, fromDate: ${fromDateController.text}, toDate: ${toDateController.text}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select an employee and date range.')),
      );
      return [];
    }

    try {
      String fromDate = fromDateController.text;
      String toDate = toDateController.text;
      String apiFromDate = DateFormat('yyyy-MM-dd')
          .format(DateFormat('dd/MM/yyyy').parse(fromDate));
      String apiToDate = DateFormat('yyyy-MM-dd')
          .format(DateFormat('dd/MM/yyyy').parse(toDate));

      final apiUrl =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/employeeActivitySummary.php'
          '?emp_id=$selectedEmpId&from_date=$apiFromDate&to_date=$apiToDate';
      print('fetchSummaryData: Requesting URL: $apiUrl');

      final response = await http.get(Uri.parse(apiUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('fetchSummaryData: Request timed out');
          throw Exception('Request timed out');
        },
      );

      print('fetchSummaryData: Response status: ${response.statusCode}');
      print('fetchSummaryData: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isEmpty) {
          print('fetchSummaryData: API returned empty data');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No summary data available.')),
          );
          return [];
        }
        return data.cast<Map<String, dynamic>>();
      } else {
        print('fetchSummaryData: Failed with status ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch summary data: ${response.statusCode}')),
        );
        return [];
      }
    } catch (e) {
      print('fetchSummaryData: Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching summary: $e')),
      );
      return [];
    }
  }

  void _showSummaryPopup() async {
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

    setState(() {
      _isLoading = true;
    });
    final summaryData = await fetchSummaryData();
    setState(() {
      _isLoading = false;
    });

    if (summaryData.isEmpty) {
      return;
    }

    final TextEditingController pmdController = TextEditingController();
    final TextEditingController daController = TextEditingController();

    Future<bool> checkDateRangeOverlap(
        String empId, String fromDate, String toDate) async {
      try {
        final response = await http.get(
          Uri.parse(
              'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/checkCumulativeDetailRangeOverlap.php'
              '?emp_id=$empId&from_date=$fromDate&to_date=$toDate'),
        );

        print(
            'checkDateRangeOverlap: Response: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['overlap'] ?? true;
        } else {
          throw Exception(
              'Failed to check date range overlap: ${response.statusCode}');
        }
      } catch (e) {
        print('checkDateRangeOverlap: Error: $e');
        return true;
      }
    }

    Future<void> submitCumulativeDetails({
      required String empId,
      required String apiFromDate,
      required String apiToDate,
      required double pmdValue,
      required double daValue,
      required String submittedEmpId,
    }) async {
      setState(() {
        _isLoading = true;
      });

      try {
        final hasOverlap =
            await checkDateRangeOverlap(empId, apiFromDate, apiToDate);
        if (hasOverlap) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Date Range Overlap'),
                content: const Text(
                    'The selected date range overlaps with existing records. Please choose a different range.'),
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
          return;
        }

        var formRequest = http.MultipartRequest(
          'POST',
          Uri.parse(
              'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/insertCumulativeDetail.php'),
        );
        formRequest.fields.addAll({
          'emp_id': empId,
          'from_date': apiFromDate,
          'to_date': apiToDate,
          'pmd': pmdValue.toString(),
          'da': daValue.toString(),
          'submitted_emp_id': submittedEmpId,
        });
        formRequest.headers.addAll({
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        });
        final formResponse = await formRequest.send();
        final formResponseBody = await formResponse.stream.bytesToString();

        print(
            'submitCumulativeDetails: Response: ${formResponse.statusCode} - $formResponseBody');
        if (formResponse.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cumulative details submitted successfully!'),
              backgroundColor: Color(0xFF28A746),
            ),
          );
          Navigator.pop(context);
        } else {
          throw Exception(
              'Failed to submit cumulative details: ${formResponse.statusCode}');
        }
      } catch (e) {
        print('submitCumulativeDetails: Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting cumulative details: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }

    Future<void> showConfirmationDialog({
      required String empId,
      required String apiFromDate,
      required String apiToDate,
      required double pmdValue,
      required double daValue,
      required String submittedEmpId,
    }) async {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Submission'),
            content: const Text('Are you sure you want to submit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A746),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        await submitCumulativeDetails(
          empId: empId,
          apiFromDate: apiFromDate,
          apiToDate: apiToDate,
          pmdValue: pmdValue,
          daValue: daValue,
          submittedEmpId: submittedEmpId,
        );
      }
    }

    void showPreviewDialog({
      required String employeeName,
      required String fromDate,
      required String toDate,
      required String pmd,
      required String da,
    }) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Submission Preview'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Employee: $employeeName',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'From Date: $fromDate',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To Date: $toDate',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PMD: $pmd',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'DA: $da',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A746),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  if (selectedEmpId == null || selectedEmpId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select an employee.')),
                    );
                    return;
                  }

                  bool isValidEmpId =
                      employees.any((e) => e.empId == selectedEmpId);
                  if (!isValidEmpId) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Invalid employee selected.')),
                    );
                    return;
                  }

                  if (empId == null || empId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Session expired. Please log in again.')),
                    );
                    return;
                  }

                  if (fromDate.isEmpty || toDate.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select a date range.')),
                    );
                    return;
                  }

                  if (pmd.isEmpty || da.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Please enter both PMD and DA values.')),
                    );
                    return;
                  }

                  double? pmdValue;
                  double? daValue;
                  try {
                    pmdValue = double.parse(pmd);
                    daValue = double.parse(da);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('PMD and DA must be valid numbers.')),
                    );
                    return;
                  }

                  String apiFromDate;
                  String apiToDate;
                  try {
                    apiFromDate = DateFormat('yyyy-MM-dd')
                        .format(DateFormat('dd/MM/yyyy').parse(fromDate));
                    apiToDate = DateFormat('yyyy-MM-dd')
                        .format(DateFormat('dd/MM/yyyy').parse(toDate));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid date format.')),
                    );
                    return;
                  }

                  await showConfirmationDialog(
                    empId: selectedEmpId!,
                    apiFromDate: apiFromDate,
                    apiToDate: apiToDate,
                    pmdValue: pmdValue,
                    daValue: daValue,
                    submittedEmpId: empId!,
                  );
                },
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    }

    void validateAndShowPreview() {
      if (selectedEmpId == null || selectedEmpId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an employee.')),
        );
        return;
      }

      bool isValidEmpId = employees.any((e) => e.empId == selectedEmpId);
      if (!isValidEmpId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid employee selected.')),
        );
        return;
      }

      if (fromDateController.text.isEmpty || toDateController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date range.')),
        );
        return;
      }

      final pmdText = pmdController.text.trim();
      final daText = daController.text.trim();
      if (pmdText.isEmpty || daText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter both PMD and DA values.')),
        );
        return;
      }

      try {
        double.parse(pmdText);
        double.parse(daText);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PMD and DA must be valid numbers.')),
        );
        return;
      }

      showPreviewDialog(
        employeeName: selectedEmployee.toString(),
        fromDate: fromDateController.text,
        toDate: toDateController.text,
        pmd: pmdText,
        da: daText,
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height *
                0.7, // Constrain dialog height
            child: RawScrollbar(
              thumbColor: const Color(0xFF28A746), // Green thumb color
              trackColor: const Color(0xFF28A746)
                  .withOpacity(0.2), // Green track with transparency
              trackVisibility: true, // Show track
              thumbVisibility: true, // Always show scrollbar
              radius: const Radius.circular(8), // Rounded scrollbar edgesar
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                      Table(
                        border: TableBorder.all(color: Colors.green),
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1),
                          3: FlexColumnWidth(1),
                          4: FlexColumnWidth(1.5),
                        },
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(color: Colors.green),
                            children: [
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Result',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Verified Total',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Total Days',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Collection Amount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          ...summaryData.map((summary) {
                            String result =
                                summary['nature_of_work'] ?? 'OTHERS';
                            String total = summary['total']?.toString() ?? '0';
                            String verifiedTotal =
                                summary['verified_total']?.toString() ?? '0';
                            String totalDays =
                                summary['total_days']?.toString() ?? '0';
                            String collectionAmount =
                                summary['total_collection']?.toString() ??
                                    '0.00';

                            double parsedCollection = 0.0;
                            try {
                              parsedCollection = double.parse(
                                  collectionAmount.replaceAll(',', ''));
                            } catch (e) {
                              parsedCollection = 0.0;
                            }

                            return _buildSummaryRow(
                              result,
                              total,
                              verifiedTotal,
                              totalDays,
                              parsedCollection,
                            );
                          }).toList(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: pmdController,
                              decoration: const InputDecoration(
                                labelText: 'PMD',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: daController,
                              decoration: const InputDecoration(
                                labelText: 'DA',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Close',
                              style:
                                  TextStyle(color: Color.fromARGB(255, 221, 48, 71)),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF28A746),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            onPressed: _isLoading ? null : validateAndShowPreview,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Submit',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 16),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  TableRow _buildSummaryRow(String result, String total, String verifiedTotal,
      String totalDays, double collectionAmount) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            result,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.left,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            total,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            verifiedTotal,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            totalDays,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            collectionAmount.toStringAsFixed(2),
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  void _showImagePopup(String imagePath) {
    final imageBaseUrl = _getImageBaseUrl();

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
                        imageUrl: imageBaseUrl + imagePath,
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
      shortDesignation: '',
      designationCategory: '',
    ),
  );

  final bool isManager = employeeDetails != null &&
      employeeDetails!['designation_category'] == 'MANAGER';
  final bool isSelectedEmployeeManager =
      selectedEmployee.designationCategory == 'MANAGER';

  return Scaffold(
    appBar: AppBar(
      title: Text(
        "Subordinate Report Selection${widget.preSelectedEmployeeName != null ? ' - ${widget.preSelectedEmployeeName}' : ''}",
        style: const TextStyle(color: Colors.white),
      ),
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
      backgroundColor: Color(0xFF28A746),
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF28A746)))
        : Padding(
            padding: EdgeInsets.all(isKeyboardVisible ? 8.0 : 16.0),
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
                      child: Row(
                        children: [
                          Text(
                            'From Date: ${fromDateController.text}  |  To Date: ${toDateController.text}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (isManager && !isSelectedEmployeeManager) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _showSummaryPopup,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF28A746),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.summarize, size: 20),
                                  SizedBox(width: 8),
                                  Text('View Summary'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                if (selectedEmpId == null ||
                                    fromDateController.text.isEmpty ||
                                    toDateController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Please select an employee and date range.')),
                                  );
                                  return;
                                }
                                Navigator.pushNamed(
                                  context,
                                  'cumulative_report',
                                  arguments: {
                                    'empId': selectedEmpId,
                                    'fromDate': fromDateController.text,
                                    'toDate': toDateController.text,
                                    'returnOrientation': 'landscape',
                                  },
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF28A746),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.assessment, size: 20),
                                  SizedBox(width: 8),
                                  Text('PMD Approval Report'),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  _columns.isEmpty && _tableData.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Text(
                              'No data found for the selected filters. Please try different filters.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _tableData.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.0),
                                child: Text(
                                  'No data found for the selected filters. Please try different filters.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor:
                                      MaterialStateProperty.all(Color(0xFF28A746)),
                                  headingTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  dataRowMinHeight: 50,
                                  dataRowMaxHeight: double.infinity,
                                  columns: _columns
                                      .map((column) =>
                                          DataColumn(label: Text(column)))
                                      .toList(),
                                  rows: _tableData.map((row) {
                                    final activityId =
                                        row['activity_id'].toString();
                                    final verificationStatus =
                                        row['Status']?.toString().toLowerCase();
                                    return DataRow(
                                      cells: _columns.map((column) {
                                        if (column == 'Approve Verification') {
                                          bool isVerified =
                                              verificationStatus == 'verified';
                                          bool isIncorrect =
                                              verificationStatus == 'incorrect';
                                          return DataCell(
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(horizontal: 6.0),
                                                  child: ElevatedButton(
                                                    onPressed: isIncorrect
                                                        ? null
                                                        : () => verifyActivity(
                                                            activityId, 'incorrect'),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      foregroundColor:
                                                          Colors.white,
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
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  margin: const EdgeInsets
                                                      .symmetric(horizontal: 6.0),
                                                  child: ElevatedButton(
                                                    onPressed: isVerified
                                                        ? null
                                                        : () => verifyActivity(
                                                            activityId, 'verified'),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.green,
                                                      foregroundColor:
                                                          Colors.white,
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
                                                ),
                                              ],
                                            ),
                                          );
                                        } else if (column == 'Spot Picture') {
                                          final imagePath = row[column];
                                          return DataCell(
                                            imagePath != null &&
                                                    imagePath.isNotEmpty
                                                ? TextButton(
                                                    onPressed: () =>
                                                        _showImagePopup(imagePath),
                                                    child: const Text(
                                                      'View Image',
                                                      style: TextStyle(
                                                          color: Colors.blue),
                                                    ),
                                                  )
                                                : const Text('No Image'),
                                          );
                                        } else if (column == 'Status') {
                                          return DataCell(
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: row[column] == 'verified'
                                                    ? Colors.green
                                                    : row[column] == 'incorrect'
                                                        ? Colors.red
                                                        : Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                row[column] ?? 'Pending',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          );
                                        } else if (column == 'Location') {
                                          return DataCell(
                                            Text(
                                              row[column]?.isEmpty ?? true
                                                  ? '__'
                                                  : row[column].toString(),
                                            ),
                                          );
                                        } else if (column == 'Action') {
                                          return DataCell(
                                            TextButton(
                                              onPressed: () async {
                                                final logs = await fetchActivityLogs(
                                                    row['activity_id'].toString(),
                                                    selectedEmpId!);
                                                if (logs.isNotEmpty) {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) {
                                                      return Dialog(
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  16),
                                                        ),
                                                        child: Container(
                                                          width: MediaQuery.of(
                                                                  context)
                                                              .size
                                                              .width *
                                                              0.5,
                                                          height: MediaQuery.of(
                                                                  context)
                                                              .size
                                                              .height *
                                                              0.7,
                                                          padding:
                                                              const EdgeInsets.all(
                                                                  16),
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
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Color
                                                                        .fromRGBO(
                                                                            40,
                                                                            167,
                                                                            70,
                                                                            1)),
                                                              ),
                                                              const SizedBox(
                                                                  height: 16),
                                                              Expanded(
                                                                child:
                                                                    SingleChildScrollView(
                                                                  child: Column(
                                                                    children: logs
                                                                        .map((log) {
                                                                      return Card(
                                                                        elevation:
                                                                            4,
                                                                        margin: const EdgeInsets
                                                                            .symmetric(
                                                                            vertical:
                                                                                8),
                                                                        shape:
                                                                            RoundedRectangleBorder(
                                                                          borderRadius:
                                                                              BorderRadius.circular(12),
                                                                        ),
                                                                        child:
                                                                            Padding(
                                                                          padding:
                                                                              const EdgeInsets.all(16),
                                                                          child:
                                                                              Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              _buildLogRow(
                                                                                icon: Icons.calendar_today,
                                                                                label: 'Log Date Time',
                                                                                value: _formatDateTime(log['log_date_time']),
                                                                              ),
                                                                              const SizedBox(
                                                                                  height: 8),
                                                                              _buildLogRow(
                                                                                icon: Icons.verified_user,
                                                                                label: 'Verification Status',
                                                                                value: log['verification_status'] ?? 'N/A',
                                                                              ),
                                                                              const SizedBox(
                                                                                  height: 8),
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
                                                } else {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            'No activity logs available.')),
                                                  );
                                                }
                                              },
                                              child: const Text(
                                                'View Logs',
                                                style: TextStyle(
                                                    color: Colors.blue),
                                              ),
                                            ),
                                          );
                                        } else {
                                          return DataCell(
                                            Text(
                                              row[column]?.toString() ?? 'N/A',
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
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
}