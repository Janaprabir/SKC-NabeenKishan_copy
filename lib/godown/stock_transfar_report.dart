import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel;
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class ReportStockTransfer extends StatefulWidget {
  const ReportStockTransfer({super.key});

  @override
  _ReportStockTransferState createState() => _ReportStockTransferState();
}

class _ReportStockTransferState extends State<ReportStockTransfer> {
  String? _empId;
  int? godownId;
  List<Map<String, dynamic>> _records = [];
  final List<String> _columns = [
    'Date',
    'Bill no',
    'DCN',
    'Remarks',
    'Source Godown',
    'Destination Godown',
    'Product Name',
    'Quantity',
    'Pre Stock Level',
    'New Stock Level',
  ];
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController billNoController = TextEditingController();
  final TextEditingController dcnController = TextEditingController();
  bool _isLoading = false;
  String? godownName;
  String? keeperName;

  @override
  void initState() {
    super.initState();
    // Set both from and to date to the current date
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _fromDateController.text = currentDate;
    _toDateController.text = currentDate;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadSessionData().then((_) {
      _loadGodownId().then((_) {
        _fetchData(); // Fetch data for the current date
      });
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _fromDateController.dispose();
    _toDateController.dispose();
    billNoController.dispose();
    dcnController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empId = prefs.getString('emp_id');
    });
  }

