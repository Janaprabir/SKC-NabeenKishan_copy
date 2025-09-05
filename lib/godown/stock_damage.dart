import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StockDamagePage extends StatefulWidget {
  @override
  _StockDamagePageState createState() => _StockDamagePageState();
}

class _StockDamagePageState extends State<StockDamagePage> {
  List<Map<String, String>> products = [];
  List<Map<String, String>> selectedProducts = [];
  List<Map<String, dynamic>> stockDamageEntries = [];
  List<Map<String, dynamic>> currentStock = [];
  String? selectedProduct;
  TextEditingController billNoController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController remarksController = TextEditingController();
  int? godownId;
  String? _empId;
  bool isLoading = true;
  bool _isSubmitting = false;
  bool _isFetchingProducts = false;
  bool _isFetchingStockDamageEntries = false;
  String? _currentStockDamageId;
  bool _isEditingExistingEntry = false;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    fetchStockDamageEntries();
    _loadGodownId();
    _loadSessionData();
  }

  @override
  void dispose() {
    billNoController.dispose();
    quantityController.dispose();
    remarksController.dispose();
    super.dispose();
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
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error loading products: $e')),
        // );
        print('Error loading products: $e');
      }
    } finally {
      setState(() => _isFetchingProducts = false);
    }
  }

  Future<void> fetchStockDamageEntries() async {
    setState(() => _isFetchingStockDamageEntries = true);
    try {
      const limit = 300;
      await _loadGodownId();
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/get_all_stock_damage_entries.php?limit=$limit&godown_id=$godownId';
      print('Fetching stock-damage entries URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock-Damage Entries Status: ${response.statusCode}');
      print('Stock-Damage Entries Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          stockDamageEntries = data.map((entry) {
            final entryMap = Map<String, dynamic>.from(entry);
            entryMap['isExpanded'] = false;
            entryMap['transactions'] = <Map<String, dynamic>>[];
            entryMap['isFetchingTransactions'] = false;
            if (entryMap['stock_damage_date'] != null) {
              try {
                final date = DateTime.parse(entryMap['stock_damage_date']);
                entryMap['stock_damage_date'] =
                    DateFormat('dd/MM/yyyy').format(date);
              } catch (e) {
                print('Error parsing date: ${entryMap['stock_damage_date']}');
              }
            }
            return entryMap;
          }).toList();
        });
      } else {
        throw Exception(
            'Failed to load stock-damage entries. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error loading stock-damage entries: $e')),
        // );
        print('Error loading stock-damage entries: $e');
      }
    } finally {
      setState(() => _isFetchingStockDamageEntries = false);
    }
  }

  Future<void> fetchStockDamageTransactions(
      String stockDamageId, int entryIndex) async {
    setState(() {
      stockDamageEntries[entryIndex]['isFetchingTransactions'] = true;
    });
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/get_stock_damage_transactions.php?stock_damage_id=$stockDamageId';
      print('Fetching stock-damage transactions URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock-Damage Transactions Status: ${response.statusCode}');
      print('Stock-Damage Transactions Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          stockDamageEntries[entryIndex]['transactions'] = data
              .map((transaction) => Map<String, dynamic>.from(transaction))
              .toList();
          stockDamageEntries[entryIndex]['isFetchingTransactions'] = false;
          stockDamageEntries[entryIndex]['isExpanded'] = true;
        });
      } else {
        throw Exception(
            'Failed to load stock-damage transactions. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error loading stock-damage transactions: $e')),
        // );
        print('Error loading stock-damage transactions: $e');
      }
      setState(() {
        stockDamageEntries[entryIndex]['isFetchingTransactions'] = false;
      });
    }
  }

  Future<void> fetchCurrentStock(int godownId) async {
    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/GodownStockController/currentGodownStock.php?godown_id=$godownId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          currentStock = data.map((stock) {
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
        print('Error loading current stock: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> fetchStockDamageEntry(String stockDamageId) async {
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/get_stock_damage_entry.php?stock_damage_id=$stockDamageId';
      print('Fetching stock-damage entry URL: $url');
 
      final response = await http.get(Uri.parse(url));
      print('Stock-Damage Entry Fetch Status: ${response.statusCode}');
      print('Stock-Damage Entry Fetch Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['stock_damage_date'] != null) {
            try {
              final date = DateTime.parse(data['stock_damage_date']);
              data['stock_damage_date'] = DateFormat('dd/MM/yyyy').format(date);
            } catch (e) {
              print('Error parsing date in fetchStockDamageEntry: ${data['stock_damage_date']}');
            }
          }
          return data;
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to fetch stock-damage entry. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error fetching stock-damage entry: $e')),
        // );
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchStockDamageTransaction(
      String stockTransactionId) async {
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/get_stock_damage_transaction.php?stock_transaction_id=$stockTransactionId';
      print('Fetching stock-damage transaction URL: $url');

      final response = await http.get(Uri.parse(url));
      print('Stock-Damage Transaction Fetch Status: ${response.statusCode}');
      print('Stock-Damage Transaction Fetch Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw Exception('Unexpected response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to fetch stock-damage transaction. Status code: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error fetching stock-damage transaction: $e')),
        // );
        print('Error fetching stock-damage transaction: $e');
      }
      return null;
    }
  }

  Future<void> updateStockDamageEntry({
    required String stockDamageId,
    required String billNo,
    required String remarks,
    required BuildContext parentContext,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final data = {
        'stock_damage_id': stockDamageId,
        'bill_no': billNo,
        'remarks': remarks,
      };

      print('Updating stock-damage entry data: $data');

      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/update_stock_damage_entry.php'),
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock-Damage Entry Update Status: ${response.statusCode}');
      print('Stock-Damage Entry Update Response: ${response.body}');

      if (response.statusCode == 200) {
        if (parentContext.mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(content: Text('Stock-damage entry updated successfully')),
          );
        }
        await fetchStockDamageEntries();
      } else {
        throw Exception(
            'Failed to update stock-damage entry. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating stock-damage entry: $e');
      if (parentContext.mounted) {
        // ScaffoldMessenger.of(parentContext).showSnackBar(
        //   SnackBar(content: Text('Error updating stock-damage entry: $e')),
        // );
        
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> updateStockDamageTransaction({
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

      print('Updating stock-damage transaction data: $data');

      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/update_stock_damage_transaction.php'),
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock-Damage Transaction Update Status: ${response.statusCode}');
      print('Stock-Damage Transaction Update Response: ${response.body}');

      if (response.statusCode == 200) {
        if (parentContext.mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(
                content: Text('Stock-damage transaction updated successfully')),
          );
        }
        await fetchStockDamageTransactions(
            stockDamageEntries[entryIndex]['stock_damage_id'].toString(), entryIndex);
      } else {
        throw Exception(
            'Failed to update stock-damage transaction. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating stock-damage transaction: $e');
      if (parentContext.mounted) {
        // ScaffoldMessenger.of(parentContext).showSnackBar(
        //   SnackBar(content: Text('Error updating stock-damage transaction: $e')),
        // );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> insertStockDamageTransaction({
    required String stockDamageId,
    required String productId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final data = {
        'stock_damage_id': stockDamageId,
        'product_id': productId,
        'quantity': quantity,
      };

      print('Inserting new stock-damage transaction data: $data');

      final response = await http.post(
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/insert_stock_damage_transaction.php'),
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      print('Stock-Damage Transaction Insert Status: ${response.statusCode}');
      print('Stock-Damage Transaction Insert Response: ${response.body}');

      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is Map<String, dynamic> &&
            responseBody['message'] ==
                'Stock-damage transaction created successfully') {
          if (parentContext.mounted) {
            ScaffoldMessenger.of(parentContext).showSnackBar(
              const SnackBar(
                  content: Text('New stock-damage transaction added successfully')),
            );
          }
          await fetchStockDamageTransactions(stockDamageId, entryIndex);
        } else {
          throw Exception('Unexpected response: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to insert stock-damage transaction. Status code: ${response.statusCode}, Response: ${response.body}');
      }
    } catch (e) {
      print('Error inserting stock-damage transaction: $e');
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

  Future<void> deleteStockDamageEntry(String stockDamageId) async {
    setState(() => _isSubmitting = true);
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/delete_stock_damage_entry.php?stock_damage_id=$stockDamageId';
      print('Deleting stock-damage entry URL: $url');

      final response = await http.delete(Uri.parse(url));
      print('Stock-Damage Entry Delete Status: ${response.statusCode}');
      print('Stock-Damage Entry Delete Response: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock-damage entry deleted successfully')),
          );
        }
        await fetchStockDamageEntries();
        await fetchCurrentStock(godownId!);
      } else {
        throw Exception(
            'Failed to delete stock-damage entry. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting stock-damage entry: $e');
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error deleting stock-damage entry: $e')),
        // );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> deleteStockDamageTransaction(
      String stockTransactionId, int entryIndex) async {
    setState(() => _isSubmitting = true);
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/delete_stock_damage_transaction.php?stock_transaction_id=$stockTransactionId';
      print('Deleting stock-damage transaction URL: $url');

      final response = await http.delete(Uri.parse(url));
      print('Stock-Damage Transaction Delete Status: ${response.statusCode}');
      print('Stock-Damage Transaction Delete Response: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Stock-damage transaction deleted successfully')),
          );
        }
        await fetchStockDamageTransactions(
            stockDamageEntries[entryIndex]['stock_damage_id'].toString(), entryIndex);
        await fetchCurrentStock(godownId!);
      } else {
        throw Exception(
            'Failed to delete stock-damage transaction. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting stock-damage transaction: $e');
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error deleting stock-damage transaction: $e')),
        // );
      }
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
    if (godownId != null) {
      await fetchCurrentStock(godownId!);
    }
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
      if (_isEditingExistingEntry && _currentStockDamageId != null) {
        for (var product in selectedProducts) {
          final transactionData = {
            'stock_damage_id': _currentStockDamageId!,
            'product_id': product['product_id'],
            'quantity': product['quantity'],
          };

          print('Submitting transaction data: $transactionData');

          final transactionResponse = await http.post(
            Uri.parse(
                'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/insert_stock_damage_transaction.php'),
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
                content: Text('Transactions added to stock-damage entry successfully')),
          );
        }
        resetForm();
        await fetchStockDamageEntries();
        await fetchCurrentStock(godownId!);
      } else {
        final billData = {
          'godown_id': godownId.toString(),
          'godown_keeper_id': _empId ?? '',
          'bill_no': billNoController.text,
          'remarks': remarksController.text,
        };

        print('Submitting bill data: $billData');

        final billResponse = await http.post(
          Uri.parse(
              'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/insert_stock_damage_entries.php'),
          body: billData,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        );

        print('Bill Submission Status: ${billResponse.statusCode}');
        print('Bill Submission Response: ${billResponse.body}');

        if (billResponse.statusCode == 201) {
          final responseBody = jsonDecode(billResponse.body);
          if (responseBody is Map<String, dynamic> &&
              responseBody.containsKey('stock_damage_id') &&
              (responseBody['message'] == 'Stock-damage entry created successfully' ||
                  responseBody['message'] == 'Stock damage entry created successfully')) {
            final stockDamageId = responseBody['stock_damage_id'].toString();

            for (var product in selectedProducts) {
              final transactionData = {
                'stock_damage_id': stockDamageId,
                'product_id': product['product_id'],
                'quantity': product['quantity'],
              };

              print('Submitting transaction data: $transactionData');

              final transactionResponse = await http.post(
                Uri.parse(
                    'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/insert_stock_damage_transaction.php'),
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
                        'Stock-damage entry and transactions submitted successfully')),
              );
            }
            resetForm();
            await fetchStockDamageEntries();
            await fetchCurrentStock(godownId!);
          } else {
            throw Exception(
                'Unexpected bill submission response: ${billResponse.body}');
          }
        } else {
          throw Exception(
              'Failed to create stock-damage entry. Status code: ${billResponse.statusCode}, Response: ${billResponse.body}');
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

  Future<bool> checkProductInTransactions(String stockDamageId, String productId) async {
    try {
      final url =
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/StockDamageController/get_stock_damage_transactions.php?stock_damage_id=$stockDamageId';
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
      orElse: () => <String, String>{'product_id': '', 'product_name': ''},
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

    final enteredQuantity = int.tryParse(quantityController.text) ?? 0;
    final stockItem = currentStock.firstWhere(
      (stock) => stock['product_id'] == productId,
      orElse: () => <String, Object>{
        'product_id': '',
        'quantity': 0,
        'product_name': selectedProduct as String,
      },
    );

    final availableQuantity = stockItem['quantity'] as int;

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

    if (_isEditingExistingEntry && _currentStockDamageId != null) {
      print('Checking if product exists for stock_damage_id: $_currentStockDamageId');
      final productExists = await checkProductInTransactions(_currentStockDamageId!, productId);
      if (productExists) {
        print('Product "$selectedProduct" already exists in stock-damage entry. Showing dialog.');
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Product Already Exists'),
            content: Text(
                'The product "${selectedProduct}" is already included in this stock-damage entry.'),
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
      print('Product "$selectedProduct" does not exist in stock-damage entry. Proceeding to add.');
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
      _currentStockDamageId = null;
      _isEditingExistingEntry = false;
      for (var entry in stockDamageEntries) {
        entry['transactions'] = <Map<String, dynamic>>[];
        entry['isExpanded'] = false;
        entry['isFetchingTransactions'] = false;
      }
    });
  }

  void _populateFormForExistingEntry({
    required String stockDamageId,
    required String billNo,
    required String remarks,
    required int entryIndex,
  }) {
    setState(() {
      _currentStockDamageId = stockDamageId;
      _isEditingExistingEntry = true;
      billNoController.text = billNo;
      remarksController.text = remarks;
      selectedProducts.clear();
      selectedProduct = null;
      quantityController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Adding products to Bill No: $billNo')),
    );
  }

  Future<void> _showEditStockDamageEntryDialog(
      String stockDamageId, BuildContext parentContext) async {
    final stockDamageEntry = await fetchStockDamageEntry(stockDamageId);
    if (stockDamageEntry == null || !parentContext.mounted) return;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => _EditStockDamageEntryDialog(
        stockDamageId: stockDamageId,
        stockDamageEntry: stockDamageEntry,
        parentContext: parentContext,
        isSubmitting: _isSubmitting,
        onUpdate: updateStockDamageEntry,
      ),
    );
  }

  Future<void> _showEditStockDamageTransactionDialog({
    required String stockTransactionId,
    required int entryIndex,
    required String stockDamageId,
    required BuildContext parentContext,
  }) async {
    final transaction = await fetchStockDamageTransaction(stockTransactionId);
    if (transaction == null || !parentContext.mounted) return;

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return _EditStockDamageTransactionDialog(
            stockTransactionId: stockTransactionId,
            stockDamageId: stockDamageId,
            entryIndex: entryIndex,
            transaction: transaction,
            products: products,
            currentStock: currentStock,
            parentContext: parentContext,
            isSubmitting: _isSubmitting,
            onUpdate: updateStockDamageTransaction,
            onInsert: insertStockDamageTransaction,
          );
        },
      ),
    );
  }

  Future<bool> _showConfirmDeleteDialog(
      String type, String identifier, String stockDamageId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => DeleteConfirmationDialog(
        type: type,
        identifier: identifier,
        stockDamageId: stockDamageId,
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
              ? 'Add to Existing Stock-Damage Entry'
              : 'Stock Damage',
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
                    'Stock-Damage Entries',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                _isFetchingStockDamageEntries
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF28A746)))
                    : stockDamageEntries.isEmpty
                        ? Center(
                            child: Text(
                              'No stock-damage entries available.',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade600),
                            ),
                          )
                        : _buildStockDamageEntriesAccordion(isMobile),
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
  }) {
    String? hintText;
    if (label == 'Quantity' && selectedProduct != null) {
      final productId = products.firstWhere(
        (product) => product['product_name'] == selectedProduct,
        orElse: () => <String, String>{'product_id': '', 'product_name': ''},
      )['product_id']!;
      final stockItem = currentStock.firstWhere(
        (stock) => stock['product_id'] == productId,
        orElse: () => <String, Object>{
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
              padding:
                  EdgeInsets.symmetric(vertical: 20.0, horizontal: textFieldPadding),
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
                setState(() {
                  selectedProduct = newValue;
                  if (newValue != null) {
                    final productId = products.firstWhere(
                      (product) => product['product_name'] == newValue,
                      orElse: () =>
                          <String, String>{'product_id': '', 'product_name': ''},
                    )['product_id']!;
                    final stockItem = currentStock.firstWhere(
                      (stock) => stock['product_id'] == productId,
                      orElse: () => <String, Object>{
                        'product_id': '',
                        'quantity': 0,
                        'product_name': newValue,
                      },
                    );
                    quantityController.text = '';
                  }
                });
                if (onChanged != null) {
                  onChanged(newValue);
                }
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

  Widget _buildStockDamageEntriesAccordion(bool isMobile) {
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stockDamageEntries.length,
      itemBuilder: (context, index) {
        final entry = stockDamageEntries[index];
        final isCurrentDate = entry['stock_damage_date'] == currentDate;

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
                        'Date: ${entry['stock_damage_date'] ?? ''}',
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
                                  stockDamageId: entry['stock_damage_id'].toString(),
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
                            : () => _showEditStockDamageEntryDialog(
                                entry['stock_damage_id'].toString(), context),
                      ),
                    if (isCurrentDate)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final confirmed = await _showConfirmDeleteDialog(
                                  'Stock-Damage Entry',
                                  entry['bill_no'] ?? '',
                                  entry['stock_damage_id'].toString(),
                                );
                                if (confirmed) {
                                  await deleteStockDamageEntry(
                                      entry['stock_damage_id'].toString());
                                }
                              },
                      ),
                  ],
                ),
              ],
            ),
            onExpansionChanged: (expanded) {
              setState(() {
                stockDamageEntries[index]['isExpanded'] = expanded;
              });
              if (expanded && entry['transactions'].isEmpty) {
                fetchStockDamageTransactions(
                    entry['stock_damage_id'].toString(), index);
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
                                              'New stock: ${transaction['new_stock_level']?.toString() ?? 'N/A'}',
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
                                                      _showEditStockDamageTransactionDialog(
                                                        stockTransactionId:
                                                            transaction['stock_transaction_id']
                                                                    ?.toString() ??
                                                                '',
                                                        entryIndex: index,
                                                        stockDamageId: entry[
                                                                    'stock_damage_id']
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
                                                        await deleteStockDamageTransaction(
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
  final String stockDamageId;

  const DeleteConfirmationDialog({
    Key? key,
    required this.type,
    required this.identifier,
    required this.stockDamageId,
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
    bool isStockDamageEntry = widget.type == 'Stock-Damage Entry';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text('Delete ${widget.type}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to delete this ${widget.type} (${widget.identifier})?'
            '${isStockDamageEntry ? ' Enter the bill number to confirm.' : ''}',
          ),
          if (isStockDamageEntry) ...[
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
            if (isStockDamageEntry &&
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

class _EditStockDamageEntryDialog extends StatefulWidget {
  final String stockDamageId;
  final Map<String, dynamic> stockDamageEntry;
  final BuildContext parentContext;
  final bool isSubmitting;
  final Future<void> Function({
    required String stockDamageId,
    required String billNo,
    required String remarks,
    required BuildContext parentContext,
  }) onUpdate;

  const _EditStockDamageEntryDialog({
    required this.stockDamageId,
    required this.stockDamageEntry,
    required this.parentContext,
    required this.isSubmitting,
    required this.onUpdate,
  });

  @override
  _EditStockDamageEntryDialogState createState() =>
      _EditStockDamageEntryDialogState();
}

class _EditStockDamageEntryDialogState
    extends State<_EditStockDamageEntryDialog> {
  late final TextEditingController billNoController;
  late final TextEditingController remarksController;

  @override
  void initState() {
    super.initState();
    billNoController = TextEditingController(
        text: widget.stockDamageEntry['bill_no']?.toString() ?? '');
    remarksController = TextEditingController(
        text: widget.stockDamageEntry['remarks']?.toString() ?? '');
    print(
        'Initialized EditStockDamageEntryDialog: billNo=${billNoController.text}, remarks=${remarksController.text}');
  }

  @override
  void dispose() {
    print('Disposing EditStockDamageEntryDialog controllers');
    billNoController.dispose();
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
        'Edit Stock-Damage Entry',
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
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 20),
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
            print('Canceling EditStockDamageEntryDialog');
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
                  final remarks = remarksController.text;
                  print(
                      'Attempting to update stock-damage entry: billNo=$billNo, remarks=$remarks');

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
                      stockDamageId: widget.stockDamageId,
                      billNo: billNo,
                      remarks: remarks,
                      parentContext: widget.parentContext,
                    );
                    if (mounted && context.mounted) {
                      print('Closing EditStockDamageEntryDialog after update');
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    print('Update failed: $e');
                    if (widget.parentContext.mounted) {
                      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                        SnackBar(content: Text('Update failed: $e')),
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

class _EditStockDamageTransactionDialog extends StatefulWidget {
  final String stockTransactionId;
  final String stockDamageId;
  final int entryIndex;
  final Map<String, dynamic> transaction;
  final List<Map<String, String>> products;
  final List<Map<String, dynamic>> currentStock;
  final BuildContext parentContext;
  final bool isSubmitting;
  final Future<void> Function({
    required String stockTransactionId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) onUpdate;
  final Future<void> Function({
    required String stockDamageId,
    required String productId,
    required String quantity,
    required int entryIndex,
    required BuildContext parentContext,
  }) onInsert;

  const _EditStockDamageTransactionDialog({
    required this.stockTransactionId,
    required this.stockDamageId,
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
  _EditStockDamageTransactionDialogState createState() =>
      _EditStockDamageTransactionDialogState();
}

class _EditStockDamageTransactionDialogState
    extends State<_EditStockDamageTransactionDialog> {
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
        'Initialized EditStockDamageTransactionDialog: product=$selectedProduct, quantity=${quantityController.text}');
  }

  @override
  void dispose() {
    print('Disposing EditStockDamageTransactionDialog controller');
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
      orElse: () => <String, Object>{
        'product_id': '',
        'quantity': 0,
        'product_name': selectedProduct as String,
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
        'Edit Stock-Damage Transaction',
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
                  print('Canceling EditStockDamageTransactionDialog');
                  Navigator.of(context).pop();
                },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: widget.isSubmitting || isUpdating
              ? null
              : _updateTransaction,
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