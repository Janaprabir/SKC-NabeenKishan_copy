import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:nabeenkishan/godown/stock_transfar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TransactionPage extends StatefulWidget {
  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  List<Map<String, String>> products = [];
  List<Map<String, String>> selectedProducts = [];
  List<Map<String, dynamic>> stockInEntries = [];
  String? selectedProduct;
  TextEditingController billNoController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController remarksController = TextEditingController();
  int? godownId;
  String? _empId;
  bool isLoading = true;
  bool _isSubmitting = false;
  bool _isFetchingProducts = false;
  bool _isFetchingStockInEntries = false;
  bool billNoExists = false;
  bool _isCheckingBillNo = false;
  Timer? _debounce;
  String? _currentStockInId;
  bool _isEditingExistingEntry = false;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    fetchStockInEntries();
    _loadGodownId();
    _loadSessionData();

    billNoController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (billNoController.text.isNotEmpty && mounted) {
          checkBillNoExists(billNoController.text);
        } else {
          setState(() {
            billNoExists = false;
            _isCheckingBillNo = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    billNoController.dispose();
    quantityController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> checkBillNoExists(String billNo) async {
    setState(() => _isCheckingBillNo = true);
    try {
      if (!RegExp(r'^[0-9A-Z]+$').hasMatch(billNo)) {
        throw Exception(
            'Invalid bill number format. Use alphanumeric characters only.');
      }

      final encodedBillNo = Uri.encodeQueryComponent(billNo);
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/check_bill_no_exists.php?bill_no=$encodedBillNo';
      print('Checking bill number URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Bill No Check Status: ${response.statusCode}');
      print('Bill No Check Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('exists')) {
          setState(() {
            billNoExists = responseBody['exists'] == true;
          });
          if (billNoExists && mounted && !_isEditingExistingEntry) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Bill number already exists. Please use a unique bill number.')),
            );
          }
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to check bill number. Status code: ${response.statusCode}, Response: ${response.body}');
      }
    } catch (e) {
      print('Error checking bill number: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking bill number: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingBillNo = false);
      }
    }
  }

  Future<void> fetchProducts() async {
    setState(() => _isFetchingProducts = true);
    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllProducts'));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    } finally {
      setState(() => _isFetchingProducts = false);
    }
  }

  Future<void> fetchStockInEntries() async {
    setState(() => _isFetchingStockInEntries = true);
    try {
      const limit = 300;
      
      await _loadGodownId();

      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/get_all_stock_in_entries.php?limit=$limit&godown_id=$godownId';
      print('Fetching stock-in entries URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock-In Entries Status: ${response.statusCode}');
      print('Stock-In Entries Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          stockInEntries = data.map((entry) {
            final entryMap = Map<String, dynamic>.from(entry);
            entryMap['isExpanded'] = false;
            entryMap['transactions'] = <Map<String, dynamic>>[];
            entryMap['isFetchingTransactions'] = false;
            if (entryMap['stock_in_date'] != null) {
              try {
                final date = DateTime.parse(entryMap['stock_in_date']);
                entryMap['stock_in_date'] =
                    DateFormat('dd/MM/yyyy').format(date);
              } catch (e) {
                print('Error parsing date: ${entryMap['stock_in_date']}');
              }
            }
            return entryMap;
          }).toList();
        });
      } else {
        throw Exception(
            'Failed to load stock-in entries. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading stock-in entries: $e');
    } finally {
      setState(() => _isFetchingStockInEntries = false);
    }
  }

  Future<void> fetchStockInTransactions(
      String stockInId, int entryIndex) async {
    setState(() {
      stockInEntries[entryIndex]['isFetchingTransactions'] = true;
    });
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/get_stock_in_transactions.php?stock_in_id=$stockInId';
      print('Fetching stock-in transactions URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock-In Transactions Status: ${response.statusCode}');
      print('Stock-In Transactions Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          stockInEntries[entryIndex]['transactions'] = data
              .map((transaction) => Map<String, dynamic>.from(transaction))
              .toList();
          stockInEntries[entryIndex]['isFetchingTransactions'] = false;
          stockInEntries[entryIndex]['isExpanded'] = true;
        });
      } else {
        throw Exception(
            'Failed to load stock-in transactions. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Error loading stock-in transactions')),
        );
      }
      setState(() {
        stockInEntries[entryIndex]['isFetchingTransactions'] = false;
      });
    }
  }

  Future<Map<String, dynamic>?> fetchStockEntry(String stockInId) async {
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/get_stock_entry.php?stock_in_id=$stockInId';
      print('Fetching stock entry URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock Entry Fetch Status: ${response.statusCode}');
      print('Stock Entry Fetch Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          // Format date if present
          if (data['stock_in_date'] != null) {
            try {
              final date = DateTime.parse(data['stock_in_date']);
              data['stock_in_date'] = DateFormat('dd/MM/yyyy').format(date);
            } catch (e) {
              print('Error parsing date in fetchStockEntry: ${data['stock_in_date']}');
            }
          }
          return data;
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to fetch stock entry. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching stock entry: $e')),
        );
      }
      return null;
    }
  }

  Future<void> updateStockEntry({
    required String stockInId,
    required String billNo,
    required String remarks,
    required BuildContext parentContext,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final data = {
        'stock_in_id': stockInId,
        'bill_no': billNo,
        'remarks': remarks,
      };

      print('Updating stock entry data: $data');

      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/update_stock_entry.php'),
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock Entry Update Status: ${response.statusCode}');
      print('Stock Entry Update Response: ${response.body}');

      if (response.statusCode == 200) {
        if (parentContext.mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(content: Text('Stock entry updated successfully')),
          );
        }
        await fetchStockInEntries();
      } else {
        throw Exception(
            'Failed to update stock entry. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating stock entry: $e');
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text('Error updating stock entry: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<Map<String, dynamic>?> fetchStockTransaction(
      String stockTransactionId) async {
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/get_stock_in_trans.php?stock_transaction_id=$stockTransactionId';
      print('Fetching stock transaction URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock Transaction Fetch Status: ${response.statusCode}');
      print('Stock Transaction Fetch Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to fetch stock transaction. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching stock transaction: $e')),
        );
      }
      return null;
    }
  }

  Future<void> updateStockTransaction({
    required String stockTransactionId,
    required String productId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final data = {
        'stock_transaction_id': stockTransactionId,
        'product_id': productId,
        'quantity': quantity,
      };

      print('Updating stock transaction data: $data');

      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/update_stock_transaction.php'),
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock Transaction Update Status: ${response.statusCode}');
      print('Stock Transaction Update Response: ${response.body}');

      if (response.statusCode == 200) {
        if (parentContext.mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(
                content: Text('Stock transaction updated successfully')),
          );
        }
        await fetchStockInTransactions(
            stockInEntries[entryIndex]['stock_in_id'].toString(), entryIndex);
      } else {
        throw Exception(
            'Failed to update stock transaction. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating stock transaction: $e');
      // if (parentContext.mounted) {
      //   ScaffoldMessenger.of(parentContext).showSnackBar(
      //     SnackBar(content: Text('Error updating stock transaction: $e')),
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> insertStockTransaction({
    required String stockInId,
    required String productId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final data = {
        'stock_in_id': stockInId,
        'product_id': productId,
        'quantity': quantity,
      };

      print('Inserting new stock transaction data: $data');

      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/insert_stock_transaction.php'),
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock Transaction Insert Status: ${response.statusCode}');
      print('Stock Transaction Insert Response: ${response.body}');

      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody['message'] ==
                'Stock transaction created successfully') {
          if (parentContext.mounted) {
            ScaffoldMessenger.of(parentContext).showSnackBar(
              const SnackBar(
                  content: Text('New stock transaction added successfully')),
            );
          }
          await fetchStockInTransactions(stockInId, entryIndex);
        } else {
          throw Exception('Unexpected response: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to insert stock transaction. Status code: ${response.statusCode}, Response: ${response.body}');
      }
    } catch (e) {
      print('Error inserting stock transaction: $e');
      if (parentContext.mounted) {
        // ScaffoldMessenger.of(parentContext).showSnackBar(
        //   SnackBar(content: Text('Error adding new transaction: $e')),
        // );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> deleteStockEntry(String stockInId) async {
    setState(() => _isSubmitting = true);
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/delete_stock_entry.php?stock_in_id=$stockInId';
      print('Deleting stock entry URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock Entry Delete Status: ${response.statusCode}');
      print('Stock Entry Delete Response: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock entry deleted successfully')),
          );
        }
        await fetchStockInEntries();
      } else {
        throw Exception(
            'Failed to delete stock entry. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting stock entry: $e');
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Error deleting stock entry: $e')),
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> deleteStockTransaction(
      String stockTransactionId, int entryIndex) async {
    setState(() => _isSubmitting = true);
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/delete_stock_transaction.php?stock_transaction_id=$stockTransactionId';
      print('Deleting stock transaction URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock Transaction Delete Status: ${response.statusCode}');
      print('Stock Transaction Delete Response: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Stock transaction deleted successfully')),
          );
        }
        await fetchStockInTransactions(
            stockInEntries[entryIndex]['stock_in_id'].toString(), entryIndex);
      } else {
        throw Exception(
            'Failed to delete stock transaction. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting stock transaction: $e');
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Error deleting stock transaction: $e')),
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _loadGodownId() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      godownId = prefs.getInt('godown_id');
      isLoading = false;
    });
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empId = prefs.getString('emp_id');
    });
  }

  Future<void> submitAll() async {
    if (billNoController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill the bill number field')),
        );
      }
      return;
    }

    if (godownId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Godown ID is not available')),
        );
      }
      return;
    }

    if (selectedProducts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one product')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isEditingExistingEntry && _currentStockInId != null) {
        for (var product in selectedProducts) {
          final transactionData = {
            'stock_in_id': _currentStockInId!,
            'product_id': product['product_id'],
            'quantity': product['quantity'],
          };

          print('Submitting transaction data: $transactionData');

          final transactionResponse = await http.post(
            Uri.parse(
                'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/insert_stock_transaction.php'),
            body: transactionData,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          );

          print('Transaction Submission Status: ${transactionResponse.statusCode}');
          print('Transaction Submission Response: ${transactionResponse.body}');

          if (transactionResponse.statusCode != 201) {
            throw Exception(
                'Failed to post transaction for ${product['product_name']}: ${transactionResponse.body}');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Transactions added to stock entry successfully')),
          );
        }
        resetForm();
        await fetchStockInEntries();
      } else {
        if (billNoExists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Bill number already exists. Please use a unique bill number.')),
            );
          }
          return;
        }

        final billData = {
          'godown_id': godownId.toString(),
          'bill_no': billNoController.text,
          'godown_keeper_id': _empId ?? '',
          'remarks': remarksController.text,
        };

        print('Submitting bill data: $billData');

        final billResponse = await http.post(
          Uri.parse(
              'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/insert_stock_entries.php'),
          body: billData,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        );

        print('Bill Submission Status: ${billResponse.statusCode}');
        print('Bill Submission Response: ${billResponse.body}');

        if (billResponse.statusCode == 201) {
          final responseBody = jsonDecode(billResponse.body);
          if (responseBody is Map<String, dynamic> &&
              responseBody['message'] == 'Stock entry created successfully' &&
              responseBody.containsKey('stock_in_id')) {
            final stockInId = responseBody['stock_in_id'].toString();

            for (var product in selectedProducts) {
              final transactionData = {
                'stock_in_id': stockInId,
                'product_id': product['product_id'],
                'quantity': product['quantity'],
              };

              print('Submitting transaction data: $transactionData');

              final transactionResponse = await http.post(
                Uri.parse(
                    'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/insert_stock_transaction.php'),
                body: transactionData,
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              );

              print('Transaction Submission Status: ${transactionResponse.statusCode}');
              print('Transaction Submission Response: ${transactionResponse.body}');

              if (transactionResponse.statusCode != 201) {
                throw Exception(
                    'Failed to post transaction for ${product['product_name']}: ${transactionResponse.body}');
              }
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Stock entry and transactions submitted successfully')),
              );
            }
            resetForm();
            await fetchStockInEntries();
          } else {
            throw Exception(
                'Unexpected bill submission response: ${billResponse.body}');
          }
        } else {
          throw Exception(
              'Failed to create stock entry. Status code: ${billResponse.statusCode}, Response: ${billResponse.body}');
        }
      }
    } catch (e) {
      print('Error during submission: $e');
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error during submission: $e')),
        // );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> checkProductInTransactions(String stockInId, String productId) async {
  try {
    final url =
        'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/get_stock_in_transactions.php?stock_in_id=$stockInId';
    print('Checking product in transactions URL: $url');
    print('Checking for productId: $productId (type: ${productId.runtimeType})');

    final response = await http.get(Uri.parse(url));
    print('Check Product Transactions Status: ${response.statusCode}');
    print('Check Product Transactions Response: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      print('Transactions: $data');
      bool exists = data.any((transaction) {
        final transactionProductId = transaction['product_id'].toString();
        print(
            'Comparing transaction product_id: $transactionProductId (type: ${transactionProductId.runtimeType}) with $productId');
        return transactionProductId == productId;
      });
      print('Product exists in transactions: $exists');
      return exists;
    } else {
      throw Exception(
          'Failed to fetch transactions for product check. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error checking product in transactions: $e');
    if (mounted) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error checking product: $e')),
      // );

    }
    return false;
  }
}

void _addProduct() async {
  if (selectedProduct == null || quantityController.text.isEmpty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Missing Information'),
        content: const Text('Please select a product and enter quantity'),
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

  final product = products.firstWhere(
    (product) => product['product_name'] == selectedProduct,
    orElse: () => {'product_id': '', 'product_name': ''},
  );
  final productId = product['product_id'];

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

  // Check for duplicates in selectedProducts
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

  // If editing an existing stock entry, check if the product exists in transactions
  if (_isEditingExistingEntry && _currentStockInId != null) {
    print('Checking if product exists for stock_in_id: $_currentStockInId');
    final productExists = await checkProductInTransactions(_currentStockInId!, productId);
    if (productExists) {
      print('Product "$selectedProduct" already exists in stock entry. Showing dialog.');
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Product Already Exists'),
          content: Text(
              'The product "${selectedProduct}" is already included in this stock entry.'),
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
    print('Product "$selectedProduct" does not exist in stock entry. Proceeding to add.');
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

  void resetForm() {
    setState(() {
      selectedProduct = null;
      selectedProducts.clear();
      billNoController.clear();
      quantityController.clear();
      remarksController.clear();
      billNoExists = false;
      _currentStockInId = null;
      _isEditingExistingEntry = false;
      for (var entry in stockInEntries) {
        entry['transactions'] = <Map<String, dynamic>>[];
        entry['isExpanded'] = false;
        entry['isFetchingTransactions'] = false;
      }
    });
  }

  void _populateFormForExistingEntry({
    required String stockInId,
    required String billNo,
    required String remarks,
    required int entryIndex,
  }) {
    setState(() {
      _currentStockInId = stockInId;
      _isEditingExistingEntry = true;
      billNoController.text = billNo;
      remarksController.text = remarks;
      selectedProducts.clear();
      selectedProduct = null;
      quantityController.clear();
      billNoExists = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adding products to Bill No: $billNo')),
    );
  }

  Future<void> _showEditStockEntryDialog(
      String stockInId, BuildContext parentContext) async {
    final stockEntry = await fetchStockEntry(stockInId);
    if (stockEntry == null || !parentContext.mounted) return;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => _EditStockEntryDialog(
        stockInId: stockInId,
        stockEntry: stockEntry,
        parentContext: parentContext,
        isSubmitting: _isSubmitting,
        onUpdate: updateStockEntry,
        onCheckBillNo: _checkBillNo,
      ),
    );
  }

  Future<void> _checkBillNo(String billNo, String originalBillNo,
      Function(bool, bool) onResult) async {
    if (billNo == originalBillNo) {
      onResult(false, false);
      print('Bill number unchanged, skipping check: $billNo');
      return;
    }

    try {
      final encodedBillNo = Uri.encodeQueryComponent(billNo);
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockInController/check_bill_no_exists.php?bill_no=$encodedBillNo';
      print('Checking bill number in dialog URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Dialog Bill No Check Status: ${response.statusCode}');
      print('Dialog Bill No Check Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        onResult(responseBody['exists'] == true, false);
        print('Bill number check result: exists=${responseBody['exists']}');
      } else {
        throw Exception('Failed to check bill number: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking bill number in dialog: $e');
      onResult(false, false);
    }
  }

  Future<void> _showEditStockTransactionDialog({
    required String stockTransactionId,
    required int entryIndex,
    required String stockInId,
    required String productName,
    required BuildContext parentContext,
  }) async {
    final transaction = await fetchStockTransaction(stockTransactionId);
    if (transaction == null || !parentContext.mounted) return;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => _EditStockTransactionDialog(
        stockTransactionId: stockTransactionId,
        stockInId: stockInId,
        entryIndex: entryIndex,
        transaction: transaction,
        products: products,
        parentContext: parentContext,
        isSubmitting: _isSubmitting,
        onUpdate: updateStockTransaction,
        onInsert: insertStockTransaction,
      ),
    );
  }

  Future<bool> _showConfirmDeleteDialog(
      String type, String identifier, String stockInId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DeleteConfirmationDialog(
        type: type,
        identifier: identifier,
        stockInId: stockInId,
      ),
    );
    return result ?? false;
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
        title: Text(
          _isEditingExistingEntry
              ? 'Add to Existing Stock Entry'
              : 'Stock In',
          style: const TextStyle(fontSize: 24, color: Colors.white),
        ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: billNoController,
                      label: 'Bill No',
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Z]'))
                      ],
                      textCapitalization: TextCapitalization.characters,
                      isMobile: isMobile,
                      textFieldPadding: textFieldPadding,
                      hasError: billNoExists && !_isEditingExistingEntry,
                      readOnly: _isEditingExistingEntry,
                    ),
                    if (billNoExists && !_isEditingExistingEntry)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0, left: 16.0),
                        child: Text(
                          'Bill number already exists',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (_isCheckingBillNo)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, left: 16.0),
                        child: Text(
                          'Checking bill number...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildTextField(
                  controller: remarksController,
                  label: 'Remarks',
                  keyboardType: TextInputType.text,
                  inputFormatters: [],
                  textCapitalization: TextCapitalization.sentences,
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  readOnly: _isEditingExistingEntry,
                ),
                SizedBox(height: screenHeight * 0.03),
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
                if (selectedProducts.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.02),
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
                              submitAll();
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
                              _isEditingExistingEntry
                                  ? 'Add Transactions'
                                  : 'Submit All',
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
                Center(
                  child: Text(
                    'Stock-In Entries',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                _isFetchingStockInEntries
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF28A746)))
                    : stockInEntries.isEmpty
                        ? Center(
                            child: Text(
                              'No stock-in entries available.',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade600),
                            ),
                          )
                        : _buildStockInEntriesAccordion(isMobile),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    TextInputType? keyboardType,
    required bool isMobile,
    required double textFieldPadding,
    required List<TextInputFormatter> inputFormatters,
    required TextCapitalization textCapitalization,
    bool hasError = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
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
            vertical: 20.0,
            horizontal: textFieldPadding,
          ),
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
    required void Function(String?)? onChanged,
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
                  vertical: 20.0,
                  horizontal: textFieldPadding,
                ),
              ),
              value: value,
              onChanged: onChanged,
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
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            DataColumn(
              label: Center(
                child: Text('Quantity',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            DataColumn(
              label: Center(
                child: Text('Action',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
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

  Widget _buildStockInEntriesAccordion(bool isMobile) {
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stockInEntries.length,
      itemBuilder: (context, index) {
        final entry = stockInEntries[index];
        final isCurrentDate = entry['stock_in_date'] == currentDate;

        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ExpansionTile(
            tilePadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
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
                      Text(
                        'Bill No: ${entry['bill_no'] ?? ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Godown: ${entry['godown_name'] ?? ''}',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                      Text(
                        'Date: ${entry['stock_in_date'] ?? ''}',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                      Text(
                        'Remarks: ${entry['remarks'] ?? ''}',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (isCurrentDate)
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.green),
                        onPressed: _isSubmitting
                            ? null
                            : () => _populateFormForExistingEntry(
                                  stockInId: entry['stock_in_id'].toString(),
                                  billNo: entry['bill_no']?.toString() ?? '',
                                  remarks: entry['remarks']?.toString() ?? '',
                                  entryIndex: index,
                                ),
                      ),
                    if (isCurrentDate)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: _isSubmitting
                            ? null
                            : () => _showEditStockEntryDialog(
                                entry['stock_in_id'].toString(), context),
                      ),
                    if (isCurrentDate)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final confirmed = await _showConfirmDeleteDialog(
                                  'Stock Entry',
                                  entry['bill_no'] ?? '',
                                  entry['stock_in_id'].toString(),
                                );
                                if (confirmed) {
                                  await deleteStockEntry(
                                      entry['stock_in_id'].toString());
                                }
                              },
                      ),
                  ],
                ),
              ],
            ),
            onExpansionChanged: (expanded) {
              setState(() {
                stockInEntries[index]['isExpanded'] = expanded;
              });
              if (expanded && entry['transactions'].isEmpty) {
                fetchStockInTransactions(
                    entry['stock_in_id'].toString(), index);
              }
            },
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: entry['transactions'].isEmpty &&
                        !entry['isFetchingTransactions']
                    ? Text(
                        'No transactions available.',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: entry['transactions']
                                .asMap()
                                .entries
                                .map<Widget>((transactionEntry) {
                              final transaction = transactionEntry.value;
                              final transactionIndex = transactionEntry.key;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Product: ${transaction['product_name']?.toString() ?? 'N/A'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isMobile ? 14 : 16,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Quantity: ${transaction['quantity']?.toString() ?? 'N/A'}',
                                              style: TextStyle(
                                                fontSize: isMobile ? 12 : 14,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Previous Stock: ${transaction['pre_stock_level']?.toString() ?? 'N/A'}',
                                              style: TextStyle(
                                                fontSize: isMobile ? 12 : 14,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'New Stock: ${transaction['new_stock_level']?.toString() ?? 'N/A'}',
                                              style: TextStyle(
                                                fontSize: isMobile ? 12 : 14,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          if (isCurrentDate)
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  color: Colors.blue),
                                              onPressed: _isSubmitting
                                                  ? null
                                                  : () =>
                                                      _showEditStockTransactionDialog(
                                                        stockTransactionId:
                                                            transaction['stock_transaction_id']
                                                                    ?.toString() ??
                                                                '',
                                                        entryIndex: index,
                                                        stockInId: entry[
                                                                    'stock_in_id']
                                                                ?.toString() ??
                                                            '',
                                                        productName: transaction[
                                                                    'product_name']
                                                                ?.toString() ??
                                                            'N/A',
                                                        parentContext: context,
                                                      ),
                                            ),
                                          if (isCurrentDate)
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: _isSubmitting
                                                  ? null
                                                  : () async {
                                                      final confirmed =
                                                          await _showConfirmDeleteDialog(
                                                              'Transaction',
                                                              transaction['product_name']
                                                                      ?.toString() ??
                                                                  '',
                                                              transaction['stock_transaction_id']
                                                                      ?.toString() ??
                                                                  '');
                                                      if (confirmed) {
                                                        await deleteStockTransaction(
                                                            transaction['stock_transaction_id']
                                                                    ?.toString() ??
                                                                '',
                                                            index);
                                                      }
                                                    },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (transactionIndex <
                                      entry['transactions'].length - 1)
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
  final String stockInId;

  const DeleteConfirmationDialog({
    Key? key,
    required this.type,
    required this.identifier,
    required this.stockInId,
  }) : super(key: key);

  @override
  _DeleteConfirmationDialogState createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<DeleteConfirmationDialog> {
  final TextEditingController billNoInputController = TextEditingController();
  String? errorMessage;

  @override
  void dispose() {
    print('Disposing DeleteConfirmationDialog controller');
    billNoInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isStockEntry = widget.type == 'Stock Entry';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text('Delete ${widget.type}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to delete this ${widget.type} (${widget.identifier})?'
            '${isStockEntry ? ' Enter the bill number to confirm.' : ''}',
          ),
          if (isStockEntry) ...[
            const SizedBox(height: 16),
            TextField(
              controller: billNoInputController,
              decoration: InputDecoration(
                labelText: 'Bill Number',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                errorText: errorMessage,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Z]')),
              ],
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            print('Canceling delete dialog for ${widget.type}: ${widget.identifier}');
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            if (isStockEntry &&
                billNoInputController.text != widget.identifier) {
              setState(() {
                errorMessage = 'Bill number does not match';
              });
              print(
                  'Bill number mismatch: entered=${billNoInputController.text}, expected=${widget.identifier}');
              return;
            }
            print('Confirming delete for ${widget.type}: ${widget.identifier}');
            Navigator.of(context).pop(true);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

class _EditStockEntryDialog extends StatefulWidget {
  final String stockInId;
  final Map<String, dynamic> stockEntry;
  final BuildContext parentContext;
  final bool isSubmitting;
  final Future<void> Function({
    required String stockInId,
    required String billNo,
    required String remarks,
    required BuildContext parentContext,
  }) onUpdate;
  final Future<void> Function(
    String billNo,
    String originalBillNo,
    Function(bool, bool) onResult,
  ) onCheckBillNo;

  const _EditStockEntryDialog({
    required this.stockInId,
    required this.stockEntry,
    required this.parentContext,
    required this.isSubmitting,
    required this.onUpdate,
    required this.onCheckBillNo,
  });

  @override
  _EditStockEntryDialogState createState() => _EditStockEntryDialogState();
}

class _EditStockEntryDialogState extends State<_EditStockEntryDialog> {
  late final TextEditingController billNoController;
  late final TextEditingController remarksController;
  bool isCheckingBillNo = false;
  bool billNoExists = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    billNoController = TextEditingController(
        text: widget.stockEntry['bill_no']?.toString() ?? '');
    remarksController = TextEditingController(
        text: widget.stockEntry['remarks']?.toString() ?? '');
    print(
        'Initialized EditStockEntryDialog: billNo=${billNoController.text}, remarks=${remarksController.text}');
  }

  @override
  void dispose() {
    print('Disposing EditStockEntryDialog controllers');
    _debounce?.cancel();
    billNoController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  void _checkBillNo(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {
      isCheckingBillNo = true;
      billNoExists = false;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onCheckBillNo(
          value,
          widget.stockEntry['bill_no']?.toString() ?? '',
          (exists, checking) {
            if (mounted) {
              setState(() {
                billNoExists = exists;
                isCheckingBillNo = checking;
              });
            }
          },
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 8,
      backgroundColor: Colors.white,
      title: const Text(
        'Edit Stock Entry',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF28A746),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: TextField(
                controller: billNoController,
                decoration: InputDecoration(
                  labelText: 'Bill No',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  errorText: billNoExists ? 'Bill number already exists' : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 20),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Z]')),
                ],
                textCapitalization: TextCapitalization.characters,
                onChanged: _checkBillNo,
              ),
            ),
            if (isCheckingBillNo)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Checking bill number...',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: TextField(
                controller: remarksController,
                decoration: InputDecoration(
                  labelText: 'Remarks',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 20),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            print('Canceling EditStockEntryDialog');
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: widget.isSubmitting || billNoExists || isCheckingBillNo
              ? null
              : () async {
                  final billNo = billNoController.text;
                  final remarks = remarksController.text;
                  print(
                      'Attempting to update stock entry: billNo=$billNo, remarks=$remarks');

                  if (billNo.isEmpty) {
                    if (widget.parentContext.mounted) {
                      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                        const SnackBar(
                            content: Text('Bill number is required')),
                      );
                    }
                    return;
                  }

                  try {
                    await widget.onUpdate(
                      stockInId: widget.stockInId,
                      billNo: billNo,
                      remarks: remarks,
                      parentContext: widget.parentContext,
                    );
                    if (mounted && context.mounted) {
                      print('Closing EditStockEntryDialog after update');
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    print('Update failed: $e');
                    if (widget.parentContext.mounted) {
                      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                        SnackBar(content: Text('Update failed')),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF28A746),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: widget.isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}

class _EditStockTransactionDialog extends StatefulWidget {
  final String stockTransactionId;
  final String stockInId;
  final int entryIndex;
  final Map<String, dynamic> transaction;
  final List<Map<String, String>> products;
  final BuildContext parentContext;
  final bool isSubmitting;
  final Future<void> Function({
    required String stockTransactionId,
    required String productId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) onUpdate;
  final Future<void> Function({
    required String stockInId,
    required String productId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) onInsert;

  const _EditStockTransactionDialog({
    required this.stockTransactionId,
    required this.stockInId,
    required this.entryIndex,
    required this.transaction,
    required this.products,
    required this.parentContext,
    required this.isSubmitting,
    required this.onUpdate,
    required this.onInsert,
  });

  @override
  _EditStockTransactionDialogState createState() =>
      _EditStockTransactionDialogState();
}

class _EditStockTransactionDialogState
    extends State<_EditStockTransactionDialog> {
  late final TextEditingController quantityController;
  String? selectedProduct;
  String? selectedProductId;
  bool isAddingNew = false;
  bool isUpdating = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    quantityController = TextEditingController(
        text: widget.transaction['quantity']?.toString() ?? '');
    selectedProduct = widget.transaction['product_name']?.toString() ?? '';
    selectedProductId = widget.transaction['product_id']?.toString() ?? '';
    print(
        'Initialized EditStockTransactionDialog: product=$selectedProduct, quantity=${quantityController.text}');
  }

  @override
  void dispose() {
    print('Disposing EditStockTransactionDialog controller');
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _addNewTransaction() async {
    final quantity = quantityController.text;
    final productId = selectedProductId;

    if (selectedProduct == null || productId == null || productId.isEmpty) {
      setState(() {
        errorText = 'Please select a product';
      });
      return;
    }

    if (quantity.isEmpty) {
      setState(() {
        errorText = 'Quantity is required';
      });
      return;
    }

    // Check for duplicate product in existing transactions
    final transactions =
        widget.transaction['transactions'] as List<Map<String, dynamic>>;
    final duplicate = transactions.any((t) =>
        t['product_id'] == productId &&
        t['stock_transaction_id'] != widget.stockTransactionId);

    if (duplicate) {
      setState(() {
        errorText = 'This product is already added in another transaction';
      });
      return;
    }

    setState(() => isAddingNew = true);
    try {
      await widget.onInsert(
        stockInId: widget.stockInId,
        productId: productId,
        quantity: quantity,
        entryIndex: widget.entryIndex,
        parentContext: widget.parentContext,
      );
      if (mounted && widget.parentContext.mounted) {
        print('Closing dialog after adding new transaction');
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Failed to add new transaction: $e');
      setState(() {
        errorText = 'Failed to add transaction: $e';
      });
    } finally {
      if (mounted) {
        setState(() => isAddingNew = false);
      }
    }
  }

  Future<void> _updateTransaction() async {
    final quantity = quantityController.text;
    final productId = selectedProductId;

    if (selectedProduct == null || productId == null || productId.isEmpty) {
      setState(() {
        errorText = 'Product is required';
      });
      return;
    }

    if (quantity.isEmpty) {
      setState(() {
        errorText = 'Quantity is required';
      });
      return;
    }

    setState(() => isUpdating = true);
    try {
      await widget.onUpdate(
        stockTransactionId: widget.stockTransactionId,
        productId: productId,
        quantity: quantity,
        entryIndex: widget.entryIndex,
        parentContext: widget.parentContext,
      );
      if (mounted && widget.parentContext.mounted) {
        print('Closing dialog after updating transaction');
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Failed to update transaction: $e');
      setState(() {
        errorText = 'Failed to update transaction: $e';
      });
    } finally {
      if (mounted) {
        setState(() => isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 8,
      backgroundColor: Colors.white,
      title: const Text(
        'Edit Stock Transaction',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF28A746),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: TextField(
                readOnly: true,
                enabled: false,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  labelText: selectedProduct ?? 'No product selected',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 20),
                  disabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                controller: TextEditingController(text: selectedProduct),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 20),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            if (isAddingNew || isUpdating)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: CircularProgressIndicator(color: Color(0xFF28A746)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.isSubmitting || isAddingNew || isUpdating
              ? null
              : () {
                  print('Canceling EditStockTransactionDialog');
                  Navigator.of(context).pop();
                },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: widget.isSubmitting || isAddingNew || isUpdating
              ? null
              : _updateTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF28A746),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: widget.isSubmitting || isAddingNew || isUpdating
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}