  Future<void> _loadGodownId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      godownId = prefs.getInt('godown_id');
    });
  }

  Future<void> _fetchData() async {
    if (_empId == null || godownId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _empId == null ? 'Employee ID not found' : 'Godown ID not found'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    const String baseUrl =
        'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/get_stock_transfer_report.php';

    String fromDateApi;
    String toDateApi;
    try {
      fromDateApi = DateFormat('yyyy-MM-dd')
          .format(DateFormat('dd/MM/yyyy').parse(_fromDateController.text));
      toDateApi = DateFormat('yyyy-MM-dd')
          .format(DateFormat('dd/MM/yyyy').parse(_toDateController.text));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid date format')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final Map<String, String> parameters = {
      'godown_id': godownId.toString(),
      'src_godown_id': godownId.toString(),
      'dest_godown_id': '',
      'from_date': fromDateApi,
      'to_date': toDateApi,
      'bill_no': billNoController.text,
      'dcn': dcnController.text,
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);
    print('Fetching from: $uri'); // Debug

    try {
      final response = await http.get(uri);
      print('Status Code: ${response.statusCode}'); // Debug
      print('Response Body: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          _records.clear();
          godownName = data.isNotEmpty ? data[0]['src_godown_name'] : null;
          keeperName = data.isNotEmpty ? data[0]['keeper_name'] : null;

          // Group transactions by Bill No
          Map<String, Map<String, dynamic>> billGroups = {};
          for (var transferEntry in data) {
            String formattedDate = '';
            if (transferEntry['stock_transfer_date']?.isNotEmpty ?? false) {
              try {
                DateTime date =
                    DateTime.parse(transferEntry['stock_transfer_date']);
                formattedDate = DateFormat('dd/MM/yyyy').format(date);
              } catch (e) {
                formattedDate = transferEntry['stock_transfer_date'] ?? '';
              }
            }

            String billNo = transferEntry['bill_no'] ?? '';
            if (!billGroups.containsKey(billNo)) {
              billGroups[billNo] = {
                'Date': formattedDate,
                'Bill no': billNo,
                'DCN': transferEntry['dcn'] ?? '',
                'Remarks': transferEntry['remarks'] ?? '',
                'Source Godown': transferEntry['src_godown_name'] ?? '',
                'Destination Godown': transferEntry['dest_godown_name'] ?? '',
                'Transactions': [],
              };
            }

            for (var transaction in transferEntry['transactions']) {
              billGroups[billNo]?['Transactions'].add({
                'Product Name': transaction['product_name'] ?? '',
                'Quantity': transaction['quantity']?.toString() ?? '',
                'Pre Stock Level': transaction['pre_stock_level']?.toString() ?? '',
                'New Stock Level': transaction['new_stock_level']?.toString() ?? '',
                'Transaction Time': transaction['transaction_created_at'] ?? '',
              });
            }
          }

          // Flatten the grouped data for display
          for (var bill in billGroups.values) {
            for (var transaction in bill['Transactions']) {
              _records.add({
                'Date': bill['Date'],
                'Bill no': bill['Bill no'],
                'DCN': bill['DCN'],
                'Remarks': bill['Remarks'],
                'Source Godown': bill['Source Godown'],
                'Destination Godown': bill['Destination Godown'],
                'Product Name': transaction['Product Name'],
                'Quantity': transaction['Quantity'],
                'Pre Stock Level': transaction['Pre Stock Level'],
                'New Stock Level': transaction['New Stock Level'],
                'Transaction Time': transaction['Transaction Time'],
                'IsBillHeader': bill['Transactions'].indexOf(transaction) == 0,
              });
            }
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch data')),
        );
      }
    } catch (e) {
      print('Exception: $e'); // Debug
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generatePdf() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pdf = pw.Document();
      final pdfPageFormat = PdfPageFormat.a4.landscape;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pdfPageFormat,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#28A746'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Stock Transfer Report',
                    style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                pw.SizedBox(height: 8),
                pw.Text('Godown: ${godownName ?? 'N/A'}',
                    style: const pw.TextStyle(
                        fontSize: 14, color: PdfColors.white)),
                pw.Text('Keeper: ${keeperName ?? 'N/A'}',
                    style: const pw.TextStyle(
                        fontSize: 14, color: PdfColors.white)),
                pw.Text(
                    'From: ${_fromDateController.text} - To: ${_toDateController.text}',
                    style: const pw.TextStyle(
                        fontSize: 14, color: PdfColors.white)),
                pw.Text(
                    'Bill No: ${billNoController.text.isEmpty ? 'N/A' : billNoController.text}',
                    style: const pw.TextStyle(
                        fontSize: 14, color: PdfColors.white)),
                pw.Text(
                    'DCN: ${dcnController.text.isEmpty ? 'N/A' : dcnController.text}',
                    style: const pw.TextStyle(
                        fontSize: 14, color: PdfColors.white)),
              ],
            ),
          ),
          build: (pw.Context context) => [
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FractionColumnWidth(0.10), // Date
                1: const pw.FractionColumnWidth(0.10), // Bill no
                2: const pw.FractionColumnWidth(0.10), // DCN
                3: const pw.FractionColumnWidth(0.12), // Remarks
                4: const pw.FractionColumnWidth(0.12), // Source Godown
                5: const pw.FractionColumnWidth(0.12), // Destination Godown
                6: const pw.FractionColumnWidth(0.14), // Product Name
                7: const pw.FractionColumnWidth(0.10), // Quantity
                8: const pw.FractionColumnWidth(0.10), // Pre Stock Level
                9: const pw.FractionColumnWidth(0.10), // New Stock Level
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey100),
                  children: _columns.map((column) => pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          column,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10),
                          textAlign: pw.TextAlign.center,
                        ),
                      )).toList(),
                ),
                ..._records.map((record) => pw.TableRow(
                      children: _columns.map((column) {
                        final alignment = (column == 'Quantity' ||
                                column == 'Pre Stock Level' ||
                                column == 'New Stock Level')
                            ? pw.TextAlign.right
                            : (column == 'Bill no' || column == 'DCN')
                                ? pw.TextAlign.center
                                : pw.TextAlign.left;
                        // Show bill-level fields only on the first transaction
                        final text = (column == 'Date' ||
                                column == 'Bill no' ||
                                column == 'DCN' ||
                                column == 'Remarks' ||
                                column == 'Source Godown' ||
                                column == 'Destination Godown') &&
                            !record['IsBillHeader']
                            ? ''
                            : record[column] ?? '';
                        return pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            text,
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: alignment,
                          ),
                        );
                      }).toList(),
                    )),
              ],
            ),
          ],
          footer: (context) => pw.Container(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
              ],
            ),
          ),
        ),
      );

      final outputDirectory = await getExternalStorageDirectory();
      final file = File(
          '${outputDirectory?.path}/stock_transfer_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF Generated Successfully')),
        );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Failed to generate PDF: $e')),
      // );
    } finally {
      setState(() {
        _isLoading = false;
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
                content:
                    Text('Downloads folder unavailable, using alternative directory')),
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

  Future<void> _generateExcel() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var excelWorkbook = excel.Excel.createExcel();
      var sheet = excelWorkbook['Sheet1'];

      // Define styles
      var headerStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
      var numberStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Right,
      );
      var centerStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
      );
      var textStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Left,
      );

      // Add header information
      sheet.merge(
          excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          excel.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: 0));
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = excel.TextCellValue('Stock Transfer Report');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .cellStyle = excel.CellStyle(bold: true, fontSize: 16);

      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          .value = excel.TextCellValue('Godown: ${godownName ?? 'N/A'}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
          .value = excel.TextCellValue('Keeper: ${keeperName ?? 'N/A'}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
          .value = excel.TextCellValue('From Date: ${_fromDateController.text}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4))
          .value = excel.TextCellValue('To Date: ${_toDateController.text}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 5))
          .value = excel.TextCellValue(
              'Bill No: ${billNoController.text.isEmpty ? 'N/A' : billNoController.text}');
      sheet
          .cell(excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 6))
          .value = excel.TextCellValue(
              'DCN: ${dcnController.text.isEmpty ? 'N/A' : dcnController.text}');

      // Add table headers
      for (int i = 0; i < _columns.length; i++) {
        var cell = sheet.cell(
            excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 8));
        cell.value = excel.TextCellValue(_columns[i]);
        cell.cellStyle = headerStyle;
      }

      // Add data rows
      for (int row = 0; row < _records.length; row++) {
        final record = _records[row];
        for (int col = 0; col < _columns.length; col++) {
          var cell = sheet.cell(excel.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: row + 9));
          // Show bill-level fields only on the first transaction
          final value = (_columns[col] == 'Date' ||
                  _columns[col] == 'Bill no' ||
                  _columns[col] == 'DCN' ||
                  _columns[col] == 'Remarks' ||
                  _columns[col] == 'Source Godown' ||
                  _columns[col] == 'Destination Godown') &&
              !record['IsBillHeader']
              ? ''
              : record[_columns[col]] ?? '';
          cell.value = excel.TextCellValue(value);

          if (_columns[col] == 'Quantity' ||
              _columns[col] == 'Pre Stock Level' ||
              _columns[col] == 'New Stock Level') {
            cell.cellStyle = numberStyle;
          } else if (_columns[col] == 'Bill no' || _columns[col] == 'DCN') {
            cell.cellStyle = centerStyle;
          } else {
            cell.cellStyle = textStyle;
          }
        }
      }

      // Auto-fit columns
      for (int i = 0; i < _columns.length; i++) {
        sheet.setColumnAutoFit(i);
      }

      final outputDirectory = await _getSaveDirectory();
      final fileName =
          'stock_transfer_report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate Excel')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context,
      TextEditingController controller, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? (_fromDate ?? DateTime.now())
          : (_toDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF28A746),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF28A746),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          controller.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          _toDate = picked;
          controller.text = DateFormat('dd/MM/yyyy').format(picked);
        }
      });
    }
  }

  void _showFilterDialog() {
    final ScrollController _scrollController = ScrollController();
    final FocusNode _billNoFocusNode = FocusNode();
    final FocusNode _dcnFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final double dialogWidth = screenWidth * 0.45;
        const double dialogMinHeight = 400;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final double dialogHeight = dialogMinHeight + keyboardHeight;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  minHeight: dialogMinHeight,
                  maxHeight:
                      dialogHeight > dialogMinHeight ? dialogHeight : dialogMinHeight,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Filter Reports',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF28A746),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _fromDateController,
                          decoration: InputDecoration(
                            labelText: 'From Date',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF28A746)),
                            ),
                            suffixIcon:
                                const Icon(Icons.calendar_today, color: Color(0xFF28A746)),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, _fromDateController, true),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _toDateController,
                          decoration: InputDecoration(
                            labelText: 'To Date',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF28A746)),
                            ),
                            suffixIcon:
                                const Icon(Icons.calendar_today, color: Color(0xFF28A746)),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, _toDateController, false),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: billNoController,
                          focusNode: _billNoFocusNode,
                          decoration: InputDecoration(
                            labelText: 'Bill No',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF28A746)),
                            ),
                            prefixIcon: const Icon(Icons.receipt, color: Color(0xFF28A746)),
                          ),
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Z]')),
                          ],
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          onTap: () {
                            Future.delayed(const Duration(milliseconds: 300), () {
                              setState(() {});
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: dcnController,
                          focusNode: _dcnFocusNode,
                          decoration: InputDecoration(
                            labelText: 'DCN',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF28A746)),
                            ),
                            prefixIcon: const Icon(Icons.document_scanner, color: Color(0xFF28A746)),
                          ),
                          keyboardType: TextInputType.text,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Z]')),
                          ],
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          onTap: () {
                            Future.delayed(const Duration(milliseconds: 300), () {
                              setState(() {});
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                backgroundColor: const Color(0xFF28A746),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () {
                                _fetchData();
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Apply Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _billNoFocusNode.dispose();
      _dcnFocusNode.dispose();
      _scrollController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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
              Navigator.pop(context, '/home_page_godown');
            });
          },
        ),
        title: const Text(
          'Stock Transfer Report',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _generatePdf,
            tooltip: 'Download PDF',
          ),
          IconButton(
            icon: const Icon(Icons.table_chart, color: Colors.white),
            onPressed: _generateExcel,
            tooltip: 'Download Excel',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28A746)))
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000), // Set max width for the card
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_records.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _buildInfoChip('Godown', godownName ?? 'N/A'),
                                _buildInfoChip('Keeper', keeperName ?? 'N/A'),
                                _buildInfoChip('From Date', _fromDateController.text),
                                _buildInfoChip('To Date', _toDateController.text),
                                _buildInfoChip('Bill No',
                                    billNoController.text.isEmpty ? 'N/A' : billNoController.text),
                                _buildInfoChip('DCN',
                                    dcnController.text.isEmpty ? 'N/A' : dcnController.text),
                              ],
                            ),
                          ],
                          const SizedBox(height: 24),
                          Expanded(
                            child: _records.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inventory_2,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No records found\nApply filters to fetch data',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: DataTable(
                                        headingRowHeight: 48,
                                        dataRowHeight: 48,
                                        headingRowColor: MaterialStateProperty.all(
                                            const Color(0xFF28A746).withOpacity(0.1)),
                                        dataRowColor:
                                            MaterialStateProperty.all(Colors.white),
                                        columnSpacing: 12, // Reduced to fit 10 columns
                                        border: TableBorder(
                                          horizontalInside:
                                              BorderSide(color: Colors.grey[200]!),
                                          verticalInside:
                                              BorderSide(color: Colors.grey[200]!),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        columns: _columns
                                            .map((column) => DataColumn(
                                                  label: Text(
                                                    column,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF28A746),
                                                      fontSize: 11, // Reduced for 10 columns
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                        rows: _records.map((record) {
                                          return DataRow(
                                            cells: _columns.map((column) {
                                              // Show bill-level fields only on the first transaction
                                              final text = (column == 'Date' ||
                                                      column == 'Bill no' ||
                                                      column == 'DCN' ||
                                                      column == 'Remarks' ||
                                                      column == 'Source Godown' ||
                                                      column == 'Destination Godown') &&
                                                  !record['IsBillHeader']
                                                  ? ''
                                                  : record[column] ?? '';
                                              return DataCell(
                                                Text(
                                                  text,
                                                  style: TextStyle(
                                                    color: Colors.grey[800],
                                                    fontSize: 10, // Reduced for 10 columns
                                                    fontWeight: (column == 'Date' ||
                                                            column == 'Bill no' ||
                                                            column == 'DCN' ||
                                                            column == 'Remarks' ||
                                                            column == 'Source Godown' ||
                                                            column == 'Destination Godown') &&
                                                        record['IsBillHeader']
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
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
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF28A746),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}