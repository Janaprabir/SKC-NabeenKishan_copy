// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:nabeenkishan/dailyactivity/dailyactivity_provider.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';

// class PendingActivitiesPage extends StatefulWidget {
//   const PendingActivitiesPage({super.key});

//   @override
//   _PendingActivitiesPageState createState() => _PendingActivitiesPageState();
// }

// class _PendingActivitiesPageState extends State<PendingActivitiesPage> {
//   bool _isLoading = true;
//   bool _isOffline = false;
//   List<Map<String, dynamic>> _drafts = [];
//   final Set<int> _submittingDrafts = {}; // Track drafts being submitted

//   @override
//   void initState() {
//     super.initState();
//     _loadDrafts();
//   }

//   Future<void> _loadDrafts() async {
//     setState(() => _isLoading = true);
//     final provider = Provider.of<ActivityProvider>(context, listen: false);
//     final isConnected = await Connectivity().checkConnectivity() != ConnectivityResult.none;
//     setState(() => _isOffline = !isConnected);
//     try {
//       final drafts = await provider.getDrafts();
//       setState(() {
//         _drafts = drafts;
//         _isLoading = false;
//         print('Loaded drafts: ${_drafts.length} items');
//       });
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error loading drafts: $e'), backgroundColor: Colors.red),
//         );
//       });
//     }
//   }

//   Future<void> _syncDrafts() async {
//     final provider = Provider.of<ActivityProvider>(context, listen: false);
//     setState(() => _isLoading = true);
//     try {
//       await provider.syncDrafts();
//       await _loadDrafts();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Drafts synced successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       setState(() {
//         _isLoading = false;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error syncing drafts: $e'), backgroundColor: Colors.red),
//         );
//       });
//     }
//   }

//   Future<void> _deleteDraft(int id, String? imagePath) async {
//     final provider = Provider.of<ActivityProvider>(context, listen: false);
//     try {
//       await provider.deleteDraft(id);
//       if (imagePath != null) {
//         final file = File(imagePath);
//         if (await file.exists()) {
//           await file.delete();
//           print("Image file deleted: $imagePath");
//         }
//       }
//       await _loadDrafts();
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Draft deleted successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error deleting draft: $e'), backgroundColor: Colors.red),
//       );
//     }
//   }

//   Future<void> _resubmitDraft(Map<String, dynamic> draft) async {
//     final draftId = draft['id'] as int;
//     if (_submittingDrafts.contains(draftId)) {
//       print("Draft ID $draftId is already being submitted, skipping...");
//       return;
//     }

//     final provider = Provider.of<ActivityProvider>(context, listen: false);
//     final data = jsonDecode(draft['data'] as String) as Map<String, dynamic>;
//     final imageFile = draft['image_path'] != null ? File(draft['image_path'] as String) : null;
//     final isConnected = await Connectivity().checkConnectivity() != ConnectivityResult.none;

//     setState(() => _submittingDrafts.add(draftId));
//     try {
//       if (isConnected) {
//         print("Attempting to resubmit draft ID $draftId for emp_id ${data['emp_id']}");
//         final success = await provider.insertActivity(data, imageFile);
//         if (success) {
//           await provider.deleteDraft(draftId);
//           await _loadDrafts();
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Activity submitted successfully'),
//               backgroundColor: Colors.green,
//             ),
//           );
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('Failed to submit activity. Kept as draft.'),
//               backgroundColor: Colors.orange,
//             ),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('No internet. Activity remains as draft.'),
//             backgroundColor: Colors.orange,
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error submitting activity: $e'), backgroundColor: Colors.red),
//       );
//     } finally {
//       setState(() => _submittingDrafts.remove(draftId));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final double screenWidth = MediaQuery.of(context).size.width;
//     final double padding = screenWidth * 0.05;

