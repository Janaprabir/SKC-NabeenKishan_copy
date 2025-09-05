import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'dart:async';

class StockReturnPage extends StatefulWidget {
  @override
  _StockReturnPageState createState() => _StockReturnPageState();
}

class Employee {
  final String empId;
  final String eCode;
  final String firstName;
  final String middleName;
  final String lastName;
  final String shortDesignation;
  final String branchName;

  Employee({
    required this.empId,
    required this.eCode,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.shortDesignation,
    required this.branchName,
  });

  @override
  String toString() {
    return '$eCode - $firstName $middleName $lastName - $shortDesignation - ($branchName)';
  }
}

class _StockReturnPageState extends State<StockReturnPage> {
  List<Employee> employees = [];
  List<Map<String, String>> products = [];
  List<Map<String, dynamic>> currentStock = [];
  List<Map<String, dynamic>> stockReturnEntries = [];
  List<Map<String, String>> selectedProducts = [];
  String? selectedEmpId;
  String? selectedProduct;
  TextEditingController quantityController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController dcReturnController = TextEditingController();
  TextEditingController srsNoController = TextEditingController();
  TextEditingController truckNoController = TextEditingController();
  TextEditingController tripNoController = TextEditingController();
  TextEditingController remarksController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  int? godownId;
  String? _empId;
  bool isLoading = true;
  bool _isSubmitting = false;
  bool _isFetchingEmployees = false;
  bool _isFetchingProducts = false;
  bool _isFetchingEntries = false;
  bool _isFetchingTransactions = false;
  bool _isDeleting = false;
  bool _isReadOnlyMode = false;

  @override
  void initState() {
    super.initState();
    fetchEmployees();
    fetchProducts();
    _loadGodownId();
    _loadSessionData();
  }

