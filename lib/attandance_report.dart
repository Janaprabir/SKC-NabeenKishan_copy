import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  List<dynamic> _attendanceList = [];
  bool _isLoading = false;
  String? empId;
  String? designation;
  String? designationCategory;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _setDefaultDates();
    _loadSessionData().then((_) => _fetchAttendance());
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        empId = prefs.getString('emp_id');
        designation = prefs.getString('short_designation');
        designationCategory = prefs.getString('designation_category');
      });
    }
  }

  void _setDefaultDates() {
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _fromDateController.text = DateFormat('dd/MM/yyyy').format(_fromDate);
    _toDateController.text = DateFormat('dd/MM/yyyy').format(_toDate);
  }

  Future<void> _fetchAttendance() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    if (empId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee ID not found in session')),
        );
        setState(() {
          _attendanceList = [];
          _isLoading = false;
        });
      }
      return;
    }

    final url = Uri.parse(
        'https://www.nabeenkishan.net.in/newproject/api/routes/AttendanceController/attendanceReport.php?emp_id=$empId&from_date=${DateFormat('yyyy-MM-dd').format(_fromDate)}&to_date=${DateFormat('yyyy-MM-dd').format(_toDate)}');
    try {
      print('API Request: $url');
      final response = await http.get(url);
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (mounted) {
        setState(() {
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            _attendanceList = data["data"] ?? [];
          } else {
            print('Server Error: ${response.statusCode}');
            _attendanceList = []; // Clear list on server error
          }

          if (_attendanceList.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'No attendance records found for ${_fromDateController.text} to ${_toDateController.text}. Try adjusting the date range.'),
              ),
            );
          }
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching attendance: $error');
      if (mounted) {
        setState(() {
          _attendanceList = []; // Clear list on exception
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No attendance records found for ${_fromDateController.text} to ${_toDateController.text}. Try adjusting the date range.'),
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context,
      TextEditingController controller, bool isFromDate) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        if (isFromDate) {
          _fromDate = pickedDate;
          _fromDateController.text =
              DateFormat('dd/MM/yyyy').format(pickedDate);
        } else {
          _toDate = pickedDate;
          _toDateController.text = DateFormat('dd/MM/yyyy').format(pickedDate);
        }
        // Ensure toDate is not before fromDate
        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
          _toDateController.text = DateFormat('dd/MM/yyyy').format(_toDate);
        }
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
    if (_attendanceList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance data to export')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create Excel workbook
      var excelWorkbook = excel.Excel.createExcel();
      var sheet = excelWorkbook['Sheet1'];

      // Define styles
      var headerStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
      var centerStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
      );
      var textStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
      );

      // Add header information (left-aligned)
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
          .value = excel.TextCellValue('Attendance Report');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1))
          .value = excel.TextCellValue('From Date: ${_fromDateController.text}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2))
          .value = excel.TextCellValue('To Date: ${_toDateController.text}');

      // Define headers (centered)
      final headers = [
        'Date',
        'In Time',
        'In Location',
        'Out Time',
        'Out Location',
        'Camp Name',
        'Office Work',
        'Camp Work',
        'Leave',
        'Remarks',
      ];
      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4));
        cell.value = excel.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Add data rows with specific alignment
      for (int row = 0; row < _attendanceList.length; row++) {
        final attendance = _attendanceList[row];

        String formattedDateTime = DateFormat('dd/MM/yyyy').format(
          DateTime.parse(attendance['attendance_date'].split(' ')[0]),
        );
        String inTime = attendance['in_time'] == "00:00:00"
            ? "Not Recorded"
            : DateFormat('hh:mm a')
                .format(DateFormat('HH:mm:ss').parse(attendance['in_time']));
        String outTime = attendance['out_time'] == "00:00:00"
            ? "Not Recorded"
            : DateFormat('hh:mm a')
                .format(DateFormat('HH:mm:ss').parse(attendance['out_time']));
        String inLocation =
            attendance['in_location']?.toString() ?? 'Not Available';
        String outLocation =
            attendance['out_location']?.toString() ?? 'Not Available';
        String campName = attendance['camp_name']?.toString() ?? 'N/A';
        String officeWork =
            attendance['status_of_work_office'] == 1 ? 'Yes' : 'No';
        String campWork = attendance['status_of_work_camp'] == 1 ? 'Yes' : 'No';
        String leave = attendance['status_of_work_leave'] == 1 ? 'Yes' : 'No';
        String remarks = attendance['remarks']?.toString() ?? 'N/A';

        final rowData = [
          formattedDateTime,
          inTime,
          inLocation,
          outTime,
          outLocation,
          campName,
          officeWork,
          campWork,
          leave,
          remarks,
        ];

        for (int col = 0; col < rowData.length; col++) {
          var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: row + 5));
          cell.value = excel.TextCellValue(rowData[col]);

          // Apply alignment
          if (col == 1 || col == 3) {
            // In Time, Out Time
            cell.cellStyle = centerStyle;
          } else {
            cell.cellStyle = textStyle; // Left-align others
          }
        }
      }

      // Save the file
      final outputDirectory = await _getSaveDirectory();
      final fileName =
          'attendance_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final filePath = '${outputDirectory.path}/$fileName';
      final file = File(filePath);
      await file.create(recursive: true);
      final excelBytes = excelWorkbook.encode();
      if (excelBytes == null) {
        throw Exception('Failed to encode Excel file');
      }
      await file.writeAsBytes(excelBytes);

      // Open the file
      final openResult = await OpenFile.open(filePath);
      if (openResult.type != ResultType.done) {
        print('Error opening Excel file: ${openResult.message}');
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
      print('Error generating Excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating Excel: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    if (_attendanceList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance data to export')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pdf = pw.Document();
      const pdfPageFormat = PdfPageFormat.a4;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pdfPageFormat,
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Attendance Report',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('From Date: ${_fromDateController.text}'),
              pw.Text('To Date: ${_toDateController.text}'),
              pw.SizedBox(height: 20),
            ],
          ),
          build: (pw.Context context) => [
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FractionColumnWidth(0.12), // Date
                1: const pw.FractionColumnWidth(0.1), // In Time
                2: const pw.FractionColumnWidth(0.18), // In Location
                3: const pw.FractionColumnWidth(0.1), // Out Time
                4: const pw.FractionColumnWidth(0.18), // Out Location
                5: const pw.FractionColumnWidth(0.1), // Camp Name
                6: const pw.FractionColumnWidth(0.08), // Office Work
                7: const pw.FractionColumnWidth(0.08), // Camp Work
                8: const pw.FractionColumnWidth(0.08), // Leave
                9: const pw.FractionColumnWidth(0.1), // Remarks
              },
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
              children: [
                // Header row
                pw.TableRow(
                  children: [
                    'Date',
                    'In Time',
                    'In Location',
                    'Out Time',
                    'Out Location',
                    'Camp Name',
                    'Office Work',
                    'Camp Work',
                    'Leave',
                    'Remarks',
                  ]
                      .map((header) => pw.Container(
                            alignment: pw.Alignment.center,
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              header,
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                          ))
                      .toList(),
                ),
                // Data rows
                ..._attendanceList.map((attendance) {
                  String formattedDateTime = DateFormat('dd/MM/yyyy').format(
                    DateTime.parse(attendance['attendance_date'].split(' ')[0]),
                  );
                  String inTime = attendance['in_time'] == "00:00:00"
                      ? "Not Recorded"
                      : DateFormat('hh:mm a').format(
                          DateFormat('HH:mm:ss').parse(attendance['in_time']));
                  String outTime = attendance['out_time'] == "00:00:00"
                      ? "Not Recorded"
                      : DateFormat('hh:mm a').format(
                          DateFormat('HH:mm:ss').parse(attendance['out_time']));
                  String inLocation =
                      attendance['in_location']?.toString() ?? 'Not Available';
                  String outLocation =
                      attendance['out_location']?.toString() ?? 'Not Available';
                  String campName =
                      attendance['camp_name']?.toString() ?? 'N/A';
                  String officeWork =
                      attendance['status_of_work_office'] == 1 ? 'Yes' : 'No';
                  String campWork =
                      attendance['status_of_work_camp'] == 1 ? 'Yes' : 'No';
                  String leave =
                      attendance['status_of_work_leave'] == 1 ? 'Yes' : 'No';
                  String remarks = attendance['remarks']?.toString() ?? 'N/A';

                  return pw.TableRow(
                    children: [
                      pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(formattedDateTime)),
                      pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(inTime)),
                      pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(inLocation)),
                      pw.Container(
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(outTime)),
                      pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(outLocation)),
                      pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(campName)),
                      pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(officeWork)),
                      pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(campWork)),
                      pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(leave)),
                      pw.Container(
                          alignment: pw.Alignment.centerLeft,
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(remarks)),
                    ],
                  );
                }).toList(),
              ],
            ),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child:
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
          ),
        ),
      );

      final outputDirectory = await _getSaveDirectory();
      final file = File(
          '${outputDirectory.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to ${file.path}')),
        );
      }
    } catch (e) {
      print('Error generating PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.8,
            child: Stack(
              children: [
                Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (BuildContext context, Widget child,
                        ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Loading...',
                              style:
                                  TextStyle(color: Colors.black, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.red,
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text("Attendance Report",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.white),
            onPressed: _downloadExcel,
            tooltip: 'Download Excel',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _downloadPdf,
            tooltip: 'Download PDF',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade300, blurRadius: 5),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _fromDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "From Date",
                        labelStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 6),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today,
                              color: Colors.green, size: 18),
                          onPressed: () =>
                              _selectDate(context, _fromDateController, true),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _toDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "To Date",
                        labelStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 6),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today,
                              color: Colors.green, size: 18),
                          onPressed: () =>
                              _selectDate(context, _toDateController, false),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_fromDate.isAfter(_toDate)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('From Date cannot be after To Date')),
                          );
                          return;
                        }
                        _fetchAttendance();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.search,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'From Date: ${_fromDateController.text}  |  To Date: ${_toDateController.text}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF28A746)))
                  : _attendanceList.isEmpty
                      ? Center(
                          child: Text(
                            "No attendance records found for the selected date range. Try adjusting the date range.",
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[900]),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _attendanceList.length,
                          itemBuilder: (context, index) {
                            final attendance = _attendanceList[index];

                            String formattedDateTime =
                                DateFormat('dd/MM/yyyy').format(
                              DateTime.parse(
                                  attendance['attendance_date'].split(' ')[0]),
                            );

                            String inTime = attendance['in_time'] == "00:00:00"
                                ? "Not Recorded"
                                : DateFormat('hh:mm a').format(
                                    DateFormat('HH:mm:ss')
                                        .parse(attendance['in_time']));

                            String outTime =
                                attendance['out_time'] == "00:00:00"
                                    ? "Not Recorded"
                                    : DateFormat('hh:mm a').format(
                                        DateFormat('HH:mm:ss')
                                            .parse(attendance['out_time']));

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                              shadowColor: Colors.grey.shade200,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Date: $formattedDateTime",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.grey[900]),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "In Time Attendance",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Color.fromARGB(255, 10, 10, 10)),
                                    ),
                                    Divider(
                                      color: Colors.grey[900],
                                      thickness: 0.5,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildSection(
                                      icon: Icons.timer,
                                      iconColor: Colors.blue,
                                      title: "In Time",
                                      value: inTime,
                                      imageUrl: attendance['in_picture'],
                                      location: attendance['in_location'],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "Out Time Attendance",
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromARGB(255, 7, 7, 7)),
                                    ),
                                    Divider(
                                      color: Colors.grey[900],
                                      thickness: 0.5,
                                    ),
                                    _buildSection(
                                      icon: Icons.timer_off,
                                      iconColor: Colors.red,
                                      title: "Out Time",
                                      value: outTime,
                                      imageUrl: attendance['out_picture'],
                                      location: attendance['out_location'],
                                    ),
                                    const SizedBox(height: 12),
                                    if (designationCategory == 'MANAGER') ...[
                                      if (attendance['camp_name'] != null &&
                                          attendance['camp_name']
                                              .toString()
                                              .isNotEmpty) ...[
                                        Row(
                                          children: [
                                            Icon(Icons.location_on,
                                                color: Colors.orange.shade400),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Camp: ${attendance['camp_name']}",
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blueGrey),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      if (attendance['branch_name'] !=
                                          "No Branch Assigned") ...[
                                        Row(
                                          children: [
                                            Icon(Icons.business,
                                                color: Colors.orange.shade400),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Office Name: ${attendance['branch_name']}",
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blueGrey),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildStatusIcon(
                                            label: "Office Work",
                                            status: attendance[
                                                'status_of_work_office'],
                                          ),
                                          _buildStatusIcon(
                                            label: "Camp Work",
                                            status: attendance[
                                                'status_of_work_camp'],
                                          ),
                                          _buildStatusIcon(
                                            label: "Leave",
                                            status: attendance[
                                                'status_of_work_leave'],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.comment,
                                            color: Colors.blue.shade400),
                                          const SizedBox(width: 8),
                                          Flexible(
                                          child: Text(
                                            "Remarks: ${attendance['remarks'] ?? 'N/A'}",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.blueGrey),
                                            softWrap: true,
                                            overflow: TextOverflow.visible,
                                          ),
                                          ),
                                       
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? imageUrl,
    String? location,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              "$title: $value",
              style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
            ),
          ],
        ),
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              _showImageDialog(
                context,
                "https://www.nabeenkishan.net.in/AttendancePicture/$imageUrl",
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text(
              "View Image",
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
          ),
        ],
        if (location != null && location.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            "Location:",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            location,
            style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIcon({required String label, required int status}) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 4),
        Icon(
          status == 1 ? Icons.check_circle : Icons.cancel,
          color: status == 1 ? Colors.green : Colors.red,
          size: 20,
        ),
      ],
    );
  }
}
