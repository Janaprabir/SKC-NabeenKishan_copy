import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef StockItem = Map<String, dynamic>;
typedef Product = Map<String, String>;
typedef TransferItem = Map<String, dynamic>;

class StockTransferPage extends StatefulWidget {
  @override
  _StockTransferPageState createState() => _StockTransferPageState();
}

class Godown {
  final int godownId;
  final String godownName;

  Godown({required this.godownId, required this.godownName});

  @override
  String toString() => godownName;
}

class _StockTransferPageState extends State<StockTransferPage> {
  List<Product> products = [];
  List<Godown> godowns = [];
  List<TransferItem> selectedTransfers = [];
  List<TransferItem> stockTransferEntries = [];
  List<StockItem> currentStock = [];
  String? selectedProduct;
  Godown? selectedTransferGodown;
  TextEditingController billNoController = TextEditingController();
  TextEditingController dcnController = TextEditingController();
  TextEditingController remarksController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  String? _empId;
  int? _godownId;
  bool _isFetchingProducts = false;
  bool _isFetchingGodowns = false;
  bool _isSubmitting = false;
  bool _isFetchingTransfers = false;
  bool isLoading = true;
  String? _currentStockTransferId;
  bool _isEditingExistingEntry = false;
  String? quantityHintText;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      fetchProducts(),
      fetchGodowns(),
      _loadSessionData(),
      fetchStockTransferEntries(),
    ]);
  }

  @override
  void dispose() {
    billNoController.dispose();
    dcnController.dispose();
    remarksController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    setState(() => isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empId = prefs.getString('emp_id');
      _godownId = prefs.getInt('godown_id');
      isLoading = false;
    });
    if (_godownId != null) {
      await _fetchCurrentStock(_godownId!);
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
          products = data.map<Map<String, String>>((product) {
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
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error loading products: $e')),
        // );
        debugPrint('Error loading products: $e');
      }
    } finally {
      setState(() => _isFetchingProducts = false);
    }
  }

  Future<void> fetchGodowns() async {
    setState(() => _isFetchingGodowns = true);
    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=godown_master'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          godowns = data.map((godown) {
            return Godown(
              godownId: int.parse(godown['godown_id'].toString()),
              godownName: godown['godown_name'].toString(),
            );
          }).toList();
        });
      } else {
        throw Exception('Failed to load godowns data');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error loading godowns: $e')),
        // );
        debugPrint('Error loading godowns: $e');
      }
    } finally {
      setState(() => _isFetchingGodowns = false);
    }
  }

  Future<void> _fetchCurrentStock(int godownId) async {
    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/GodownStockController/currentGodownStock.php?godown_id=$godownId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          currentStock = data.map<StockItem>((stock) {
            return {
              'product_id': stock['product_id'].toString(),
              'quantity': int.parse(stock['quantity'].toString()),
              'product_name': stock['product_name'].toString(),
            };
          }).toList();
        });
      } else {
        throw Exception('Failed to load current stock');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error loading current stock: $e')),
        // );
        debugPrint('Error loading current stock: $e');
      }
      setState(() {
        currentStock = [];
      });
    }
  }

  Future<void> fetchStockTransferEntries() async {
    setState(() => _isFetchingTransfers = true);
    try {
      const limit = 300;
      await _loadSessionData();
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/get_all_stock_transfer_entries.php?limit=$limit&godown_id=$_godownId';
      print('Fetching stock-transfer entries URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock-Transfer Entries Status: ${response.statusCode}');
      print('Stock-Transfer Entries Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          stockTransferEntries = data.map((entry) {
            final entryMap = Map<String, dynamic>.from(entry);
            entryMap['isExpanded'] = false;
            entryMap['transactions'] = <Map<String, dynamic>>[];
            entryMap['isFetchingTransactions'] = false;
            if (entryMap['stock_transfer_date'] != null) {
              try {
                final date = DateTime.parse(entryMap['stock_transfer_date']);
                entryMap['stock_transfer_date'] =
                    DateFormat('dd/MM/yyyy').format(date);
              } catch (e) {
                print('Error parsing date: ${entryMap['stock_transfer_date']}');
              }
            }
            return entryMap;
          }).toList();
        });
      } else {
        throw Exception(
            'Failed to load stock-transfer entries. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error loading stock-transfer entries: $e')),
        // );
        debugPrint(
            'Error loading stock-transfer entries: $e');
      }
    } finally {
      setState(() => _isFetchingTransfers = false);
    }
  }

  Future<void> fetchStockTransferTransactions(
      String stockTransferId, int entryIndex) async {
    setState(() {
      stockTransferEntries[entryIndex]['isFetchingTransactions'] = true;
    });
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/get_stock_transfer_transactions.php?stock_transfer_id=$stockTransferId';
      print('Fetching stock-transfer transactions URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock-Transfer Transactions Status: ${response.statusCode}');
      print('Stock-Transfer Transactions Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          stockTransferEntries[entryIndex]['transactions'] = data
              .map((transaction) => Map<String, dynamic>.from(transaction))
              .toList();
          stockTransferEntries[entryIndex]['isFetchingTransactions'] = false;
          stockTransferEntries[entryIndex]['isExpanded'] = true;
        });
      } else {
        throw Exception(
            'Failed to load stock-transfer transactions. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //       content: Text('Error loading stock-transfer transactions: $e')),
        // );
        debugPrint(
            'Error loading stock-transfer transactions: $e');
      }
      setState(() {
        stockTransferEntries[entryIndex]['isFetchingTransactions'] = false;
      });
    }
  }

  Future<Map<String, dynamic>?> fetchStockTransferEntry(
      String stockTransferId) async {
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/get_stock_transfer_entry.php?stock_transfer_id=$stockTransferId';
      print('Fetching stock-transfer entry URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock-Transfer Entry Fetch Status: ${response.statusCode}');
      print('Stock-Transfer Entry Fetch Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['stock_transfer_date'] != null) {
            try {
              final date = DateTime.parse(data['stock_transfer_date']);
              data['stock_transfer_date'] =
                  DateFormat('dd/MM/yyyy').format(date);
            } catch (e) {
              print(
                  'Error parsing date in fetchStockTransferEntry: ${data['stock_transfer_date']}');
            }
          }
          return data;
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to fetch stock-transfer entry. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Error fetching stock-transfer entry: $e')),
      //   );
      // }
      print('Error fetching stock-transfer entry: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchStockTransferTransaction(
      String stockTransactionId) async {
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/get_stock_transfer_transaction.php?stock_transaction_id=$stockTransactionId';
      print('Fetching stock-transfer transaction URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock-Transfer Transaction Fetch Status: ${response.statusCode}');
      print('Stock-Transfer Transaction Fetch Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to fetch stock-transfer transaction. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //         content: Text('Error fetching stock-transfer transaction: $e')),
      //   );
      // }
      print('Error fetching stock-transfer transaction: $e');
      return null;
    }
  }

  Future<void> updateStockTransferEntry({
    required String stockTransferId,
    required String billNo,
    required String dcn,
    required String remarks,
    required BuildContext parentContext,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final data = {
        'stock_transfer_id': stockTransferId,
        'bill_no': billNo,
        'dcn': dcn,
        'remarks': remarks,
      };

      print('Updating stock-transfer entry data: $data');

      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/update_stock_transfer_entry.php'),
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock-Transfer Entry Update Status: ${response.statusCode}');
      print('Stock-Transfer Entry Update Response: ${response.body}');

      if (response.statusCode == 200) {
        if (parentContext.mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(
                content: Text('Stock-transfer entry updated successfully')),
          );
        }
        await fetchStockTransferEntries();
      } else {
        throw Exception(
            'Failed to update stock-transfer entry. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating stock-transfer entry: $e');
      // if (parentContext.mounted) {
      //   ScaffoldMessenger.of(parentContext).showSnackBar(
      //     SnackBar(content: Text('Error updating stock-transfer entry: $e')),
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> updateStockTransferTransaction({
    required String stockTransactionId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final data = {
        'stock_transaction_id': stockTransactionId,
        'quantity': quantity,
      };

      print('Updating stock-transfer transaction data: $data');

      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/update_stock_transfer_transaction.php'),
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock-Transfer Transaction Update Status: ${response.statusCode}');
      print('Stock-Transfer Transaction Update Response: ${response.body}');

      if (response.statusCode == 200) {
        if (parentContext.mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(
                content:
                    Text('Stock-transfer transaction updated successfully')),
          );
        }
        await fetchStockTransferTransactions(
            stockTransferEntries[entryIndex]['stock_transfer_id'].toString(),
            entryIndex);
      } else {
        throw Exception(
            'Failed to update stock-transfer transaction. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating stock-transfer transaction: $e');
      // if (parentContext.mounted) {
      //   ScaffoldMessenger.of(parentContext).showSnackBar(
      //     SnackBar(
      //         content: Text('Error updating stock-transfer transaction: $e')),
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> insertStockTransferTransaction({
    required String stockTransferId,
    required String productId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final data = {
        'stock_transfer_id': stockTransferId,
        'product_id': productId,
        'quantity': quantity,
      };

      print('Inserting new stock-transfer transaction data: $data');

      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/insert_stock_transfer_transaction.php'),
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock-Transfer Transaction Insert Status: ${response.statusCode}');
      print('Stock-Transfer Transaction Insert Response: ${response.body}');

      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody['message'] ==
                'Stock-transfer transaction created successfully') {
          if (parentContext.mounted) {
            ScaffoldMessenger.of(parentContext).showSnackBar(
              const SnackBar(
                  content: Text(
                      'New stock-transfer transaction added successfully')),
            );
          }
          await fetchStockTransferTransactions(stockTransferId, entryIndex);
        } else {
          throw Exception('Unexpected response: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to insert stock-transfer transaction. Status code: ${response.statusCode}, Response: ${response.body}');
      }
    } catch (e) {
      print('Error inserting stock-transfer transaction: $e');
      // if (parentContext.mounted) {
      //   ScaffoldMessenger.of(parentContext).showSnackBar(
      //     SnackBar(content: Text('Error adding new transaction: $e')),
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> deleteStockTransferEntry(String stockTransferId) async {
    setState(() => _isSubmitting = true);
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/delete_stock_transfer_entry.php?stock_transfer_id=$stockTransferId';
      print('Deleting stock-transfer entry URL: $url');

      final response = await http.delete(Uri.parse(url));
      print('Stock-Transfer Entry Delete Status: ${response.statusCode}');
      print('Stock-Transfer Entry Delete Response: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Stock-transfer entry deleted successfully')),
          );
        }
        await fetchStockTransferEntries();
        if (_godownId != null) {
          await _fetchCurrentStock(_godownId!);
        }
      } else {
        throw Exception(
            'Failed to delete stock-transfer entry. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting stock-transfer entry: $e');
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Error deleting stock-transfer entry: $e')),
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> deleteStockTransferTransaction(
      String stockTransactionId, int entryIndex) async {
    setState(() => _isSubmitting = true);
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/delete_stock_transfer_transaction.php?stock_transaction_id=$stockTransactionId';
      print('Deleting stock-transfer transaction URL: $url');

      final response = await http.delete(Uri.parse(url));
      print('Stock-Transfer Transaction Delete Status: ${response.statusCode}');
      print('Stock-Transfer Transaction Delete Response: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Stock-transfer transaction deleted successfully')),
          );
        }
        await fetchStockTransferTransactions(
            stockTransferEntries[entryIndex]['stock_transfer_id'].toString(),
            entryIndex);
        if (_godownId != null) {
          await _fetchCurrentStock(_godownId!);
        }
      } else {
        throw Exception(
            'Failed to delete stock-transfer transaction. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting stock-transfer transaction: $e');
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(
      //         content: Text('Error deleting stock-transfer transaction: $e')),
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<bool> checkProductInTransactions(
      String stockTransferId, String productId) async {
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/get_stock_transfer_transactions.php?stock_transfer_id=$stockTransferId';
      print('Checking product in transactions URL: $url');
      print(
          'Checking for productId: $productId (type: ${productId.runtimeType})');

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
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Error checking product: $e')),
      //   );
      // }
      return false;
    }
  }

  void _addTransfer() {
    if (selectedTransferGodown == null ||
        selectedProduct == null ||
        quantityController.text.isEmpty ||
        billNoController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Missing Information'),
          content: const Text(
              'Please select a godown, product, enter bill number, and quantity'),
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

    final productId = products.firstWhere(
      (product) => product['product_name'] == selectedProduct,
      orElse: () => {'product_id': '', 'product_name': ''},
    )['product_id'];

    final StockItem defaultStockItem = {
      'product_id': '',
      'quantity': 0,
      'product_name': selectedProduct ?? '',
    };

    final stockItem = currentStock.firstWhere(
      (stock) => stock['product_id'] == productId,
      orElse: () => defaultStockItem,
    );

    final availableQuantity =
        int.tryParse(stockItem['quantity'].toString()) ?? 0;
    final enteredQuantity = int.tryParse(quantityController.text) ?? 0;

    if (availableQuantity <= 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Stock Available'),
          content: Text('No stock available for ${stockItem['product_name']}'),
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

    if (enteredQuantity > availableQuantity) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Insufficient Stock'),
          content: Text(
            'Insufficient stock for ${stockItem['product_name']}. Available: $availableQuantity',
          ),
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

    final existingTransfer = selectedTransfers.firstWhere(
      (transfer) =>
          transfer['product_id'] == productId &&
          transfer['transfered_godown_id'] ==
              selectedTransferGodown!.godownId.toString(),
      orElse: () => <String, dynamic>{},
    );

    if (existingTransfer.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Transfer'),
          content: Text(
              'The transfer of "${selectedProduct}" to "${selectedTransferGodown!.godownName}" is already added.'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  selectedProduct = null;
                  quantityController.clear();
                  quantityHintText = null;
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

    if (_isEditingExistingEntry && _currentStockTransferId != null) {
      print(
          'Checking if product exists for stock_transfer_id: $_currentStockTransferId');
      checkProductInTransactions(_currentStockTransferId!, productId!)
          .then((productExists) {
        if (productExists) {
          print(
              'Product "$selectedProduct" already exists in stock-transfer entry. Showing dialog.');
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Product Already Exists'),
              content: Text(
                  'The product "${selectedProduct}" is already included in this stock-transfer entry.'),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedProduct = null;
                      quantityController.clear();
                      quantityHintText = null;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          print(
              'Product "$selectedProduct" does not exist in stock-transfer entry. Proceeding to add.');
          setState(() {
            selectedTransfers.add({
              'product_id': productId,
              'product_name': selectedProduct!,
              'transfered_godown_id':
                  selectedTransferGodown!.godownId.toString(),
              'destination_godown': selectedTransferGodown!.godownName,
              'quantity': quantityController.text,
            });
            selectedProduct = null;
            quantityController.clear();
            quantityHintText = null;
          });
        }
      });
    } else {
      setState(() {
        selectedTransfers.add({
          'product_id': productId!,
          'product_name': selectedProduct!,
          'transfered_godown_id': selectedTransferGodown!.godownId.toString(),
          'destination_godown': selectedTransferGodown!.godownName,
          'quantity': quantityController.text,
        });
        selectedProduct = null;
        quantityController.clear();
        quantityHintText = null;
      });
    }
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

    if (_godownId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source Godown ID is not available')),
        );
      }
      return;
    }

    if (selectedTransferGodown == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a destination godown')),
        );
      }
      return;
    }

    if (selectedTransfers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one transfer')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isEditingExistingEntry && _currentStockTransferId != null) {
        for (var transfer in selectedTransfers) {
          final transactionData = {
            'stock_transfer_id': _currentStockTransferId!,
            'product_id': transfer['product_id'],
            'quantity': transfer['quantity'],
          };

          print('Submitting transaction data: $transactionData');

          final transactionResponse = await http.post(
            Uri.parse(
                'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/insert_stock_transfer_transaction.php'),
            body: transactionData,
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          );

          print(
              'Transaction Submission Status: ${transactionResponse.statusCode}');
          print('Transaction Submission Response: ${transactionResponse.body}');

          if (transactionResponse.statusCode != 201) {
            throw Exception(
                'Failed to post transaction for ${transfer['product_name']}: ${transactionResponse.body}');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Transactions added to stock-transfer entry successfully')),
          );
        }
        resetForm();
        await fetchStockTransferEntries();
        if (_godownId != null) {
          await _fetchCurrentStock(_godownId!);
        }
      } else {
        final transferData = {
          'src_godown_id': _godownId.toString(),
          'dest_godown_id': selectedTransferGodown!.godownId.toString(),
          'godown_keeper_id': _empId ?? '',
          'bill_no': billNoController.text,
          'dcn': dcnController.text,
          'remarks': remarksController.text,
        };

        print('Submitting stock transfer data: $transferData');

        final transferResponse = await http.post(
          Uri.parse(
              'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/insert_stock_transfer_entries.php'),
          body: transferData,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        );

        print(
            'Stock Transfer Submission Status: ${transferResponse.statusCode}');
        print('Stock Transfer Submission Response: ${transferResponse.body}');

        if (transferResponse.statusCode == 201) {
          final responseBody = jsonDecode(transferResponse.body);
          if (responseBody is Map<String, dynamic> &&
              responseBody.containsKey('stock_transfer_id') &&
              (responseBody['message'] ==
                      'Stock-transfer entry created successfully' ||
                  responseBody['message'] ==
                      'Stock transfer entry created successfully')) {
            final stockTransferId =
                responseBody['stock_transfer_id'].toString();

            for (var transfer in selectedTransfers) {
              final transactionData = {
                'stock_transfer_id': stockTransferId,
                'product_id': transfer['product_id'],
                'quantity': transfer['quantity'],
              };

              print('Submitting transaction data: $transactionData');

              final transactionResponse = await http.post(
                Uri.parse(
                    'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockTransferController/insert_stock_transfer_transaction.php'),
                body: transactionData,
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              );

              print(
                  'Transaction Submission Status: ${transactionResponse.statusCode}');
              print(
                  'Transaction Submission Response: ${transactionResponse.body}');

              if (transactionResponse.statusCode != 201) {
                throw Exception(
                    'Failed to post transaction for ${transfer['product_name']}: ${transactionResponse.body}');
              }
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Stock-transfer entry and transactions submitted successfully')),
              );
            }
            resetForm();
            await fetchStockTransferEntries();
            if (_godownId != null) {
              await _fetchCurrentStock(_godownId!);
            }
          } else {
            throw Exception(
                'Unexpected stock transfer submission response: ${transferResponse.body}');
          }
        } else {
          throw Exception(
              'Failed to create stock-transfer entry. Status code: ${transferResponse.statusCode}, Response: ${transferResponse.body}');
        }
      }
    } catch (e) {
      print('Error during submission: $e');
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Error during submission: $e')),
      //   );
      // }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void resetForm() {
    setState(() {
      selectedTransferGodown = null;
      selectedProduct = null;
      selectedTransfers.clear();
      billNoController.clear();
      dcnController.clear();
      remarksController.clear();
      quantityController.clear();
      quantityHintText = null;
      _currentStockTransferId = null;
      _isEditingExistingEntry = false;
      for (var entry in stockTransferEntries) {
        entry['transactions'] = <Map<String, dynamic>>[];
        entry['isExpanded'] = false;
        entry['isFetchingTransactions'] = false;
      }
    });
  }

  void _populateFormForExistingEntry({
    required String stockTransferId,
    required String billNo,
    required String dcn,
    required String remarks,
    required int entryIndex,
  }) {
    // Find the destination godown from the stock transfer entry
    final entry = stockTransferEntries[entryIndex];
    final destGodownId = int.tryParse(entry['dest_godown_id'].toString());
    Godown? destinationGodown;

    if (destGodownId != null) {
      destinationGodown = godowns.firstWhere(
        (godown) => godown.godownId == destGodownId,
        orElse: () => godowns.first,
      );
    }

    setState(() {
      _currentStockTransferId = stockTransferId;
      _isEditingExistingEntry = true;
      billNoController.text = billNo;
      dcnController.text = dcn;
      remarksController.text = remarks;
      selectedTransfers.clear();
      selectedProduct = null;
      quantityController.clear();
      quantityHintText = null;
      selectedTransferGodown = destinationGodown; // Set the destination godown
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adding products to Bill No: $billNo')),
    );
  }

  Future<void> _showEditStockTransferEntryDialog(
      String stockTransferId, BuildContext parentContext) async {
    final stockTransferEntry = await fetchStockTransferEntry(stockTransferId);
    if (stockTransferEntry == null || !parentContext.mounted) return;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => _EditStockTransferEntryDialog(
        stockTransferId: stockTransferId,
        stockTransferEntry: stockTransferEntry,
        parentContext: parentContext,
        isSubmitting: _isSubmitting,
        onUpdate: updateStockTransferEntry,
      ),
    );
  }

  Future<void> _showEditStockTransferTransactionDialog({
    required String stockTransactionId,
    required int entryIndex,
    required String stockTransferId,
    required BuildContext parentContext,
  }) async {
    final transaction = await fetchStockTransferTransaction(stockTransactionId);
    if (transaction == null || !parentContext.mounted) return;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => _EditStockTransferTransactionDialog(
        stockTransactionId: stockTransactionId,
        stockTransferId: stockTransferId,
        entryIndex: entryIndex,
        transaction: transaction,
        products: products,
        currentStock: currentStock,
        parentContext: parentContext,
        isSubmitting: _isSubmitting,
        onUpdate: updateStockTransferTransaction,
        onInsert: insertStockTransferTransaction,
      ),
    );
  }

  Future<bool> _showConfirmDeleteDialog(
      String type, String identifier, String stockTransferId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DeleteConfirmationDialog(
        type: type,
        identifier: identifier,
        stockTransferId: stockTransferId,
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
              ? 'Add to Existing Stock-Transfer Entry'
              : 'Stock Transfer',
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
                  readOnly: _isEditingExistingEntry,
                ),
                SizedBox(height: screenHeight * 0.01),
                _buildTextField(
                  controller: dcnController,
                  label: 'DCN',
                  keyboardType: TextInputType.text,
                  inputFormatters: [],
                  textCapitalization: TextCapitalization.characters,
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  readOnly: _isEditingExistingEntry,
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
                SizedBox(height: screenHeight * 0.01),
                _buildGodownDropdownField(
                  value: selectedTransferGodown,
                  items: godowns
                      .where((godown) => godown.godownId != _godownId)
                      .toList(),
                  label: 'Select Destination Godown',
                  onChanged: (newValue) =>
                      setState(() => selectedTransferGodown = newValue),
                  isMobile: isMobile,
                  textFieldPadding: textFieldPadding,
                  isLoading: _isFetchingGodowns,
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
                        hintText: quantityHintText,
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    SizedBox(
                      width: screenWidth * 0.12,
                      height: screenHeight * 0.06,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _addTransfer,
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
                if (selectedTransfers.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.02),
                      Center(child: _buildSelectedTransfersTable(isMobile)),
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
                    'Stock-Transfer Entries',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                _isFetchingTransfers
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF28A746)))
                    : stockTransferEntries.isEmpty
                        ? Center(
                            child: Text(
                              'No stock-transfer entries available.',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade600),
                            ),
                          )
                        : _buildStockTransferEntriesAccordion(isMobile),
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
    String? hintText,
  }) {
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
    required List<Product> items,
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
                  vertical: 20.0,
                  horizontal: textFieldPadding,
                ),
              ),
              value: value,
              onChanged: (newValue) {
                onChanged(newValue);
                if (newValue != null) {
                  final productId = products.firstWhere(
                    (product) => product['product_name'] == newValue,
                    orElse: () => {'product_id': '', 'product_name': ''},
                  )['product_id'];

                  final StockItem defaultStockItem = {
                    'product_id': '',
                    'quantity': 0,
                    'product_name': newValue,
                  };

                  final stockItem = currentStock.firstWhere(
                    (stock) => stock['product_id'] == productId,
                    orElse: () => defaultStockItem,
                  );

                  setState(() {
                    quantityHintText = 'Available: ${stockItem['quantity']}';
                  });
                } else {
                  setState(() {
                    quantityHintText = null;
                  });
                }
              },
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['product_name'],
                  child: Text(item['product_name']!),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildGodownDropdownField({
    required Godown? value,
    required List<Godown> items,
    required String label,
    required void Function(Godown?) onChanged,
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
          : DropdownButtonFormField<Godown>(
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
              items: items.map((godown) {
                return DropdownMenuItem<Godown>(
                  value: godown,
                  child: Text(godown.godownName),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildSelectedTransfersTable(bool isMobile) {
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
                child: Text('Target Godown',
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
          rows: selectedTransfers.map((transfer) {
            return DataRow(
              color: MaterialStateColor.resolveWith(
                (states) => selectedTransfers.indexOf(transfer) % 2 == 0
                    ? Colors.grey.shade50
                    : Colors.white,
              ),
              cells: [
                DataCell(Text(transfer['product_name'])),
                DataCell(Text(transfer['destination_godown'])),
                DataCell(Text(transfer['quantity'])),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        selectedTransfers.remove(transfer);
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

  Widget _buildStockTransferEntriesAccordion(bool isMobile) {
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stockTransferEntries.length,
      itemBuilder: (context, index) {
        final entry = stockTransferEntries[index];
        final isCurrentDate = entry['stock_transfer_date'] == currentDate;

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
                        'Source: ${entry['src_godown_name'] ?? ''}',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                      Text(
                        'Destination: ${entry['dest_godown_name'] ?? ''}',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                      Text(
                        'Date: ${entry['stock_transfer_date'] ?? ''}',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                      ),
                      Text(
                        'DCN: ${entry['dcn'] ?? ''}',
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
                                  stockTransferId:
                                      entry['stock_transfer_id'].toString(),
                                  billNo: entry['bill_no']?.toString() ?? '',
                                  dcn: entry['dcn']?.toString() ?? '',
                                  remarks: entry['remarks']?.toString() ?? '',
                                  entryIndex: index,
                                ),
                      ),
                    if (isCurrentDate)
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: _isSubmitting
                            ? null
                            : () => _showEditStockTransferEntryDialog(
                                entry['stock_transfer_id'].toString(), context),
                      ),
                    if (isCurrentDate)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final confirmed =
                                    await _showConfirmDeleteDialog(
                                  'Stock-Transfer Entry',
                                  entry['bill_no'] ?? '',
                                  entry['stock_transfer_id'].toString(),
                                );
                                if (confirmed) {
                                  await deleteStockTransferEntry(
                                      entry['stock_transfer_id'].toString());
                                }
                              },
                      ),
                  ],
                ),
              ],
            ),
            onExpansionChanged: (expanded) {
              setState(() {
                stockTransferEntries[index]['isExpanded'] = expanded;
              });
              if (expanded && entry['transactions'].isEmpty) {
                fetchStockTransferTransactions(
                    entry['stock_transfer_id'].toString(), index);
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
                                            Text(
                                              'Pre Stock: ${transaction['pre_stock_level']?.toString() ?? 'N/A'}',
                                              style: TextStyle(
                                                fontSize: isMobile ? 12 : 14,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
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
                                                      _showEditStockTransferTransactionDialog(
                                                        stockTransactionId:
                                                            transaction['stock_transaction_id']
                                                                    ?.toString() ??
                                                                '',
                                                        entryIndex: index,
                                                        stockTransferId: entry[
                                                                    'stock_transfer_id']
                                                                ?.toString() ??
                                                            '',
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
                                                      final confirmed = await _showConfirmDeleteDialog(
                                                          'Transaction',
                                                          transaction['product_name']
                                                                  ?.toString() ??
                                                              '',
                                                          transaction['stock_transaction_id']
                                                                  ?.toString() ??
                                                              '');
                                                      if (confirmed) {
                                                        await deleteStockTransferTransaction(
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
  final String stockTransferId;

  const DeleteConfirmationDialog({
    Key? key,
    required this.type,
    required this.identifier,
    required this.stockTransferId,
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
    bool isStockTransferEntry = widget.type == 'Stock-Transfer Entry';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text('Delete ${widget.type}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to delete this ${widget.type} (${widget.identifier})?'
            '${isStockTransferEntry ? ' Enter the bill number to confirm.' : ''}',
          ),
          if (isStockTransferEntry) ...[
            const SizedBox(height: 16),
            TextField(
              controller: billNoInputController,
              decoration: InputDecoration(
                labelText: 'Bill Number',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            print(
                'Canceling delete dialog for ${widget.type}: ${widget.identifier}');
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            if (isStockTransferEntry &&
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

class _EditStockTransferEntryDialog extends StatefulWidget {
  final String stockTransferId;
  final Map<String, dynamic> stockTransferEntry;
  final BuildContext parentContext;
  final bool isSubmitting;
  final Future<void> Function({
    required String stockTransferId,
    required String billNo,
    required String dcn,
    required String remarks,
    required BuildContext parentContext,
  }) onUpdate;

  const _EditStockTransferEntryDialog({
    required this.stockTransferId,
    required this.stockTransferEntry,
    required this.parentContext,
    required this.isSubmitting,
    required this.onUpdate,
  });

  @override
  _EditStockTransferEntryDialogState createState() =>
      _EditStockTransferEntryDialogState();
}

class _EditStockTransferEntryDialogState
    extends State<_EditStockTransferEntryDialog> {
  late final TextEditingController billNoController;
  late final TextEditingController dcnController;
  late final TextEditingController remarksController;

  @override
  void initState() {
    super.initState();
    billNoController = TextEditingController(
        text: widget.stockTransferEntry['bill_no']?.toString() ?? '');
    dcnController = TextEditingController(
        text: widget.stockTransferEntry['dcn']?.toString() ?? '');
    remarksController = TextEditingController(
        text: widget.stockTransferEntry['remarks']?.toString() ?? '');
    print(
        'Initialized EditStockTransferEntryDialog: billNo=${billNoController.text}, dcn=${dcnController.text}, remarks=${remarksController.text}');
  }

  @override
  void dispose() {
    print('Disposing EditStockTransferEntryDialog controllers');
    billNoController.dispose();
    dcnController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 8,
      backgroundColor: Colors.white,
      title: const Text(
        'Edit Stock-Transfer Entry',
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Z]')),
                ],
                textCapitalization: TextCapitalization.characters,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: TextField(
                controller: dcnController,
                decoration: InputDecoration(
                  labelText: 'DCN',
                  labelStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                ),
                textCapitalization: TextCapitalization.characters,
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
            print('Canceling EditStockTransferEntryDialog');
            Navigator.of(context).pop();
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: widget.isSubmitting
              ? null
              : () async {
                  final billNo = billNoController.text;
                  final dcn = dcnController.text;
                  final remarks = remarksController.text;
                  print(
                      'Attempting to update stock-transfer entry: billNo=$billNo, dcn=$dcn, remarks=$remarks');

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
                      stockTransferId: widget.stockTransferId,
                      billNo: billNo,
                      dcn: dcn,
                      remarks: remarks,
                      parentContext: widget.parentContext,
                    );
                    // Close the dialog after successful update
                    if (mounted && context.mounted) {
                      print(
                          'Closing EditStockTransferEntryDialog after successful update');
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    print('Update failed: $e');
                    if (widget.parentContext.mounted) {
                      // ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                      //   SnackBar(content: Text('Update failed: $e')),
                      // );
                      debugPrint(
                          'Error updating stock-transfer entry: $e');
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

class _EditStockTransferTransactionDialog extends StatefulWidget {
  final String stockTransactionId;
  final String stockTransferId;
  final int entryIndex;
  final Map<String, dynamic> transaction;
  final List<Product> products;
  final List<StockItem> currentStock;
  final BuildContext parentContext;
  final bool isSubmitting;
  final Future<void> Function({
    required String stockTransactionId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) onUpdate;
  final Future<void> Function({
    required String stockTransferId,
    required String productId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) onInsert;

  const _EditStockTransferTransactionDialog({
    required this.stockTransactionId,
    required this.stockTransferId,
    required this.entryIndex,
    required this.transaction,
    required this.products,
    required this.currentStock,
    required this.parentContext,
    required this.isSubmitting,
    required this.onUpdate,
    required this.onInsert,
  });

  @override
  _EditStockTransferTransactionDialogState createState() =>
      _EditStockTransferTransactionDialogState();
}

class _EditStockTransferTransactionDialogState
    extends State<_EditStockTransferTransactionDialog> {
  late final TextEditingController quantityController;
  String? selectedProduct;
  String? selectedProductId;
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
        'Initialized EditStockTransferTransactionDialog: product=$selectedProduct, quantity=${quantityController.text}');
  }

  @override
  void dispose() {
    print('Disposing EditStockTransferTransactionDialog controller');
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _updateTransaction() async {
    final quantity = quantityController.text;

    if (quantity.isEmpty) {
      setState(() {
        errorText = 'Quantity is required';
      });
      return;
    }

    final enteredQuantity = int.tryParse(quantity) ?? 0;
    final stockItem = widget.currentStock.firstWhere(
      (stock) => stock['product_id'] == selectedProductId,
      orElse: () => <String, dynamic>{
        'product_id': '',
        'quantity': 0,
        'product_name': selectedProduct ?? '',
      },
    );

    final availableQuantity = stockItem['quantity'] as int;

    if (availableQuantity <= 0) {
      setState(() {
        errorText = 'No stock available for ${stockItem['product_name']}';
      });
      return;
    }

    if (enteredQuantity > availableQuantity) {
      setState(() {
        errorText =
            'Insufficient stock for ${stockItem['product_name']}. Available: $availableQuantity';
      });
      return;
    }

    setState(() => isUpdating = true);
    try {
      await widget.onUpdate(
        stockTransactionId: widget.stockTransactionId,
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
        'Edit Stock-Transfer Transaction',
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
            if (isUpdating)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: CircularProgressIndicator(color: Color(0xFF28A746)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.isSubmitting || isUpdating
              ? null
              : () {
                  print('Canceling EditStockTransferTransactionDialog');
                  Navigator.of(context).pop();
                },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed:
              widget.isSubmitting || isUpdating ? null : _updateTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF28A746),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: widget.isSubmitting || isUpdating
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