  Future<bool> checkProductInTransactions(
      String stockReturnId, String productId) async {
    try {
      final url =
          'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/get_stock_return_transactions.php?stock_return_id=$stockReturnId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('transactions')) {
          final data = responseBody['transactions'] as List;
          return data.any((transaction) =>
              transaction['product_id'].toString() == productId);
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception('Failed to fetch transactions for product check');
      }
    } catch (e) {
      print('Error checking product in transactions: $e');
      return false;
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    addressController.dispose();
    dcReturnController.dispose();
    srsNoController.dispose();
    truckNoController.dispose();
    tripNoController.dispose();
    remarksController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchEmployees() async {
    if (godownId == null) {
      await _loadGodownId();
    }
    setState(() => _isFetchingEmployees = true);
    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/CampController/getCampEmployees.php?godown_id=$godownId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final employeeList = data['employees'] as List;
          setState(() {
            employees = employeeList.map((employee) {
              return Employee(
                empId: employee['emp_id'].toString(),
                eCode: employee['e_code'].toString(),
                firstName: employee['full_name'].toString().split(' ')[0],
                middleName: '',
                lastName: employee['full_name']
                    .toString()
                    .split(' ')
                    .sublist(1)
                    .join(' '),
                shortDesignation: employee['short_designation'].toString(),
                branchName: employee['branch_name'].toString(),
              );
            }).toList();
          });
        } else {
          throw Exception('API returned success: false');
        }
      } else {
        throw Exception('Failed to load employee data');
      }
    } catch (e) {
      print('Error loading employees: $e');
    } finally {
      setState(() => _isFetchingEmployees = false);
    }
  }

  Future<void> fetchCampAddress(String empId) async {
    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/CampController/getCampAddress.php?emp_id=$empId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('camp_address')) {
          setState(() {
            addressController.text = data['camp_address'].toString();
          });
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('Failed to load camp address');
      }
    } catch (e) {
      print('Error fetching camp address: $e');
    }
  }

  Future<void> fetchProducts() async {
    setState(() => _isFetchingProducts = true);
    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/MasterController/masterRoutes.php?action=getAllProducts'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          products = data.map((product) {
            return {
              'product_name': product['product_name'].toString(),
              'product_id': product['product_id'].toString(),
            };
          }).toList();
        });
      } else {
        throw Exception('Failed to load products data');
      }
    } catch (e) {
      print('Error loading products: $e');
    } finally {
      setState(() => _isFetchingProducts = false);
    }
  }

  Future<void> _loadGodownId() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      godownId = prefs.getInt('godown_id');
    });
    if (godownId != null) {
      await _fetchCurrentStock(godownId!);
      await _fetchStockReturnEntries();
      await fetchEmployees();
    }
    setState(() => isLoading = false);
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empId = prefs.getString('emp_id');
    });
  }

  Future<void> _fetchCurrentStock(int godownId) async {
    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/GodownStockController/currentGodownStock.php?godown_id=$godownId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          currentStock = data
              .map((stock) => {
                    'product_id': stock['product_id'].toString(),
                    'quantity': int.parse(stock['quantity'].toString()),
                    'product_name': stock['product_name'],
                  })
              .toList();
        });
      } else {
        throw Exception('Failed to load current stock');
      }
    } catch (e) {
      print('Error loading current stock: $e');
    }
  }

  Future<void> _fetchStockReturnEntries() async {
    setState(() => _isFetchingEntries = true);
    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/get_all_stock_return_entries.php?limit=300&godown_id=$godownId'));
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('entries')) {
          final data = responseBody['entries'] as List;
          setState(() {
            stockReturnEntries = data.map((entry) {
              String formattedDate = '';
              if (entry['stock_return_date'] != null &&
                  entry['stock_return_date'].isNotEmpty) {
                try {
                  DateTime date = DateTime.parse(entry['stock_return_date']);
                  formattedDate =
                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                } catch (e) {
                  formattedDate = entry['stock_return_date'].toString();
                }
              }
              return <String, Object>{
                'stock_return_id': entry['stock_return_id'].toString(),
                'stock_return_date': formattedDate,
                'godown_id': entry['godown_id'].toString(),
                'godown_name': entry['godown_name']?.toString() ?? '',
                'grn_no': entry['grn_no']?.toString() ?? '',
                'emp_id': entry['emp_id'].toString(),
                'emp_name':
                    '${entry['emp_first_name']} ${entry['emp_middle_name']} ${entry['emp_last_name']}'
                        .trim(),
                'emp_ecode': entry['emp_ecode']?.toString() ?? '',
                'address': entry['address']?.toString() ?? '',
                'dc_retrun': entry['dc_retrun']?.toString() ?? '',
                'srs_no': entry['srs_no']?.toString() ?? '',
                'truck_no': entry['truck_no']?.toString() ?? '',
                'trip_no': entry['trip_no']?.toString() ?? '',
                'remarks': entry['remarks']?.toString() ?? '',
                'entry_created_at': entry['entry_created_at']?.toString() ?? '',
                'updated_at': entry['updated_at']?.toString() ?? '',
                'isExpanded': false,
                'transactions': <Map<String, Object>>[],
                'isFetchingTransactions': false,
              };
            }).toList();
          });
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception('Failed to load stock return entries');
      }
    } catch (e) {
      print('Error fetching stock return entries: $e');
    } finally {
      setState(() => _isFetchingEntries = false);
    }
  }

  Future<void> _fetchStockReturnTransactions(
      String stockReturnId, int entryIndex) async {
    setState(() {
      stockReturnEntries[entryIndex]['isFetchingTransactions'] = true;
    });
    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/get_stock_return_transactions.php?stock_return_id=$stockReturnId'));
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('transactions')) {
          final data = responseBody['transactions'] as List;
          setState(() {
            stockReturnEntries[entryIndex]['transactions'] =
                data.map((transaction) {
              return {
                'stock_transaction_id':
                    transaction['stock_transaction_id'].toString(),
                'stock_return_id': transaction['stock_return_id'].toString(),
                'product_id': transaction['product_id'].toString(),
                'product_name': transaction['product_name']?.toString() ?? '',
                'quantity': transaction['quantity'].toString(),
                'transaction_created_at':
                    transaction['transaction_created_at']?.toString() ?? '',
                'pre_stock_level':
                    transaction['pre_stock_level']?.toString() ?? '',
                'new_stock_level':
                    transaction['new_stock_level']?.toString() ?? '',
              };
            }).toList();
          });
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception('Failed to load stock return transactions');
      }
    } catch (e) {
      print('Error fetching stock return transactions: $e');
    } finally {
      setState(() {
        stockReturnEntries[entryIndex]['isFetchingTransactions'] = false;
      });
    }
  }

  Future<bool> _showConfirmDeleteDialog(
      String type, String identifier, String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DeleteConfirmationDialog(
        type: type,
        identifier: identifier,
        id: id,
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteStockReturnEntry(String stockReturnId) async {
    setState(() => _isDeleting = true);
    try {
      final url = Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/delete_stock_return_entry.php?stock_return_id=$stockReturnId');
      final response = await http.delete(url);
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Stock return entry deleted successfully.')),
        );
        setState(() {
          stockReturnEntries.removeWhere(
              (entry) => entry['stock_return_id'] == stockReturnId);
        });
        await _fetchCurrentStock(godownId!);
      } else {
        throw Exception('Failed to delete stock return entry');
      }
    } catch (e) {
      print('Error deleting stock return entry: $e');
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  Future<void> _deleteTransaction(String transactionId, int entryIndex) async {
    setState(() => _isDeleting = true);
    try {
      final url = Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/delete_stock_return_transaction.php?stock_transaction_id=$transactionId');
      final response = await http.delete(url);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted successfully.')),
        );
        await _fetchStockReturnTransactions(
            stockReturnEntries[entryIndex]['stock_return_id'], entryIndex);
        await _fetchCurrentStock(godownId!);
      } else {
        throw Exception('Failed to delete transaction');
      }
    } catch (e) {
      print('Error deleting transaction: $e');
    } finally {
      setState(() => _isDeleting = false);
    }
  }

  void _populateFormForExistingEntry({
    required String stockReturnId,
    required String address,
    required String dcReturn,
    required String srsNo,
    required String truckNo,
    required String tripNo,
    required String remarks,
    required int entryIndex,
  }) {
    setState(() {
      _isReadOnlyMode = true;
      addressController.text = address;
      dcReturnController.text = dcReturn;
      srsNoController.text = srsNo;
      truckNoController.text = truckNo;
      tripNoController.text = tripNo;
      remarksController.text = remarks;
      selectedEmpId = stockReturnEntries[entryIndex]['emp_id'];
      selectedProducts.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Form populated with existing entry details in read-only mode.')),
    );
  }

  Future<void> _showEditStockReturnEntryDialog(
    String stockReturnId, BuildContext context, Function fetchEntries) async {
    bool isLoading = false;
    bool isDialogActive = true;
    Map<String, dynamic> entry = {};

    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/get_stock_return_entry.php?stock_return_id=$stockReturnId'));
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('entry')) {
          entry = responseBody['entry'];
          if (entry.isEmpty) {
            throw Exception('No data returned for stock return entry');
          }
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to fetch stock return entry: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching stock return entry: $e');
      return;
    }

    final TextEditingController editDcReturnController =
        TextEditingController(text: entry['dc_retrun']?.toString() ?? '');
    final TextEditingController editSrsNoController =
        TextEditingController(text: entry['srs_no']?.toString() ?? '');
    final TextEditingController editTruckNoController =
        TextEditingController(text: entry['truck_no']?.toString() ?? '');
    final TextEditingController editTripNoController =
        TextEditingController(text: entry['trip_no']?.toString() ?? '');
    final TextEditingController editRemarksController =
        TextEditingController(text: entry['remarks']?.toString() ?? '');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Stock Return Entry',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        isDialogActive = false;
                        editDcReturnController.dispose();
                        editSrsNoController.dispose();
                        editTruckNoController.dispose();
                        editTripNoController.dispose();
                        editRemarksController.dispose();
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFF28A746)),
                  )
                else
                  Column(
                    children: [
                      TextField(
                        controller: editDcReturnController,
                        decoration: InputDecoration(
                          labelText: 'DC Return',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF28A746), width: 2),
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editSrsNoController,
                        decoration: InputDecoration(
                          labelText: 'SRS No',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF28A746), width: 2),
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editTruckNoController,
                        decoration: InputDecoration(
                          labelText: 'Truck No',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF28A746), width: 2),
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editTripNoController,
                        decoration: InputDecoration(
                          labelText: 'Trip No',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF28A746), width: 2),
                          ),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editRemarksController,
                        decoration: InputDecoration(
                          labelText: 'Remarks',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF28A746), width: 2),
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        isDialogActive = false;
                        editDcReturnController.dispose();
                        editSrsNoController.dispose();
                        editTruckNoController.dispose();
                        editTripNoController.dispose();
                        editRemarksController.dispose();
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        setDialogState(() => isLoading = true);
                        try {
                          final updatedData = {
                            'stock_return_id': stockReturnId,
                            'dc_retrun': editDcReturnController.text,
                            'srs_no': editSrsNoController.text,
                            'truck_no': editTruckNoController.text,
                            'trip_no': editTripNoController.text,
                            'remarks': editRemarksController.text,
                          };
                          final response = await http.post(
                            Uri.parse(
                                'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/update_stock_return_entry.php'),
                            body: updatedData,
                            headers: {
                              'Content-Type': 'application/x-www-form-urlencoded'
                            },
                          );
                          if (response.statusCode == 200) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Stock return entry updated successfully.')),
                            );
                            await fetchEntries();
                            isDialogActive = false;
                            editDcReturnController.dispose();
                            editSrsNoController.dispose();
                            editTruckNoController.dispose();
                            editTripNoController.dispose();
                            editRemarksController.dispose();
                            Navigator.of(dialogContext).pop();
                          } else {
                            throw Exception(
                                'Failed to update stock return entry: ${response.body}');
                          }
                        } catch (e) {
                          if (isDialogActive) {
                            print('Error updating stock return entry: $e');
                          }
                        } finally {
                          if (isDialogActive) {
                            setDialogState(() => isLoading = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28A746),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Update',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
  }

  Future<void> _showEditStockTransactionDialog({
    required String stockTransactionId,
    required int entryIndex,
    required String stockReturnId,
    required String productName,
    required BuildContext parentContext,
    required Function(String, int) fetchTransactions,
    required Function fetchCurrentStock,
    required List<Map<String, dynamic>> currentStock,
    required String godownId,
  }) async {
    bool isLoading = false;
    bool isDialogActive = true;
    Map<String, dynamic> transaction = {};
    String? errorMessage;

    try {
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/get_stock_return_transaction.php?stock_transaction_id=$stockTransactionId'));
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('transaction')) {
          transaction = responseBody['transaction'];
          if (transaction.isEmpty) {
            throw Exception('No data returned for transaction');
          }
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to fetch transaction: ${response.statusCode}');
      }
    } catch (e) {
      if (isDialogActive) {
        print('Error fetching transaction: $e');
      }
      return;
    }

    final TextEditingController editQuantityController =
        TextEditingController(text: transaction['quantity']?.toString() ?? '');
    final String displayProductName =
        transaction['product_name']?.toString() ?? productName;

    await showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Transaction',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        isDialogActive = false;
                        editQuantityController.dispose();
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFF28A746)),
                  )
                else
                  Column(
                    children: [
                      TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: '$displayProductName',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF28A746), width: 2),
                          ),
                          hintText: displayProductName,
                          hintStyle: TextStyle(color: Colors.grey.shade800),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editQuantityController,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF28A746), width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red, width: 2),
                          ),
                          errorText: errorMessage,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        isDialogActive = false;
                        editQuantityController.dispose();
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (!isDialogActive) return;
                        final quantity = int.tryParse(editQuantityController.text);
                        if (quantity == null || quantity <= 0) {
                          setDialogState(() {
                            errorMessage = 'Enter a valid quantity';
                          });
                          return;
                        }

                        final productId = transaction['product_id']?.toString();
                        if (productId == null || productId.isEmpty) {
                          setDialogState(() {
                            errorMessage = 'Invalid product ID';
                          });
                          return;
                        }

                        setDialogState(() => isLoading = true);
                        try {
                          final updatedData = {
                            'stock_transaction_id': stockTransactionId,
                            'quantity': quantity.toString(),
                          };
                          final response = await http.post(
                            Uri.parse(
                                'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/update_stock_return_transaction.php'),
                            body: updatedData,
                            headers: {
                              'Content-Type': 'application/x-www-form-urlencoded'
                            },
                          );
                          if (!isDialogActive) return;
                          if (response.statusCode == 200) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Transaction updated successfully.')),
                            );
                            await fetchTransactions(stockReturnId, entryIndex);
                            await fetchCurrentStock();
                            isDialogActive = false;
                            editQuantityController.dispose();
                            Navigator.of(dialogContext).pop();
                          } else {
                            throw Exception(
                                'Failed to update transaction: ${response.body}');
                          }
                        } catch (e) {
                          if (isDialogActive) {
                            print('Error updating transaction: $e');
                          }
                        } finally {
                          if (isDialogActive) {
                            setDialogState(() => isLoading = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28A746),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Update',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
  }

  void _addProduct() async {
    if (selectedProduct == null || quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a product and enter quantity')),
      );
      return;
    }

    final product = products.firstWhere(
      (product) => product['product_name'] == selectedProduct,
      orElse: () => {'product_id': '', 'product_name': ''},
    );
    final productId = product['product_id'] as String?;

    if (productId == null || productId.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid Product'),
          content: const Text('Selected product is invalid.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final existingProduct = selectedProducts.firstWhere(
      (product) => product['product_id'] == productId,
      orElse: () => <String, String>{},
    );

    if (existingProduct.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Product'),
          content:
              Text('The product "${selectedProduct}" has already been added.'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  selectedProduct = null;
                  quantityController.clear();
                });
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (_isReadOnlyMode) {
      try {
        final entry = stockReturnEntries.firstWhere(
          (entry) => entry['stock_return_id'] != '',
          orElse: () => <String, Object>{'stock_return_id': ''},
        );
        final stockReturnId = entry['stock_return_id'] as String?;

        if (stockReturnId != null && stockReturnId.isNotEmpty) {
          final productExists =
              await checkProductInTransactions(stockReturnId, productId);
          if (productExists) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Product Already Exists'),
                content: Text(
                    'The product "${selectedProduct}" is already included in this stock return entry.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedProduct = null;
                        quantityController.clear();
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Invalid stock return entry. Please try again.')),
          );
          return;
        }
      } catch (e) {
        print('Error checking stock return entry: $e');
        return;
      }
    }

    setState(() {
      selectedProducts.add({
        'product_id': productId,
        'product_name': selectedProduct!,
        'quantity': quantityController.text,
      });
      selectedProduct = null;
      quantityController.clear();
    });
  }

  Future<void> postTransactions() async {
  if (selectedProducts.isEmpty ||
      selectedEmpId == null ||
      godownId == null ||
      addressController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Please add at least one product and fill all required fields')),
    );
    return;
  }

  setState(() => _isSubmitting = true);

  try {
    String stockReturnId;

    // Log input data for debugging
    print('Submitting with:');
    print('selectedProducts: $selectedProducts');
    print('selectedEmpId: $selectedEmpId');
    print('godownId: $godownId');
    print('address: ${addressController.text}');

    if (_isReadOnlyMode) {
      final entry = stockReturnEntries.firstWhere(
        (entry) => entry['stock_return_id'] != '',
        orElse: () => <String, Object>{'stock_return_id': ''},
      );
      stockReturnId = entry['stock_return_id'] as String;
      if (stockReturnId.isEmpty) {
        throw Exception('No valid stock return ID found in read-only mode');
      }
    } else {
      // Always create a new stock return entry unless in read-only mode
      final returnData = {
        'godown_id': godownId.toString(),
        'godown_keeper_id': _empId ?? '',
        'emp_id': selectedEmpId!,
        'address': addressController.text,
        'dc_retrun': dcReturnController.text,
        'srs_no': srsNoController.text,
        'truck_no': truckNoController.text,
        'trip_no': tripNoController.text,
        'remarks': remarksController.text,
      };

      final response = await http.post(
        Uri.parse(
            'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/insert_stock_return_entries.php'),
        body: returnData,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock Return Entry Response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('stock_return_id')) {
          stockReturnId = responseBody['stock_return_id'].toString();
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception('Failed to create stock return entry: ${response.body}');
      }
    }

    // Insert transactions
    for (var product in selectedProducts) {
      final transactionData = {
        'stock_return_id': stockReturnId,
        'product_id': product['product_id'],
        'quantity': product['quantity'],
      };

      final response = await http.post(
        Uri.parse(
            'https://www.nabeenkishan.net.in/appi/routes/StockReturnController/insert_stock_return_transaction.php'),
        body: transactionData,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Transaction Response for ${product['product_name']}: ${response.statusCode}, ${response.body}');

      if (response.statusCode != 201) {
        throw Exception(
            'Failed to post transaction for ${product['product_name']}: ${response.body}');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_isReadOnlyMode
              ? 'Transactions added to existing stock return entry successfully'
              : 'Stock return entry and transactions submitted successfully')),
    );

    _clearFields();
    await _fetchCurrentStock(godownId!);
    await _fetchStockReturnEntries();
  } catch (e) {
    print('Error during submission: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to submit: $e')),
    );
  } finally {
    setState(() => _isSubmitting = false);
  }
}

  void _clearFields() {
    setState(() {
      _isReadOnlyMode = false;
      selectedEmpId = null;
      selectedProduct = null;
      selectedProducts.clear();
      quantityController.clear();
      addressController.clear();
      dcReturnController.clear();
      srsNoController.clear();
      truckNoController.clear();
      tripNoController.clear();
      remarksController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final buttonWidth = isMobile ? screenWidth * 0.85 : screenWidth * 0.5;
    final textFieldPadding = isMobile ? 12.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Stock Return',
            style: TextStyle(fontSize: 24, color: Colors.white)),
        backgroundColor: const Color(0xFF28A746),
        elevation: 0,
        centerTitle: true,
      ),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade100, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.03),
                _buildEmployeeDropdown(
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  screenHeight: screenHeight,
                  screenWidth: screenWidth,
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildTextField(
                  controller: addressController,
                  label: 'Address',
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  inputFormatters: [],
                  textCapitalization: TextCapitalization.sentences,
                  readOnly: true,
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildTextField(
                  controller: dcReturnController,
                  label: 'DC Return',
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  inputFormatters: [],
                  textCapitalization: TextCapitalization.characters,
                  readOnly: _isReadOnlyMode,
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildTextField(
                  controller: srsNoController,
                  label: 'SRS No',
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  inputFormatters: [],
                  textCapitalization: TextCapitalization.characters,
                  readOnly: _isReadOnlyMode,
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildTextField(
                  controller: truckNoController,
                  label: 'Truck No',
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  inputFormatters: [],
                  textCapitalization: TextCapitalization.characters,
                  readOnly: _isReadOnlyMode,
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildTextField(
                  controller: tripNoController,
                  label: 'Trip No',
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  inputFormatters: [],
                  textCapitalization: TextCapitalization.characters,
                  readOnly: _isReadOnlyMode,
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildTextField(
                  controller: remarksController,
                  label: 'Remarks',
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  inputFormatters: [],
                  textCapitalization: TextCapitalization.sentences,
                  readOnly: _isReadOnlyMode,
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildDropdownField(
                  value: selectedProduct,
                  items: products,
                  label: 'Select Product',
                  onChanged: (newValue) =>
                      setState(() => selectedProduct = newValue),
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  isLoading: _isFetchingProducts,
                ),
                SizedBox(height: screenHeight * 0.01),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: quantityController,
                        label: 'Quantity',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        isMobile: isMobile,
                        textFieldPadding: textFieldPadding,
                        textCapitalization: TextCapitalization.none,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    SizedBox(
                      width: screenWidth * 0.12,
                      height: screenHeight * 0.06,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _addProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A746),
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(0),
                        ),
                        child: const Icon(Icons.add,
                            size: 24, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02),
                if (selectedProducts.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Products',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Center(child: _buildSelectedProductsTable(isMobile)),
                    ],
                  ),
                SizedBox(height: screenHeight * 0.03),
                Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: buttonWidth,
                    height: screenHeight * 0.06,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              postTransactions();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28A746),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        elevation: 8,
                        shadowColor: Colors.black26,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit All',
                              style: TextStyle(
                                fontSize: screenHeight * 0.018,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.03),
                const Divider(color: Colors.grey),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  'Stock Return Entries',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                _buildStockReturnEntriesAccordion(isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeDropdown({
    required bool isMobile,
    required double textFieldPadding,
    required double screenHeight,
    required double screenWidth,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: _isFetchingEmployees
          ? Container(
              padding: EdgeInsets.all(textFieldPadding),
              height: screenHeight * 0.07,
              child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF28A746))),
            )
          : DropdownButton2<Employee>(
              isExpanded: true,
              hint: Text('Select Employee',
                  style: TextStyle(
                      fontSize: screenHeight * 0.014,
                      color: Colors.grey.shade600)),
              value: selectedEmpId == null
                  ? null
                  : employees.firstWhere((e) => e.empId == selectedEmpId,
                      orElse: () => employees.first),
              onChanged: _isReadOnlyMode
                  ? null
                  : (Employee? selectedEmployee) {
                      setState(() {
                        selectedEmpId = selectedEmployee?.empId;
                        if (selectedEmpId != null) {
                          fetchCampAddress(selectedEmpId!);
                        } else {
                          addressController.clear();
                        }
                      });
                    },
              items: employees.map((employee) {
                return DropdownMenuItem<Employee>(
                  value: employee,
                  child: Text(
                    employee.toString(),
                    style: TextStyle(
                      fontSize: screenHeight * 0.014,
                    ),
                  ),
                );
              }).toList(),
              buttonStyleData: ButtonStyleData(
                padding: EdgeInsets.all(textFieldPadding),
                height: screenHeight * 0.07,
                width: screenWidth,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15), color: Colors.white),
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: screenHeight * 0.6,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(15)),
              ),
              menuItemStyleData: MenuItemStyleData(height: screenHeight * 0.046),
              dropdownSearchData: DropdownSearchData(
                searchController: searchController,
                searchInnerWidgetHeight: screenHeight * 0.15,
                searchInnerWidget: Container(
                  height: screenHeight * 0.08,
                  padding: const EdgeInsets.all(8),
                  child: TextFormField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by employee name or e-code...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color.fromRGBO(40, 167, 70, 1), width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color.fromRGBO(40, 167, 70, 1), width: 2),
                      ),
                    ),
                  ),
                ),
                searchMatchFn: (item, searchValue) {
                  final employee = item.value!;
                  final searchLower = searchValue.toLowerCase();
                  final fullName =
                      '${employee.firstName} ${employee.middleName} ${employee.lastName}'
                          .trim()
                          .toLowerCase();
                  return fullName.contains(searchLower) ||
                      employee.eCode.toLowerCase().contains(searchLower);
                },
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    Widget? suffixIcon,
    bool readOnly = false,
    TextInputType? keyboardType,
    required bool isMobile,
    required double textFieldPadding,
    required List<TextInputFormatter> inputFormatters,
    bool hasError = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    String? hintText;
    if (label == 'Quantity' && selectedProduct != null) {
      final productId = products.firstWhere(
        (product) => product['product_name'] == selectedProduct,
        orElse: () => {'product_id': '', 'product_name': ''},
      )['product_id'];
      final stockItem = currentStock.firstWhere(
        (stock) => stock['product_id'] == productId,
        orElse: () => {
          'product_id': '',
          'quantity': 0,
          'product_name': selectedProduct as String,
        },
      );
      hintText = 'Available: ${stockItem['quantity']}';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                )
              : null,
          focusedBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(
              vertical: 20.0, horizontal: textFieldPadding),
          suffixIcon: suffixIcon,
        ),
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<Map<String, String>> items,
    required String label,
    required void Function(String?) onChanged,
    required bool isMobile,
    required double textFieldPadding,
    bool isLoading = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: isLoading
          ? Container(
              padding: EdgeInsets.symmetric(
                  vertical: 20.0, horizontal: textFieldPadding),
              child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF28A746))),
            )
          : DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: Colors.grey.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: textFieldPadding),
              ),
              value: value,
              onChanged: (newValue) {
                setState(() {
                  selectedProduct = newValue;
                  if (newValue != null) {
                    final productId = products.firstWhere(
                      (product) => product['product_name'] == newValue,
                      orElse: () => {'product_id': '', 'product_name': ''},
                    )['product_id'];
                    final stockItem = currentStock.firstWhere(
                      (stock) => stock['product_id'] == productId,
                      orElse: () => {
                        'product_id': '',
                        'quantity': 0,
                        'product_name': newValue,
                      },
                    );
                    quantityController.text = '';
                  }
                });
                onChanged(newValue);
              },
              items: items.map((product) {
                return DropdownMenuItem<String>(
                  value: product['product_name'],
                  child: Text(product['product_name']!),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSelectedProductsTable(bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: DataTable(
          columnSpacing: isMobile ? 10 : 20,
          dataRowHeight: 60,
          headingRowColor: MaterialStateColor.resolveWith(
              (states) => const Color(0xFF28A746).withOpacity(0.1)),
          border: TableBorder(
            horizontalInside: BorderSide(width: 1, color: Colors.grey.shade300),
            verticalInside: BorderSide(width: 1, color: Colors.grey.shade300),
          ),
          columns: const [
            DataColumn(
                label: Center(
                    child: Text('Product',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            DataColumn(
                label: Center(
                    child: Text('Quantity',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            DataColumn(
                label: Center(
                    child: Text('Action',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
          ],
          rows: selectedProducts.map((product) {
            return DataRow(
              color: MaterialStateColor.resolveWith(
                (states) => selectedProducts.indexOf(product) % 2 == 0
                    ? Colors.grey.shade50
                    : Colors.white,
              ),
              cells: [
                DataCell(Text(product['product_name']!)),
                DataCell(Text(product['quantity']!)),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        selectedProducts.remove(product);
                      });
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStockReturnEntriesAccordion(bool isMobile) {
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return _isFetchingEntries
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF28A746)))
        : stockReturnEntries.isEmpty
            ? Center(
                child: Text(
                  'No stock return entries available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stockReturnEntries.length,
                itemBuilder: (context, index) {
                  final entry = stockReturnEntries[index];
                  final isCurrentDate =
                      entry['stock_return_date'] == currentDate;

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ExpansionTile(
                      tilePadding:
                          EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                      backgroundColor: Colors.white,
                      collapsedBackgroundColor:
                          index % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Text(
                                //   'Godown: ${entry['godown_name'] ?? ''}',
                                //   style: TextStyle(
                                //       fontWeight: FontWeight.bold,
                                //       fontSize: 16),
                                // ),
                                Text(
                                  'GRN: ${entry['grn_no'] ?? ''}',
                                 style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  'Date: ${entry['stock_return_date'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600),
                                ),
                                Text(
                                  'Address: ${entry['address'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600),
                                ),
                                Text(
                                  'Remarks: ${entry['remarks'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (isCurrentDate)
                                IconButton(
                                  icon: const Icon(Icons.add,
                                      color: Colors.green),
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _populateFormForExistingEntry(
                                            stockReturnId:
                                                entry['stock_return_id']
                                                    .toString(),
                                            address:
                                                entry['address']?.toString() ??
                                                    '',
                                            dcReturn: entry['dc_retrun']
                                                    ?.toString() ??
                                                '',
                                            srsNo:
                                                entry['srs_no']?.toString() ??
                                                    '',
                                            truckNo:
                                                entry['truck_no']?.toString() ??
                                                    '',
                                            tripNo:
                                                entry['trip_no']?.toString() ??
                                                    '',
                                            remarks:
                                                entry['remarks']?.toString() ??
                                                    '',
                                            entryIndex: index,
                                          ),
                                ),
                              if (isCurrentDate)
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _showEditStockReturnEntryDialog(
                                            entry['stock_return_id'].toString(),
                                            context,
                                            _fetchStockReturnEntries,
                                          ),
                                ),
                              if (isCurrentDate)
                                IconButton(
                                  icon: _isDeleting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.red),
                                        )
                                      : const Icon(Icons.delete,
                                          color: Colors.red),
                                  onPressed: _isSubmitting || _isDeleting
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await _showConfirmDeleteDialog(
                                            'Stock Return Entry',
                                            entry['stock_return_id'] ?? '',
                                            entry['stock_return_id'].toString(),
                                          );
                                          if (confirmed) {
                                            await _deleteStockReturnEntry(
                                                entry['stock_return_id']
                                                    .toString());
                                          }
                                        },
                                ),
                            ],
                          ),
                        ],
                      ),
                      onExpansionChanged: (expanded) {
                        setState(() {
                          stockReturnEntries[index]['isExpanded'] = expanded;
                        });
                        if (expanded && entry['transactions'].isEmpty) {
                          _fetchStockReturnTransactions(
                              entry['stock_return_id'].toString(), index);
                        }
                      },
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: entry['isFetchingTransactions']
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF28A746)))
                              : entry['transactions'].isEmpty
                                  ? Text(
                                      'No transactions available.',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600),
                                    )
                                  : Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Container(
                                        width: isMobile ? double.infinity : 600,
                                        padding: const EdgeInsets.all(12.0),
                                        color: Colors.white,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: entry['transactions']
                                              .asMap()
                                              .entries
                                              .map<Widget>((transactionEntry) {
                                            final transaction =
                                                transactionEntry.value;
                                            final transactionIndex =
                                                transactionEntry.key;
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Product: ${transaction['product_name']?.toString() ?? 'N/A'}',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: isMobile
                                                                  ? 14
                                                                  : 16,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(
                                                            'Quantity: ${transaction['quantity']?.toString() ?? 'N/A'}',
                                                            style: TextStyle(
                                                              fontSize: isMobile
                                                                  ? 12
                                                                  : 14,
                                                              color: Colors.grey
                                                                  .shade800,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(
                                                            'Pre Stock: ${transaction['pre_stock_level']?.toString() ?? 'N/A'}',
                                                            style: TextStyle(
                                                              fontSize: isMobile
                                                                  ? 12
                                                                  : 14,
                                                              color: Colors.grey
                                                                  .shade800,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(
                                                            'New Stock: ${transaction['new_stock_level']?.toString() ?? 'N/A'}',
                                                            style: TextStyle(
                                                              fontSize: isMobile
                                                                  ? 12
                                                                  : 14,
                                                              color: Colors.grey
                                                                  .shade800,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Column(
                                                      children: [
                                                        if (isCurrentDate)
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons.edit,
                                                                color: Colors
                                                                    .blue),
                                                            onPressed:
                                                                _isSubmitting
                                                                    ? null
                                                                    : () =>
                                                                        _showEditStockTransactionDialog(
                                                                          stockTransactionId:
                                                                              transaction['stock_transaction_id']?.toString() ?? '',
                                                                          entryIndex:
                                                                              index,
                                                                          stockReturnId:
                                                                              entry['stock_return_id']?.toString() ?? '',
                                                                          productName:
                                                                              transaction['product_name']?.toString() ?? 'N/A',
                                                                          parentContext:
                                                                              context,
                                                                          fetchTransactions:
                                                                              (stockReturnId, entryIndex) => _fetchStockReturnTransactions(stockReturnId, entryIndex),
                                                                          fetchCurrentStock:
                                                                              () => _fetchCurrentStock(godownId!),
                                                                          currentStock:
                                                                              currentStock,
                                                                          godownId:
                                                                              godownId.toString(),
                                                                        ),
                                                          ),
                                                        if (isCurrentDate)
                                                          IconButton(
                                                            icon: _isDeleting
                                                                ? const SizedBox(
                                                                    width: 20,
                                                                    height: 20,
                                                                    child: CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            2,
                                                                        color: Colors
                                                                            .red),
                                                                  )
                                                                : const Icon(
                                                                    Icons
                                                                        .delete,
                                                                    color: Colors
                                                                        .red),
                                                            onPressed:
                                                                _isSubmitting ||
                                                                        _isDeleting
                                                                    ? null
                                                                    : () async {
                                                                        final confirmed = await _showConfirmDeleteDialog(
                                                                            'Transaction',
                                                                            transaction['product_name']?.toString() ??
                                                                                '',
                                                                            transaction['stock_transaction_id']?.toString() ??
                                                                                '');
                                                                        if (confirmed) {
                                                                          await _deleteTransaction(
                                                                              transaction['stock_transaction_id']?.toString() ?? '',
                                                                              index);
                                                                        }
                                                                      },
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                if (transactionIndex <
                                                    entry['transactions']
                                                            .length -
                                                        1)
                                                  Divider(
                                                    color: Colors.grey.shade300,
                                                    thickness: 1,
                                                    height: 16,
                                                  ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                        ),
                      ],
                    ),
                  );
                },
              );
  }
}

class DeleteConfirmationDialog extends StatefulWidget {
  final String type;
  final String identifier;
  final String id;

  const DeleteConfirmationDialog({
    Key? key,
    required this.type,
    required this.identifier,
    required this.id,
  }) : super(key: key);

  @override
  _DeleteConfirmationDialogState createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<DeleteConfirmationDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text('Delete ${widget.type}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to delete this ${widget.type} (${widget.identifier})?',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}