//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text("Pending Activities", style: TextStyle(color: Colors.white)),
//         backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh, color: Colors.white),
//             onPressed: _isOffline || _isLoading
//                 ? null
//                 : () async {
//                     await _syncDrafts();
//                   },
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
//             child: Column(
//               children: [
//                 if (_isOffline)
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 10),
//                     child: Text(
//                       "Offline Mode: Showing local drafts",
//                       style: TextStyle(
//                         color: Colors.blue,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 Expanded(
//                   child: _isLoading
//                       ? const Center(
//                           child: CircularProgressIndicator(
//                             color: Color.fromRGBO(40, 167, 70, 1),
//                           ),
//                         )
//                       : _drafts.isEmpty
//                           ? const Center(child: Text("No pending activities found."))
//                           : ListView.builder(
//                               itemCount: _drafts.length,
//                               itemBuilder: (context, index) {
//                                 final draft = _drafts[index];
//                                 final data = jsonDecode(draft['data'] as String) as Map<String, dynamic>;
//                                 return Card(
//                                   margin: const EdgeInsets.symmetric(vertical: 8),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   child: ListTile(
//                                     title: Text(
//                                       data['nature_of_work_id'] == '1'
//                                           ? 'DEMO - ${data['customer_name']}'
//                                           : data['nature_of_work_id'] == '2'
//                                               ? 'DELIVERY & COLLECTION'
//                                               : data['nature_of_work_id'] == '3'
//                                                   ? 'SUBMISSION'
//                                                   : data['nature_of_work_id'] == '4'
//                                                       ? 'MEETING'
//                                                       : data['nature_of_work_id'] == '5'
//                                                           ? 'LEAVE'
//                                                           : 'OTHERS',
//                                       style: const TextStyle(fontWeight: FontWeight.bold),
//                                     ),
//                                     subtitle: Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       children: [
//                                         Text('Location: ${data['location']}'),
//                                         if (data['customer_name']?.isNotEmpty ?? false)
//                                           Text('Customer: ${data['customer_name']}'),
//                                         if (data['remarks']?.isNotEmpty ?? false)
//                                           Text('Remarks: ${data['remarks']}'),
//                                       ],
//                                     ),
//                                     trailing: Row(
//                                       mainAxisSize: MainAxisSize.min,
//                                       children: [
//                                         IconButton(
//                                           icon: _submittingDrafts.contains(draft['id'])
//                                               ? const CircularProgressIndicator(
//                                                   color: Color.fromRGBO(40, 167, 70, 1),
//                                                   strokeWidth: 2,
//                                                 )
//                                               : const Icon(Icons.send, color: Color.fromRGBO(40, 167, 70, 1)),
//                                           onPressed: _submittingDrafts.contains(draft['id'])
//                                               ? null
//                                               : () => _resubmitDraft(draft),
//                                         ),
//                                         IconButton(
//                                           icon: const Icon(Icons.delete, color: Colors.red),
//                                           onPressed: _submittingDrafts.contains(draft['id'])
//                                               ? null
//                                               : () => _showDeleteConfirmation(draft['id'], draft['image_path']),
//                                         ),
//                                       ],
//                                     ),
//                                     onTap: () => _showDraftDetails(draft),
//                                   ),
//                                 );
//                               },
//                             ),
//                 ),
//               ],
//             ),
//           ),
//           if (_isLoading)
//             Container(
//               color: Colors.black.withOpacity(0.5),
//               child: const Center(
//                 child: CircularProgressIndicator(color: Color.fromRGBO(40, 167, 70, 1)),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   void _showDraftDetails(Map<String, dynamic> draft) {
//     final data = jsonDecode(draft['data'] as String) as Map<String, dynamic>;
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Draft Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Nature of Work ID: ${data['nature_of_work_id']}'),
//                 if (data['customer_name']?.isNotEmpty ?? false)
//                   Text('Customer Name: ${data['customer_name']}'),
//                 if (data['customer_address']?.isNotEmpty ?? false)
//                   Text('Customer Address: ${data['customer_address']}'),
//                 if (data['customer_phone_no']?.isNotEmpty ?? false)
//                   Text('Customer Phone: ${data['customer_phone_no']}'),
//                 if (data['demo_product_id']?.isNotEmpty ?? false)
//                   Text('Demo Products: ${data['demo_product_id']}'),
//                 if (data['order_no']?.isNotEmpty ?? false) Text('Order No: ${data['order_no']}'),
//                 if (data['result_id']?.isNotEmpty ?? false) Text('Result ID: ${data['result_id']}'),
//                 if (data['remarks']?.isNotEmpty ?? false) Text('Remarks: ${data['remarks']}'),
//                 if (data['order_unit']?.isNotEmpty ?? false) Text('Order Unit: ${data['order_unit']}'),
//                 if (data['booking_advance']?.isNotEmpty ?? false)
//                   Text('Booking Advance: ${data['booking_advance']}'),
//                 if (data['total_customer']?.isNotEmpty ?? false)
//                   Text('Total Customer: ${data['total_customer']}'),
//                 if (data['collection_amount']?.isNotEmpty ?? false)
//                   Text('Collection Amount: ${data['collection_amount']}'),
//                 if (data['delivery_unit']?.isNotEmpty ?? false)
//                   Text('Delivery Unit: ${data['delivery_unit']}'),
//                 if (data['office_name']?.isNotEmpty ?? false)
//                   Text('Office Name: ${data['office_name']}'),
//                 Text('Location: ${data['location']}'),
//                 Text('Latitude: ${data['latitude']}'),
//                 Text('Longitude: ${data['longitude']}'),
//                 if (draft['image_path'] != null) Text('Image Path: ${data['image_path']}'),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Close'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _showDeleteConfirmation(int id, String? imagePath) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Delete Draft'),
//           content: const Text('Are you sure you want to delete this draft?'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel', style: TextStyle(color: Colors.red)),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 _deleteDraft(id, imagePath);
//               },
//               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//               child: const Text('Delete', style: TextStyle(color: Colors.white)),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }