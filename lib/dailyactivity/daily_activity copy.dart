// // ignore_for_file: depend_on_referenced_packages

// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:nabeenkishan/dailyactivity/dailyactivity_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:permission_handler/permission_handler.dart';

// class DailyActivityForm extends StatefulWidget {
//   const DailyActivityForm({super.key});

//   @override
//   _DailyActivityFormState createState() => _DailyActivityFormState();
// }

// class _DailyActivityFormState extends State<DailyActivityForm> {
//   bool isFormComplete = false;
//   final _formKey = GlobalKey<FormState>();
//   String? selectedNatureOfWork;
//   List<String> selectedDemoProducts = [];
//   String? selectedResult;
//   File? _image;
//   final picker = ImagePicker();
//   double? latitude;
//   double? longitude;
//   String? locationName;
//   String? empId;
//   bool isFormValid = false;
//   bool isLoading = false;
//   bool _isSubmitting = false;
//   bool _isOffline = false;
//   final Map<String, bool> _locationLoadingStates = {};

//   final TextEditingController customerNameController = TextEditingController();
//   final TextEditingController customerAddressController =
//       TextEditingController();
//   final TextEditingController customerPhoneController = TextEditingController();
//   final TextEditingController orderNoController = TextEditingController();
//   final TextEditingController orderUnitController = TextEditingController();
//   final TextEditingController bookingAdvanceController =
//       TextEditingController();
//   final TextEditingController totalCustomerController = TextEditingController();
//   final TextEditingController collectionAmountController =
//       TextEditingController();
//   final TextEditingController deliveryUnitController = TextEditingController();
//   final TextEditingController officeNameController = TextEditingController();
//   final TextEditingController remarksController = TextEditingController();
//   final TextEditingController spotPictureController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _requestPermissions();
//     _getCurrentLocation();
//     _loadEmpId();

//     // Add listeners to controllers
//     [
//       customerNameController,
//       customerAddressController,
//       customerPhoneController,
//       orderNoController,
//       orderUnitController,
//       bookingAdvanceController,
//       totalCustomerController,
//       collectionAmountController,
//       deliveryUnitController,
//       officeNameController,
//       remarksController,
//       spotPictureController
//     ].forEach((controller) {
//       controller.addListener(() {
//         print('Controller changed: ${controller.text}');
//         _validateForm();
//       });
//     });

//     // Fetch data and check connectivity
//     _loadData();

//     // Listen for connectivity changes
//     Connectivity().onConnectivityChanged.listen((result) {
//       final isConnected = result != ConnectivityResult.none;
//       setState(() => _isOffline = !isConnected);
//       if (isConnected) {
//         _loadData(showSyncMessage: true);
//       }
//     });
//   }

//   Future<void> _loadData({bool showSyncMessage = false}) async {
//     setState(() => isLoading = true);
//     final isConnected =
//         await Connectivity().checkConnectivity() != ConnectivityResult.none;
//     setState(() => _isOffline = !isConnected);

//     final provider = Provider.of<ActivityProvider>(context, listen: false);
//     try {
//       await Future.wait([
//         provider.fetchNatureOfWork(forceFetch: isConnected),
//         provider.fetchDemoProducts(forceFetch: isConnected),
//         provider.fetchActivityResults(forceFetch: isConnected),
//       ]);
//       setState(() {
//         isLoading = false;
//         if (_isOffline &&
//             (provider.natureOfWork.isEmpty ||
//                 provider.demoProducts.isEmpty ||
//                 provider.activityResults.isEmpty)) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: const Text(
//                   "Some dropdown data is missing. Please connect to the internet to fetch data."),
//               backgroundColor: Colors.red,
//               action: SnackBarAction(
//                 label: 'Retry',
//                 textColor: Colors.white,
//                 onPressed: () => _loadData(showSyncMessage: true),
//               ),
//             ),
//           );
//         } else if (_isOffline) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Using cached data in offline mode"),
//               backgroundColor: Colors.blue,
//             ),
//           );
//         } else if (showSyncMessage) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Data synced with latest from server"),
//               backgroundColor: Colors.green,
//             ),
//           );
//         }
//       });
//       _validateForm(); // Ensure form state is updated
//     } catch (error) {
//       setState(() {
//         isLoading = false;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text("Error fetching data: $error"),
//             backgroundColor: Colors.red,
//             action: SnackBarAction(
//               label: 'Retry',
//               textColor: Colors.white,
//               onPressed: () => _loadData(showSyncMessage: true),
//             ),
//           ),
//         );
//       });
//     }
//   }

//   Future<void> _requestPermissions() async {
//     if (await Permission.notification.isDenied) {
//       await Permission.notification.request();
//     }
//     if (await Permission.storage.isDenied) {
//       await Permission.storage.request();
//     }
//     if (await Permission.camera.isDenied) {
//       await Permission.camera.request();
//     }
//   }

//   Future<void> _loadEmpId() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       empId = prefs.getString('emp_id') ?? "0";
//       print('Loaded empId: $empId');
//     });
//   }

//   Future<void> _pickImage() async {
//     final pickedFile = await picker.pickImage(source: ImageSource.camera);
//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//         spotPictureController.text = pickedFile.path;
//         print('Image picked: ${_image?.path}');
//         _validateForm();
//       });
//     }
//   }

//   Future<void> _getCurrentLocation() async {
//     try {
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Location services are disabled.")),
//         );
//         return;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text("Location permission denied.")),
//           );
//           return;
//         }
//       }

//       if (permission == LocationPermission.deniedForever) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text("Location permission permanently denied.")),
//         );
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       setState(() {
//         latitude = position.latitude;
//         longitude = position.longitude;
//         print('Location fetched: lat=$latitude, long=$longitude');
//       });

//       if (latitude != null && longitude != null && empId != null) {
//         String? fetchedLocationName =
//             await _getLocationName(latitude!, longitude!, empId!);
//         setState(() {
//           locationName = fetchedLocationName;
//           print('Location name: $locationName');
//         });
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error getting location: $e")),
//       );
//     }
//   }

//   Future<String?> _getLocationName(
//       double latitude, double longitude, String activityId) async {
//     setState(() {
//       _locationLoadingStates[activityId] = true;
//     });

//     try {
//       List<Placemark> placemarks =
//           await placemarkFromCoordinates(latitude, longitude);
//       if (placemarks.isNotEmpty) {
//         Placemark placemark = placemarks.first;
//         final locationParts = [
//           if (placemark.street?.isNotEmpty == true) placemark.street!,
//           if (placemark.thoroughfare?.isNotEmpty == true)
//             placemark.thoroughfare!,
//           if (placemark.subLocality?.isNotEmpty == true) placemark.subLocality!,
//           if (placemark.locality?.isNotEmpty == true) placemark.locality!,
//           if (placemark.postalCode?.isNotEmpty == true) placemark.postalCode!,
//           if (placemark.subAdministrativeArea?.isNotEmpty == true)
//             placemark.subAdministrativeArea!,
//           if (placemark.administrativeArea?.isNotEmpty == true)
//             placemark.administrativeArea!,
//           if (placemark.country?.isNotEmpty == true) placemark.country!,
//         ];
//         final locationName = locationParts.join(', ');
//         return locationName.isNotEmpty ? locationName : 'Unknown Location';
//       }
//       return 'No Location Found';
//     } catch (e) {
//       return 'Error: $e';
//     } finally {
//       setState(() {
//         _locationLoadingStates[activityId] = false;
//       });
//     }
//   }

//   void _validateForm() {
//     setState(() {
//       final isBasicValid = selectedNatureOfWork != null &&
//           selectedNatureOfWork!.isNotEmpty &&
//           selectedNatureOfWork != '0';
//       print(
//           'Validating form - isBasicValid: $isBasicValid, selectedNatureOfWork: $selectedNatureOfWork');

//       switch (selectedNatureOfWork) {
//         case '1': // DEMO
//           isFormComplete = selectedDemoProducts.isNotEmpty &&
//               customerNameController.text.trim().isNotEmpty &&
//               customerAddressController.text.trim().isNotEmpty &&
//               customerPhoneController.text.trim().isNotEmpty &&
//               customerPhoneController.text.trim().length == 10 &&
//               selectedResult != null &&
//               _image != null;
//           print('DEMO - selectedDemoProducts: $selectedDemoProducts, '
//               'customerName: ${customerNameController.text}, '
//               'customerAddress: ${customerAddressController.text}, '
//               'customerPhone: ${customerPhoneController.text}, '
//               'selectedResult: $selectedResult, '
//               '_image: ${_image?.path}, '
//               'isFormComplete: $isFormComplete');
//           if (selectedResult == '2') {
//             isFormComplete = isFormComplete &&
//                 orderNoController.text.trim().isNotEmpty &&
//                 orderUnitController.text.trim().isNotEmpty &&
//                 bookingAdvanceController.text.trim().isNotEmpty;
//             print('DEMO with result 2 - orderNo: ${orderNoController.text}, '
//                 'orderUnit: ${orderUnitController.text}, '
//                 'bookingAdvance: ${bookingAdvanceController.text}, '
//                 'isFormComplete: $isFormComplete');
//           }
//           break;
//         case '2': // DELIVERY & COLLECTION
//           isFormComplete = totalCustomerController.text.trim().isNotEmpty &&
//               collectionAmountController.text.trim().isNotEmpty &&
//               deliveryUnitController.text.trim().isNotEmpty;
//           print(
//               'DELIVERY & COLLECTION - totalCustomer: ${totalCustomerController.text}, '
//               'collectionAmount: ${collectionAmountController.text}, '
//               'deliveryUnit: ${deliveryUnitController.text}, '
//               'isFormComplete: $isFormComplete');
//           break;
//         case '3': // SUBMISSION
//         case '4': // MEETING
//           isFormComplete = officeNameController.text.trim().isNotEmpty &&
//               remarksController.text.trim().isNotEmpty;
//           print(
//               'SUBMISSION/MEETING - officeName: ${officeNameController.text}, '
//               'remarks: ${remarksController.text}, '
//               'isFormComplete: $isFormComplete');
//           break;
//         case '5': // LEAVE
//         case '7': // OTHERS
//           isFormComplete = remarksController.text.trim().isNotEmpty;
//           print('LEAVE/OTHERS - remarks: ${remarksController.text}, '
//               'isFormComplete: $isFormComplete');
//           break;
//         default:
//           isFormComplete = false;
//           print('Default case - isFormComplete: $isFormComplete');
//       }

//       isFormValid = isBasicValid && isFormComplete;
//       print('Final isFormValid: $isFormValid');
//     });
//   }

//   void _showValidationMessage() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text("Please fill all required fields before submitting."),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }

//   void _showConfirmationDialog() {
//     FocusScope.of(context).unfocus();
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text("Confirm Submission"),
//           content: const Text("Are you sure you want to submit this activity?"),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("Recheck", style: TextStyle(color: Colors.red)),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 if (_formKey.currentState!.validate() && isFormValid) {
//                   Navigator.pop(context);
//                   submitActivity();
//                 } else {
//                   Navigator.pop(context);
//                   _showValidationMessage();
//                 }
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//               ),
//               child:
//                   const Text("Confirm", style: TextStyle(color: Colors.white)),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget buildTextField(
//     String label,
//     TextEditingController controller,
//     TextInputType keyboardType, {
//     bool isRequired = false,
//     required List<TextInputFormatter> inputFormatters,
//     String? Function(String?)? validator,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: TextFormField(
//         controller: controller,
//         enabled: !_isSubmitting,
//         keyboardType: keyboardType,
//         inputFormatters: inputFormatters,
//         decoration: InputDecoration(
//           labelText: isRequired ? "$label *" : label,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: const BorderSide(
//                 color: Color.fromRGBO(40, 167, 70, 1), width: 2),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: const BorderSide(
//                 color: Color.fromRGBO(40, 167, 70, 1), width: 2),
//           ),
//         ),
//         validator: validator ??
//             (isRequired
//                 ? (value) => value?.trim().isEmpty ?? true
//                     ? "This field is required"
//                     : null
//                 : null),
//       ),
//     );
//   }

//   Widget buildDropdown(
//     String label,
//     String? selectedValue,
//     List<Map<String, dynamic>> items,
//     Function(String?) onChanged, {
//     bool isRequired = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: DropdownButtonFormField<String>(
//         value: selectedValue,
//         onChanged: _isSubmitting ||
//                 items.isEmpty ||
//                 (items.length == 1 && items[0]['id'] == '0')
//             ? null
//             : (value) {
//                 print('Dropdown $label changed to: $value');
//                 onChanged(value);
//               },
//         items: items.isEmpty || (items.length == 1 && items[0]['id'] == '0')
//             ? [
//                 const DropdownMenuItem<String>(
//                   value: null,
//                   child: Text("No data available"),
//                 )
//               ]
//             : items.map((item) {
//                 return DropdownMenuItem<String>(
//                   value: item['id'].toString(),
//                   child: Text(item['name'].toString()),
//                 );
//               }).toList(),
//         decoration: InputDecoration(
//           labelText: isRequired ? "$label *" : label,
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: const BorderSide(
//                 color: Color.fromRGBO(40, 167, 70, 1), width: 2),
//           ),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//             borderSide: const BorderSide(
//                 color: Color.fromRGBO(40, 167, 70, 1), width: 2),
//           ),
//         ),
//         validator: isRequired
//             ? (value) => value == null || value == '0'
//                 ? "Please select a valid $label"
//                 : null
//             : null,
//       ),
//     );
//   }

//   Widget buildMultiSelectDropdown(
//     String label,
//     List<String> selectedValues,
//     List<Map<String, dynamic>> items,
//     Function(List<String>) onChanged, {
//     bool isRequired = false,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             isRequired ? "$label *" : label,
//             style: Theme.of(context).textTheme.titleMedium,
//           ),
//           const SizedBox(height: 8),
//           GestureDetector(
//             onTap: _isSubmitting ||
//                     items.isEmpty ||
//                     (items.length == 1 && items[0]['id'] == '0')
//                 ? null
//                 : () async {
//                     List<String> newSelectedValues = await showDialog(
//                           context: context,
//                           builder: (BuildContext context) {
//                             List<String> tempSelected =
//                                 List.from(selectedValues);
//                             return StatefulBuilder(
//                               builder: (context, setState) {
//                                 return AlertDialog(
//                                   title: Text('Select $label'),
//                                   content: SizedBox(
//                                     width: double.maxFinite,
//                                     child: items.isEmpty ||
//                                             (items.length == 1 &&
//                                                 items[0]['id'] == '0')
//                                         ? const Text("No products available")
//                                         : ListView(
//                                             shrinkWrap: true,
//                                             children: items.map((item) {
//                                               return CheckboxListTile(
//                                                 title: Text(
//                                                     item['name'].toString()),
//                                                 value: tempSelected.contains(
//                                                     item['id'].toString()),
//                                                 onChanged: (bool? value) {
//                                                   setState(() {
//                                                     if (value == true) {
//                                                       tempSelected.add(
//                                                           item['id']
//                                                               .toString());
//                                                     } else {
//                                                       tempSelected.remove(
//                                                           item['id']
//                                                               .toString());
//                                                     }
//                                                   });
//                                                 },
//                                                 activeColor:
//                                                     const Color.fromRGBO(
//                                                         40, 167, 70, 1),
//                                                 checkColor: Colors.white,
//                                               );
//                                             }).toList(),
//                                           ),
//                                   ),
//                                   actions: [
//                                     TextButton(
//                                       onPressed: () => Navigator.pop(
//                                           context, selectedValues),
//                                       child: const Text('Cancel'),
//                                     ),
//                                     TextButton(
//                                       onPressed: () =>
//                                           Navigator.pop(context, tempSelected),
//                                       child: const Text('OK'),
//                                     ),
//                                   ],
//                                 );
//                               },
//                             );
//                           },
//                         ) ??
//                         selectedValues;

//                     print('Multi-select $label changed to: $newSelectedValues');
//                     onChanged(newSelectedValues);
//                     _validateForm();
//                   },
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 border: Border.all(
//                     color: const Color.fromRGBO(40, 167, 70, 1), width: 2),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: Text(
//                       selectedValues.isEmpty
//                           ? items.isEmpty ||
//                                   (items.length == 1 && items[0]['id'] == '0')
//                               ? 'No products available'
//                               : 'Select Products'
//                           : items
//                               .where((item) => selectedValues
//                                   .contains(item['id'].toString()))
//                               .map((item) => item['name'])
//                               .join(', '),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                   const Icon(Icons.arrow_drop_down),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget buildDynamicFields() {
//     switch (selectedNatureOfWork) {
//       case '1': // DEMO
//         return Column(
//           children: [
//             Consumer<ActivityProvider>(
//               builder: (context, provider, child) {
//                 return buildMultiSelectDropdown(
//                   "Demo Products",
//                   selectedDemoProducts,
//                   provider.demoProducts.isEmpty
//                       ? [
//                           {'id': '0', 'name': 'No products available'}
//                         ]
//                       : provider.demoProducts,
//                   (values) {
//                     setState(() {
//                       selectedDemoProducts = values;
//                       _validateForm();
//                     });
//                   },
//                   isRequired: true,
//                 );
//               },
//             ),
//             buildTextField(
//               "Customer Name",
//               customerNameController,
//               TextInputType.name,
//               inputFormatters: [],
//               isRequired: true,
//             ),
//             buildTextField(
//               "Customer Address",
//               customerAddressController,
//               TextInputType.streetAddress,
//               inputFormatters: [],
//               isRequired: true,
//             ),
//             buildTextField(
//               "Customer Mobile Number",
//               customerPhoneController,
//               TextInputType.phone,
//               inputFormatters: [
//                 FilteringTextInputFormatter.digitsOnly,
//                 LengthLimitingTextInputFormatter(10),
//               ],
//               isRequired: true,
//               validator: (value) {
//                 if (value == null || value.trim().isEmpty) {
//                   return "This field is required";
//                 }
//                 if (value.length != 10) {
//                   return "Enter a valid 10-digit number";
//                 }
//                 return null;
//               },
//             ),
//             Consumer<ActivityProvider>(
//               builder: (context, provider, child) {
//                 return buildDropdown(
//                   "Select Result",
//                   selectedResult,
//                   provider.activityResults.isEmpty
//                       ? [
//                           {'id': '0', 'name': 'No data available'}
//                         ]
//                       : provider.activityResults,
//                   (value) {
//                     setState(() {
//                       selectedResult = value;
//                       _validateForm();
//                     });
//                   },
//                   isRequired: true,
//                 );
//               },
//             ),
//             if (selectedResult == '2') ...[
//               buildTextField(
//                 "Order No",
//                 orderNoController,
//                 TextInputType.text,
//                 inputFormatters: [],
//                 isRequired: true,
//               ),
//               buildTextField(
//                 "Order Unit",
//                 orderUnitController,
//                 TextInputType.number,
//                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 isRequired: true,
//               ),
//               buildTextField(
//                 "Booking Advance",
//                 bookingAdvanceController,
//                 TextInputType.number,
//                 inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//                 isRequired: true,
//               ),
//             ],
//             buildTextField(
//               "Remarks",
//               remarksController,
//               TextInputType.text,
//               inputFormatters: [],
//             ),
//             Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     controller: spotPictureController,
//                     enabled: !_isSubmitting,
//                     readOnly: true,
//                     decoration: InputDecoration(
//                       labelText: "Spot Picture Path *",
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         borderSide: const BorderSide(
//                             color: Color.fromRGBO(40, 167, 70, 1), width: 2),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         borderSide: const BorderSide(
//                             color: Color.fromRGBO(40, 167, 70, 1), width: 2),
//                       ),
//                     ),
//                     validator: (value) =>
//                         _image == null ? "Please upload a spot picture" : null,
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 ElevatedButton(
//                   onPressed: _isSubmitting ? null : _pickImage,
//                   style: ElevatedButton.styleFrom(
//                     shape: const CircleBorder(),
//                     padding: const EdgeInsets.all(16),
//                     backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
//                   ),
//                   child: const Icon(
//                     Icons.camera_alt,
//                     size: 30,
//                     color: Colors.white,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         );
//       case '2': // DELIVERY & COLLECTION
//         return Column(
//           children: [
//             buildTextField(
//               "Total Customer",
//               totalCustomerController,
//               TextInputType.number,
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//               isRequired: true,
//             ),
//             buildTextField(
//               "Collection Amount",
//               collectionAmountController,
//               TextInputType.number,
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//               isRequired: true,
//             ),
//             buildTextField(
//               "Delivery Unit",
//               deliveryUnitController,
//               TextInputType.number,
//               inputFormatters: [FilteringTextInputFormatter.digitsOnly],
//               isRequired: true,
//             ),
//             buildTextField(
//               "Remarks",
//               remarksController,
//               TextInputType.text,
//               inputFormatters: [],
//             ),
//           ],
//         );
//       case '3': // SUBMISSION
//       case '4': // MEETING
//         return Column(
//           children: [
//             buildTextField(
//               "Office Name",
//               officeNameController,
//               TextInputType.name,
//               inputFormatters: [],
//               isRequired: true,
//             ),
//             buildTextField(
//               "Remarks",
//               remarksController,
//               TextInputType.text,
//               inputFormatters: [],
//               isRequired: true,
//             ),
//           ],
//         );
//       case '5': // LEAVE
//       case '7': // OTHERS
//         return buildTextField(
//           "Remarks",
//           remarksController,
//           TextInputType.text,
//           inputFormatters: [],
//           isRequired: true,
//         );
//       default:
//         return const SizedBox.shrink();
//     }
//   }

//   void _resetForm() {
//     setState(() {
//       selectedNatureOfWork = null;
//       selectedDemoProducts = [];
//       selectedResult = null;
//       _image = null;
//       latitude = null;
//       longitude = null;
//       locationName = null;
//       isFormValid = false;

//       [
//         customerNameController,
//         customerAddressController,
//         customerPhoneController,
//         orderNoController,
//         orderUnitController,
//         bookingAdvanceController,
//         totalCustomerController,
//         collectionAmountController,
//         deliveryUnitController,
//         officeNameController,
//         remarksController,
//         spotPictureController
//       ].forEach((controller) => controller.clear());

//       _validateForm();
//     });
//     _getCurrentLocation();
//   }

//   Future<void> submitActivity() async {
//     if (empId == null || empId == "0") {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content: Text("Employee ID not found. Please log in again.")),
//       );
//       return;
//     }

//     if (!_formKey.currentState!.validate() || !isFormValid) {
//       _showValidationMessage();
//       return;
//     }

//     if (locationName == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content:
//                 Text("Location name could not be fetched. Please try again.")),
//       );
//       return;
//     }

//     setState(() => _isSubmitting = true);

//     final activityData = {
//       "emp_id": empId,
//       "customer_name": customerNameController.text.trim(),
//       "customer_address": customerAddressController.text.trim(),
//       "customer_phone_no": customerPhoneController.text.trim(),
//       "nature_of_work_id": selectedNatureOfWork ?? "",
//       "demo_product_id": selectedDemoProducts.join(','),
//       "order_no": orderNoController.text.trim(),
//       "result_id": selectedResult ?? "",
//       "remarks": remarksController.text.trim(),
//       "order_unit": orderUnitController.text.trim(),
//       "booking_advance": bookingAdvanceController.text.trim(),
//       "total_customer": totalCustomerController.text.trim(),
//       "collection_amount": collectionAmountController.text.trim(),
//       "delivery_unit": deliveryUnitController.text.trim(),
//       "office_name": officeNameController.text.trim(),
//       "verification_status": "pending",
//       "activity_checked_by": "",
//       "latitude": latitude?.toString() ?? "0.0",
//       "longitude": longitude?.toString() ?? "0.0",
//       "location": locationName ?? "Unknown",
//     };

//     final provider = Provider.of<ActivityProvider>(context, listen: false);
//     final isConnected =
//         (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

//     try {
//       if (isConnected) {
//         final success = await provider.insertActivity(activityData, _image);
//         setState(() => _isSubmitting = false);
//         if (success) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Activity Submitted Successfully"),
//               backgroundColor: Colors.green,
//             ),
//           );
//           _resetForm();
//         } else {
//           await provider.saveDraft(activityData, _image);
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text(
//                   "Failed to submit activity. Saved as draft for later sync."),
//               backgroundColor: Colors.orange,
//             ),
//           );
//           _resetForm();
//         }
//       } else {
//         await provider.saveDraft(activityData, _image);
//         setState(() => _isSubmitting = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//                 "No internet. Activity saved as draft and will sync later."),
//             backgroundColor: Colors.orange,
//           ),
//         );
//         _resetForm();
//       }
//     } catch (e) {
//       setState(() => _isSubmitting = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error submitting activity: $e")),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final double screenWidth = MediaQuery.of(context).size.width;
//     final double padding = screenWidth * 0.05;

//     if (isLoading) {
//       return Scaffold(
//         appBar: AppBar(
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
//             onPressed: () => Navigator.pop(context),
//           ),
//           title: const Text("Daily Activity",
//               style: TextStyle(color: Colors.white)),
//           backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
//           actions: [
//             IconButton(
//               icon: const Icon(Icons.refresh, color: Colors.white),
//               onPressed: _isOffline || _isSubmitting
//                   ? null
//                   : () async {
//                       await _loadData(showSyncMessage: true);
//                     },
//             ),
//           ],
//         ),
//         body: const Center(
//             child: CircularProgressIndicator(
//                 color: Color.fromRGBO(40, 167, 70, 1))),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title:
//             const Text("Daily Activity", style: TextStyle(color: Colors.white)),
//         backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh, color: Colors.white),
//             onPressed: _isOffline || _isSubmitting
//                 ? null
//                 : () async {
//                     await _loadData(showSyncMessage: true);
//                   },
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           GestureDetector(
//             onTap: () => FocusScope.of(context).unfocus(),
//             child: Padding(
//               padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
//               child: Form(
//                 key: _formKey,
//                 child: SingleChildScrollView(
//                   child: Column(
//                     children: [
//                       if (_isOffline)
//                         Padding(
//                           padding: const EdgeInsets.only(bottom: 10),
//                           child: Text(
//                             "Offline Mode: Using cached data",
//                             style: TextStyle(
//                               color: Colors.blue,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       Consumer<ActivityProvider>(
//                         builder: (context, provider, child) {
//                           print(
//                               'Nature of Work dropdown items: ${provider.natureOfWork}');
//                           return buildDropdown(
//                             "Nature of Work",
//                             selectedNatureOfWork,
//                             provider.natureOfWork.isEmpty
//                                 ? [
//                                     {'id': '0', 'name': 'No data available'}
//                                   ]
//                                 : provider.natureOfWork,
//                             (value) {
//                               setState(() {
//                                 selectedNatureOfWork = value;
//                                 // Reset dependent fields
//                                 selectedDemoProducts = [];
//                                 selectedResult = null;
//                                 _image = null;
//                                 spotPictureController.clear();
//                                 customerNameController.clear();
//                                 customerAddressController.clear();
//                                 customerPhoneController.clear();
//                                 orderNoController.clear();
//                                 orderUnitController.clear();
//                                 bookingAdvanceController.clear();
//                                 totalCustomerController.clear();
//                                 collectionAmountController.clear();
//                                 deliveryUnitController.clear();
//                                 officeNameController.clear();
//                                 remarksController.clear();
//                                 _validateForm();
//                               });
//                             },
//                             isRequired: true,
//                           );
//                         },
//                       ),
//                       buildDynamicFields(),
//                       const SizedBox(height: 20),
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: isFormValid && !isLoading && !_isSubmitting
//                               ? _showConfirmationDialog
//                               : () {
//                                   print(
//                                       'Submit button disabled: isFormValid=$isFormValid, '
//                                       'isLoading=$isLoading, _isSubmitting=$_isSubmitting');
//                                   _showValidationMessage();
//                                 },
//                           style: ElevatedButton.styleFrom(
//                             padding: const EdgeInsets.symmetric(vertical: 15),
//                             textStyle: const TextStyle(
//                                 fontSize: 18, fontWeight: FontWeight.bold),
//                             backgroundColor:
//                                 isFormValid && !isLoading && !_isSubmitting
//                                     ? const Color.fromRGBO(40, 167, 70, 1)
//                                     : Colors.grey,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                           child: _isSubmitting
//                               ? const CircularProgressIndicator(
//                                   color: Colors.white)
//                               : const Text("Submit Activity",
//                                   style: TextStyle(color: Colors.white)),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           if (_isSubmitting)
//             Container(
//               color: Colors.black.withOpacity(0.5),
//               child: const Center(
//                 child: CircularProgressIndicator(
//                     color: Color.fromRGBO(40, 167, 70, 1)),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     // Remove listeners and dispose controllers
//     [
//       customerNameController,
//       customerAddressController,
//       customerPhoneController,
//       orderNoController,
//       orderUnitController,
//       bookingAdvanceController,
//       totalCustomerController,
//       collectionAmountController,
//       deliveryUnitController,
//       officeNameController,
//       remarksController,
//       spotPictureController
//     ].forEach((controller) {
//       controller.removeListener(_validateForm);
//       controller.dispose();
//     });
//     super.dispose();
//   }
// }
