import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:nabeenkishan/dailyactivity/dailyactivity_provider.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyActivityForm extends StatefulWidget {
  @override
  _DailyActivityFormState createState() => _DailyActivityFormState();
}

class _DailyActivityFormState extends State<DailyActivityForm> {
  bool vederFormComplete = false; // Added definition for vederFormComplete
  bool isFormComplete = false; // Added definition for isFormComplete
  final _formKey = GlobalKey<FormState>();
  String? selectedNatureOfWork;
  List<String> selectedDemoProducts = [];
  String? selectedResult;
  File? _image;
  final picker = ImagePicker();
  double? latitude;
  double? longitude;
  String? locationName;
  String? empId;
  bool isFormValid = false;
  bool isLoading = false;
  bool _isSubmitting = false;
  final Map<String, bool> _locationLoadingStates = {};

  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerAddressController =
      TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController orderNoController = TextEditingController();
  final TextEditingController orderUnitController = TextEditingController();
  final TextEditingController bookingAdvanceController =
      TextEditingController();
  final TextEditingController totalCustomerController = TextEditingController();
  final TextEditingController collectionAmountController =
      TextEditingController();
  final TextEditingController deliveryUnitController = TextEditingController();
  final TextEditingController officeNameController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  final TextEditingController spotPictureController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadEmpId();

    [
      orderNoController,
      orderUnitController,
      bookingAdvanceController,
      customerNameController,
      customerAddressController,
      customerPhoneController,
      totalCustomerController,
      collectionAmountController,
      deliveryUnitController,
      officeNameController,
      remarksController
    ].forEach((controller) {
      controller.addListener(_validateForm);
    });

