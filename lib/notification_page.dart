import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<dynamic> notifications = [];
  bool isLoading = false;
  int? godownId;
  final String baseUrl =
      'https://www.nabeenkishan.net.in/newproject/api/routes/StockTransferController';

  @override
  void initState() {
    super.initState();
    _loadGodownId().then((_) {
      fetchNotifications();
    });
  }

  Future<void> _loadGodownId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      godownId = prefs.getInt('godown_id');
    });
  }

  Future<void> fetchNotifications() async {
    if (godownId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Godown ID not found')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get_notifications_with_details.php?godown_id=$godownId&limit=20'),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('Godown ID: $godownId');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is List) {
          setState(() {
            notifications = decoded;
            isLoading = false;
          });
        } else {
          throw Exception('Expected a list of notifications, got: $decoded');
        }
      } else {
        throw Exception('Failed to load notifications: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching notifications: $e');
    }
  }

  Future<void> markAsRead() async {
    if (godownId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Godown ID not found')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mark_notifications_as_read.php'),
        body: {
          'godown_id': godownId.toString(),
          'limit': '20',
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Notifications marked as read')),
        );
        await fetchNotifications();
      } else {
        throw Exception('Failed to mark notifications as read: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  Future<void> markSingleNotificationAsRead(String stockTransferId) async {
    if (godownId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Godown ID not found')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mark_notification_as_read.php'),
        body: {
          'godown_id': godownId.toString(),
          'stock_transfer_id': stockTransferId,
        },
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('Mark single notification response: ${result['message']}');
        setState(() {
          final index = notifications.indexWhere(
            (n) => n['stock_transfer_entry']['stock_transfer_id'] == stockTransferId,
          );
          if (index != -1) {
            notifications[index]['status'] = 'read';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification marked as read')),
        );
      } else {
        throw Exception('Failed to mark notification as read: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking single notification as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error marking notification as read')),
      );
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return 'N/A';
    }
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      print('Error parsing date: $e');
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: markAsRead,
            child: const Text(
              'Mark All as Read',
              style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_off,
                        size: 60,
                        color: Colors.green.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchNotifications,
                  color: Colors.green,
                  backgroundColor: Colors.white,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final stockTransfer = notification['stock_transfer_entry'];
                      final transactions = notification['transactions'] as List? ?? [];

                      if (stockTransfer is! Map<String, dynamic>) {
                        print('Invalid stock_transfer_entry at index $index: $stockTransfer');
                        return Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: Icon(
                              notification['status'] == 'unread'
                                  ? Icons.notifications_active
                                  : Icons.notifications,
                              color: notification['status'] == 'unread'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            title: const Text(
                              'Invalid Notification Data',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.red,
                              ),
                            ),
                            subtitle: Text(
                              'Error: Unable to display transfer details',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        );
                      }

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 16.0),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ExpansionTile(
                            leading: Icon(
                              notification['status'] == 'unread'
                                  ? Icons.notifications_active
                                  : Icons.notifications,
                              color: notification['status'] == 'unread'
                                  ? Colors.green
                                  : Colors.grey,
                              size: 28,
                            ),
                            title: Text(
                              'Transfer from ${stockTransfer['src_godown_name'] ?? 'N/A'} to ${stockTransfer['dest_godown_name'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: notification['status'] == 'unread'
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: Colors.green[900],
                              ),
                            ),
                            subtitle: Text(
                              'Date: ${formatDate(stockTransfer['stock_transfer_date'])} | Bill: ${stockTransfer['bill_no'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.05),
                                  borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(16)),
                                ),
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow(
                                        'DCN', stockTransfer['dcn'] ?? 'N/A'),
                                    _buildDetailRow('Remarks',
                                        stockTransfer['remarks'] ?? 'None'),
                                    _buildDetailRow('Keeper',
                                        stockTransfer['keeper_name'] ?? 'N/A'),
                                    _buildDetailRow('Designation',
                                        stockTransfer['designation'] ?? 'N/A'),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Products:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (transactions.isEmpty)
                                      Text(
                                        'No products available',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      )
                                    else
                                      ...transactions.map(
                                        (transaction) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12.0),
                                          child: Card(
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _buildDetailRow('Product',
                                                      transaction['product_name'] ?? 'N/A'),
                                                  _buildDetailRow('Quantity',
                                                      (transaction['quantity'] ?? 0).toString()),
                                                  _buildDetailRow(
                                                      'Previous Stock',
                                                      (transaction['pre_stock_level'] ?? 0)
                                                          .toString()),
                                                  _buildDetailRow('New Stock',
                                                      (transaction['new_stock_level'] ?? 0).toString()),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // if (notification['status'] == 'unread')
                                    //   Align(
                                    //     alignment: Alignment.centerRight,
                                    //     child: TextButton(
                                    //       onPressed: () {
                                    //         final stockTransferId =
                                    //             stockTransfer['stock_transfer_id']?.toString();
                                    //         if (stockTransferId != null) {
                                    //           markSingleNotificationAsRead(stockTransferId);
                                    //         }
                                    //       },
                                    //       child: const Text(
                                    //         'Mark as Read',
                                    //         style: TextStyle(
                                    //           color: Colors.green,
                                    //           fontSize: 14,
                                    //           fontWeight: FontWeight.w600,
                                    //         ),
                                    //       ),
                                    //     ),
                                    //   ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}