    Future.delayed(Duration.zero, () {
      setState(() => isLoading = true);
      final provider = Provider.of<ActivityProvider>(context, listen: false);
      Future.wait([
        provider.fetchNatureOfWork(),
        provider.fetchDemoProducts(),
        provider.fetchActivityResults()
      ]).then((_) => setState(() => isLoading = false));
    });
  }

  @override
  void dispose() {
    [
      orderNoController,
      orderUnitController,
      bookingAdvanceController,
      customerNameController,
      customerAddressController,
      customerPhoneController,
      totalCustomerController,
      collectionAmountController,
      deliveryUnitController,
      officeNameController,
      remarksController
    ].forEach((controller) {
      controller.removeListener(_validateForm);
    });

    [
      customerNameController,
      customerAddressController,
      customerPhoneController,
      orderNoController,
      orderUnitController,
      bookingAdvanceController,
      totalCustomerController,
      collectionAmountController,
      deliveryUnitController,
      officeNameController,
      remarksController,
      spotPictureController
    ].forEach((controller) {
      controller.dispose();
    });
    super.dispose();
  }

  Future<void> _loadEmpId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      empId = prefs.getString('emp_id') ?? "0";
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        spotPictureController.text = pickedFile.path;
        _validateForm();
      });
    }
  }

  Future<String?> _getLocationName(
      double latitude, double longitude, String activityId) async {
    setState(() {
      _locationLoadingStates[activityId] = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Permission Denied';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return 'Permission Denied Forever';
      }

      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        List<String> locationParts = {
          if (placemark.street?.isNotEmpty == true) placemark.street!,
          if (placemark.thoroughfare?.isNotEmpty == true)
            placemark.thoroughfare!,
          if (placemark.subLocality?.isNotEmpty == true) placemark.subLocality!,
          if (placemark.locality?.isNotEmpty == true) placemark.locality!,
          if (placemark.postalCode?.isNotEmpty == true) placemark.postalCode!,
          if (placemark.subAdministrativeArea?.isNotEmpty == true)
            placemark.subAdministrativeArea!,
          if (placemark.administrativeArea?.isNotEmpty == true)
            placemark.administrativeArea!,
          if (placemark.country?.isNotEmpty == true) placemark.country!,
        }.toList();
        String locationName = locationParts.join(', ');
        return locationName.isNotEmpty ? locationName : 'Unknown Location';
      }
      return 'No Location Found';
    } catch (e) {
      return 'Error: $e';
    } finally {
      setState(() {
        _locationLoadingStates[activityId] = false;
      });
    }
  }

  void _validateForm() {
    setState(() {
      bool isBasicValid =
          selectedNatureOfWork != null && selectedNatureOfWork!.isNotEmpty;
      vederFormComplete = true;

      switch (selectedNatureOfWork) {
        case '1': // DEMO
          isFormComplete = selectedDemoProducts.isNotEmpty &&
              customerNameController.text.trim().isNotEmpty &&
              customerAddressController.text.trim().isNotEmpty &&
              customerPhoneController.text.trim().isNotEmpty &&
              selectedResult != null &&
              _image != null;

          if (selectedResult == '2') {
            isFormComplete = isFormComplete &&
                orderNoController.text.trim().isNotEmpty &&
                orderUnitController.text.trim().isNotEmpty &&
                bookingAdvanceController.text.trim().isNotEmpty;
          }
          break;

        case '2': // DELIVERY & COLLECTION
          isFormComplete = totalCustomerController.text.trim().isNotEmpty &&
              collectionAmountController.text.trim().isNotEmpty &&
              deliveryUnitController.text.trim().isNotEmpty;
          break;

        case '3': // MEETING
        case '4':
          isFormComplete = officeNameController.text.trim().isNotEmpty &&
              remarksController.text.trim().isNotEmpty;
          break;

        case '5':
        case '6':
        case '7':
          isFormComplete = remarksController.text.trim().isNotEmpty;
          break;
      }

      isFormValid = isBasicValid && isFormComplete;
    });
  }

  void _showValidationMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please fill all required fields before submitting."),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showConfirmationDialog() {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Submission"),
          content: const Text("Are you sure you want to submit this activity?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Recheck", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  submitActivity();
                } else {
                  Navigator.pop(context);
                  _showValidationMessage();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child:
                  const Text("Confirm", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      TextInputType keyboardType,
      {bool isRequired = false,
      required List<TextInputFormatter> inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        enabled: !_isSubmitting,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: isRequired ? "$label *" : label,
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
        validator: isRequired
            ? (value) =>
                value?.trim().isEmpty ?? true ? "This field is required" : null
            : null,
      ),
    );
  }

  Widget buildDropdown(String label, String? selectedValue,
      List<Map<String, dynamic>> items, Function(String?) onChanged,
      {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: selectedValue,
        onChanged: _isSubmitting ? null : onChanged,
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item['id'].toString(),
            child: Text(item['name'].toString()),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: isRequired ? "$label *" : label,
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
        validator: isRequired
            ? (value) => value == null ? "This field is required" : null
            : null,
      ),
    );
  }

  Widget buildMultiSelectDropdown(String label, List<String> selectedValues,
      List<Map<String, dynamic>> items, Function(List<String>) onChanged,
      {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isRequired ? "$label *" : label,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _isSubmitting
                ? null
                : () async {
                    List<String> newSelectedValues = await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            List<String> tempSelected =
                                List.from(selectedValues);
                            return StatefulBuilder(
                              builder: (context, setState) {
                                return AlertDialog(
                                  title: Text('Select $label'),
                                  content: SizedBox(
                                    width: double.maxFinite,
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: items.map((item) {
                                        return CheckboxListTile(
                                          title: Text(item['name'].toString()),
                                          value: tempSelected
                                              .contains(item['id'].toString()),
                                          onChanged: (bool? value) {
                                            setState(() {
                                              if (value == true) {
                                                tempSelected
                                                    .add(item['id'].toString());
                                              } else {
                                                tempSelected.remove(
                                                    item['id'].toString());
                                              }
                                            });
                                          },
                                          activeColor: const Color.fromRGBO(
                                              40, 167, 70, 1),
                                          checkColor: Colors.white,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(
                                          context, selectedValues),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, tempSelected),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ) ??
                        selectedValues;

                    onChanged(newSelectedValues);
                    _validateForm();
                  },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color.fromRGBO(40, 167, 70, 1), width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      selectedValues.isEmpty
                          ? 'Select Products'
                          : items
                              .where((item) => selectedValues
                                  .contains(item['id'].toString()))
                              .map((item) => item['name'])
                              .join(', '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDynamicFields() {
    switch (selectedNatureOfWork) {
      case '1': // DEMO
        return Column(
          children: [
            Consumer<ActivityProvider>(
              builder: (context, provider, child) {
                return buildMultiSelectDropdown(
                  "Demo Products",
                  selectedDemoProducts,
                  provider.demoProducts,
                  (values) {
                    setState(() {
                      selectedDemoProducts = values;
                      _validateForm();
                    });
                  },
                  isRequired: true,
                );
              },
            ),
            buildTextField(
              "Customer Name",
              customerNameController,
              TextInputType.name,
              inputFormatters: [],
              isRequired: true,
            ),
            buildTextField(
              "Customer Address",
              customerAddressController,
              TextInputType.streetAddress,
              inputFormatters: [],
              isRequired: true,
            ),
            TextFormField(
              controller: customerPhoneController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: "Customer Mobile Number *",
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
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) || (value?.length != 10)
                      ? "Enter a valid 10-digit number"
                      : null,
            ),
            Consumer<ActivityProvider>(
              builder: (context, provider, child) {
                return buildDropdown(
                  "Select Result",
                  selectedResult,
                  provider.activityResults,
                  (value) {
                    setState(() {
                      selectedResult = value;
                      _validateForm();
                    });
                  },
                  isRequired: true,
                );
              },
            ),
            if (selectedResult == '2') ...[
              buildTextField("Order No", orderNoController, TextInputType.text,
                  inputFormatters: [], isRequired: true),
              buildTextField(
                  "Order Unit", orderUnitController, TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  isRequired: true),
              buildTextField("Booking Advance", bookingAdvanceController,
                  TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  isRequired: true),
            ],
            buildTextField("Remarks", remarksController, TextInputType.text,
                inputFormatters: []),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: spotPictureController,
                    enabled: !_isSubmitting,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Spot Picture Path *",
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
                    validator: (value) =>
                        _image == null ? "Please upload a spot picture" : null,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _pickImage,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                    backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        );
      case '2': // DELIVERY & COLLECTION
        return Column(
          children: [
            buildTextField(
                "Total Customer", totalCustomerController, TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                isRequired: true),
            buildTextField("Collection Amount", collectionAmountController,
                TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                isRequired: true),
            buildTextField(
                "Delivery Unit", deliveryUnitController, TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                isRequired: true),
            buildTextField("Remarks", remarksController, TextInputType.text,
                inputFormatters: []),
          ],
        );
      case '3': // MEETING
      case '4':
        return Column(
          children: [
            buildTextField(
                "Office Name", officeNameController, TextInputType.name,
                inputFormatters: [], isRequired: true),
            buildTextField("Remarks", remarksController, TextInputType.text,
                inputFormatters: [], isRequired: true),
          ],
        );
      case '5':
      case '6':
      case '7':
        return buildTextField("Remarks", remarksController, TextInputType.text,
            inputFormatters: [], isRequired: true);
      default:
        return Container();
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permission denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permission permanently denied.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
    });

    if (latitude != null && longitude != null && empId != null) {
      String? fetchedLocationName = await _getLocationName(
        latitude!,
        longitude!,
        empId!,
      );
      setState(() {
        locationName = fetchedLocationName;
      });
    }
  }

  void _resetForm() {
    setState(() {
      selectedNatureOfWork = null;
      selectedDemoProducts = [];
      selectedResult = null;
      _image = null;
      latitude = null;
      longitude = null;
      locationName = null;
      isFormValid = false;

      [
        customerNameController,
        customerAddressController,
        customerPhoneController,
        orderNoController,
        orderUnitController,
        bookingAdvanceController,
        totalCustomerController,
        collectionAmountController,
        deliveryUnitController,
        officeNameController,
        remarksController,
        spotPictureController
      ].forEach((controller) {
        controller.clear();
      });

      _getCurrentLocation();
    });
    FocusScope.of(context).unfocus();
  }

  void submitActivity() async {
    if (empId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Employee ID not found. Please log in again.")),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (locationName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Location name could not be fetched. Please try again.")),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    bool success = await Provider.of<ActivityProvider>(context, listen: false)
        .insertActivity({
      "emp_id": empId,
      "customer_name": customerNameController.text,
      "customer_address": customerAddressController.text,
      "customer_phone_no": customerPhoneController.text,
      "nature_of_work_id": selectedNatureOfWork ?? "",
      "demo_product_id": selectedDemoProducts.join(','),
      "order_no": orderNoController.text,
      "result_id": selectedResult ?? "",
      "remarks": remarksController.text,
      "order_unit": orderUnitController.text,
      "booking_advance": bookingAdvanceController.text,
      "total_customer": totalCustomerController.text,
      "collection_amount": collectionAmountController.text,
      "delivery_unit": deliveryUnitController.text,
      "office_name": officeNameController.text,
      "verification_status": "pending",
      "activity_checked_by": "",
      "latitude": latitude?.toString() ?? "0.0",
      "longitude": longitude?.toString() ?? "0.0",
      "location": locationName ?? "Unknown",
    }, _image);

    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Activity Submitted Successfully"),
          backgroundColor: Colors.green,
        ),
      );

      _resetForm();

      final provider = Provider.of<ActivityProvider>(context, listen: false);
      await Future.wait([
        provider.fetchNatureOfWork(),
        provider.fetchDemoProducts(),
        provider.fetchActivityResults()
      ]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to Submit Activity")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double padding = screenWidth * 0.05;

    if (isLoading && selectedNatureOfWork == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Daily Activity",
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFF28A746))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title:
            const Text("Daily Activity", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Consumer<ActivityProvider>(
                        builder: (context, provider, child) {
                          return buildDropdown(
                            "Nature of Work",
                            selectedNatureOfWork,
                            provider.natureOfWork,
                            (value) {
                              setState(() {
                                _resetForm(); // Reset the form first
                                selectedNatureOfWork =
                                    value; // Set the new value
                                _validateForm(); // Validate the form after reset
                              });
                            },
                            isRequired: true,
                          );
                        },
                      ),
                      buildDynamicFields(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isFormValid && !isLoading && !_isSubmitting
                              ? _showConfirmationDialog
                              : _showValidationMessage,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            textStyle: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            backgroundColor:
                                isFormValid && !isLoading && !_isSubmitting
                                    ? const Color.fromRGBO(40, 167, 70, 1)
                                    : Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text("Submit Activity",
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color.fromRGBO(40, 167, 70, 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
