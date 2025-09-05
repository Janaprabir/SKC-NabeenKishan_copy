
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:nabeenkishan/manager/office_nature_of_id.dart';
import 'package:nabeenkishan/manager/result.dart';
import 'package:nabeenkishan/manager/status_of_work_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'nature_of_work.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class InsertActivityPage extends StatefulWidget {
  const InsertActivityPage({super.key});

  @override
  _InsertActivityPageState createState() => _InsertActivityPageState();
}

class _InsertActivityPageState extends State<InsertActivityPage> {
  final OfficeNatureOfId _officeNatureOfId = OfficeNatureOfId();
  final NatureOfWorkId _natureOfWork = NatureOfWorkId();
  final StatusOfWork _statusOfWork = StatusOfWork();
  final Result _activityResult = Result();
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerMobileController = TextEditingController();
  final _orderNoController = TextEditingController();
  final _orderUnitController = TextEditingController();
  final _bookingAdvanceController = TextEditingController();
  final _remarksController = TextEditingController();
  final _campNameController = TextEditingController();
  final _nameGCACGLController = TextEditingController();
  final _spotPictureController = TextEditingController();

  String? _selectedNatureOfWork;
  String? _selectedResult;
  String? _selectedOfficeNatureOfId;
  String? _selectedStatusOfWork;
  List<String> _selectedDemoProducts = [];
  List<Map<String, dynamic>> _demoProducts = [];
  File? _image;
  final picker = ImagePicker();

  String? _activityId;
  bool _isEditing = false;
  String? _selectedOfficeName;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _editingActivityId;
  List<Map<String, String>> _submittedData = [];
  bool isFormValid = false;
  bool _isCampEnabled = false;
  bool _isOfficeEnabled = false;
  bool _isInterviewEnabled = false;
  bool _isLeaveEnabled = false;
  double? latitude;
  double? longitude;
  String? locationName;
  bool _isLocationFetched = false;
  bool _isLocationLoading = false;
  final Map<String, bool> _locationLoadingStates = {};
  bool _isFieldSupportSelected = false;

  List<String> _officeNames = [];

  // Helper method to check if the selected nature of work is CAMP VISIT or COLLECTION
  // TODO: Verify IDs '2' (CAMP VISIT) and '3' (COLLECTION) in _natureOfWork.natureOfWorkItems
  bool get _isCampVisitOrCollection =>
      _selectedNatureOfWork == '2' || _selectedNatureOfWork == '3';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadInitialData();
    _fetchOfficeNames();
    _fetchDemoProducts();

    _orderNoController.addListener(_validateForm);
    _orderUnitController.addListener(_validateForm);
    _bookingAdvanceController.addListener(_validateForm);
    _campNameController.addListener(_validateForm);
    _nameGCACGLController.addListener(_validateForm);
    _customerNameController.addListener(_validateForm);
    _customerAddressController.addListener(_validateForm);
    _customerMobileController.addListener(_validateForm);
    _remarksController.addListener(_validateForm);
    _spotPictureController.addListener(_validateForm);
  }

  Future<void> _fetchOfficeNames() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllBranch',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _officeNames =
              data.map((branch) => branch['branch_name'] as String).toList();
        });
      }
    } catch (e) {
      print('Error fetching office names: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDemoProducts() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllProducts'));

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        setState(() {
          _demoProducts = data
              .map((item) =>
                  {"id": item['product_id'], "name": item['product_name']})
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching demo products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _officeNatureOfId.fetchOfficeNatureOfId(setState),
      _natureOfWork.fetchNatureOfWorkItems(setState),
      _activityResult.fetchResults(setState),
      _statusOfWork.fetchStatusOfWorkItems(setState),
    ]);
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _orderNoController.removeListener(_validateForm);
    _orderUnitController.removeListener(_validateForm);
    _bookingAdvanceController.removeListener(_validateForm);
    _campNameController.removeListener(_validateForm);
    _nameGCACGLController.removeListener(_validateForm);
    _customerNameController.removeListener(_validateForm);
    _customerAddressController.removeListener(_validateForm);
    _customerMobileController.removeListener(_validateForm);
    _remarksController.removeListener(_validateForm);
    _spotPictureController.removeListener(_validateForm);

    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerMobileController.dispose();
    _orderNoController.dispose();
    _orderUnitController.dispose();
    _bookingAdvanceController.dispose();
    _remarksController.dispose();
    _campNameController.dispose();
    _nameGCACGLController.dispose();
    _spotPictureController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _spotPictureController.text = pickedFile.path;
        _validateForm();
      });
    }
  }

  Future<String> _getLocationName(
      double latitude, double longitude, String activityId) async {
    setState(() {
      _locationLoadingStates[activityId] = true;
      _isLocationLoading = true;
    });

    try {
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
        _isLocationLoading = false;
      });
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Please enable GPS.'),
        ),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied.'),
          ),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permission permanently denied. Please enable it in settings.'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
      _isLocationFetched = false;
    });

    bool hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) {
      setState(() {
        _isLocationLoading = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });

      if (latitude != null && longitude != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? empId = prefs.getString('emp_id') ?? 'unknown';
        String fetchedLocationName = await _getLocationName(
          latitude!,
          longitude!,
          empId,
        );

        setState(() {
          locationName = fetchedLocationName;
          _isLocationFetched = locationName != null &&
              !locationName!.startsWith('Error:') &&
              locationName != 'No Location Found' &&
              locationName != 'Unknown Location';
          _isLocationLoading = false;
        });

        if (!_isLocationFetched) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to fetch location: $locationName'),
            ),
          );
        }
      } else {
        setState(() {
          _isLocationLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get coordinates.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLocationLoading = false;
      });
      print('Error fetching location: $e');
    }
  }

  void _validateForm() {
    setState(() {
      _isFieldSupportSelected = _selectedNatureOfWork == '1';
      bool isBasicValid = _selectedStatusOfWork != null;
      bool isCampValid = true;

      if (_isCampEnabled) {
        isCampValid = _campNameController.text.trim().isNotEmpty &&
            _selectedNatureOfWork != null &&
            _nameGCACGLController.text.trim().isNotEmpty;

        // Only validate customer fields if not CAMP VISIT or COLLECTION
        if (!_isCampVisitOrCollection) {
          isCampValid = isCampValid &&
              _customerNameController.text.trim().isNotEmpty &&
              _customerAddressController.text.trim().isNotEmpty &&
              _customerMobileController.text.trim().isNotEmpty;
        }

        if (_isFieldSupportSelected) {
          isCampValid =
              isCampValid && _image != null && _selectedDemoProducts.isNotEmpty;
        }

        // Only validate result-related fields if not CAMP VISIT or COLLECTION
        if (!_isCampVisitOrCollection && _selectedResult == '2') {
          isCampValid = isCampValid &&
              _orderNoController.text.trim().isNotEmpty &&
              _orderUnitController.text.trim().isNotEmpty &&
              _bookingAdvanceController.text.trim().isNotEmpty;
        }
      }

      if (_isOfficeEnabled) {
        isCampValid =
            _selectedOfficeName != null && _selectedOfficeNatureOfId != null;
      }

      if (_isInterviewEnabled || _isLeaveEnabled) {
        isCampValid = _remarksController.text.trim().isNotEmpty;
      }

      isFormValid = isBasicValid && isCampValid;
    });
  }

  void _clearForm() {
    _customerNameController.clear();
    _customerAddressController.clear();
    _customerMobileController.clear();
    _orderNoController.clear();
    _orderUnitController.clear();
    _bookingAdvanceController.clear();
    _remarksController.clear();
    _campNameController.clear();
    _nameGCACGLController.clear();
    _spotPictureController.clear();

    setState(() {
      _selectedNatureOfWork = null;
      _selectedResult = null;
      _selectedOfficeNatureOfId = null;
      _selectedOfficeName = null;
      _selectedStatusOfWork = null; // Reset status of work
      _selectedDemoProducts = [];
      _image = null;
      _isCampEnabled = false; // Reset camp enabled
      _isOfficeEnabled = false;
      _isInterviewEnabled = false;
      _isLeaveEnabled = false;
      _isEditing = false;
      _isFieldSupportSelected = false;
      isFormValid = false;
    });

    _getCurrentLocation(); // Re-fetch location on form reset
  }

  void _editEntry(int activityId) async {
    try {
      var response = await http.get(Uri.parse(
          'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/getActivityById.php?activity_id=$activityId'));

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        var activityData = responseData['data'];

        setState(() {
          _customerNameController.text = activityData['customer_name'] ?? '';
          _customerAddressController.text =
              activityData['customer_address'] ?? '';
          _customerMobileController.text =
              activityData['customer_phone_no'] ?? '';
          _orderNoController.text = activityData['order_no'] ?? '0';
          _orderUnitController.text = activityData['booking_unit'].toString();
          _bookingAdvanceController.text =
              activityData['booking_advance'].toString();
          _remarksController.text = activityData['remarks'] ?? '';
          _campNameController.text = activityData['camp_name'] ?? '';
          _nameGCACGLController.text = activityData['name_of_se_gc_gl'] ?? '';
          _selectedOfficeName = activityData['office_name'] ?? '';
          _selectedNatureOfWork = activityData['camp_nature_of_work_id'];
          _selectedResult = activityData['result_id'];
          _selectedOfficeNatureOfId = activityData['office_nature_of_work_id'];
          _selectedStatusOfWork = activityData['status_of_work_id'];
          _editingActivityId = activityData['activity_id'];
          _isEditing = true;

          if (_selectedStatusOfWork == '1') {
            _isCampEnabled = true;
            _isOfficeEnabled = false;
            _isInterviewEnabled = false;
            _isLeaveEnabled = false;
          } else if (_selectedStatusOfWork == '2') {
            _isCampEnabled = false;
            _isOfficeEnabled = true;
            _isInterviewEnabled = false;
            _isLeaveEnabled = false;
          } else if (_selectedStatusOfWork == '3' ||
              _selectedStatusOfWork == '4') {
            _isCampEnabled = false;
            _isOfficeEnabled = false;
            _isInterviewEnabled = _selectedStatusOfWork == '3';
            _isLeaveEnabled = _selectedStatusOfWork == '4';
          }

          _validateForm();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity loaded for editing!')),
        );
      }
    } catch (e) {
      print('Error fetching activity data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load activity: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              onPressed: () => Navigator.pop(context),
              child: const Text("Recheck", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitForm();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child:
                  const Text("Confirm", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() == true &&
        isFormValid &&
        _isLocationFetched) {
      FocusScope.of(context).unfocus();
      setState(() => _isSubmitting = true);
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? empId = prefs.getString('emp_id');

        if (empId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Emp ID not found in session!')),
          );
          setState(() => _isSubmitting = false);
          return;
        }

        final data = {
          'emp_id': empId,
          if (!_isCampVisitOrCollection) ...{
            'customer_name': _customerNameController.text,
            'customer_address': _customerAddressController.text,
            'customer_phone_no': _customerMobileController.text,
          },
          'status_of_work_id': _selectedStatusOfWork ?? '',
          'camp_name': _campNameController.text,
          'camp_nature_of_work_id': _selectedNatureOfWork ?? '',
          'demo_product_id': _selectedDemoProducts.join(','),
          if (!_isCampVisitOrCollection) ...{
            'order_no': _orderNoController.text,
            'result_id': _selectedResult ?? '',
          },
          'name_of_se_gc_gl': _nameGCACGLController.text,
          'remarks': _remarksController.text,
          'booking_unit': _orderUnitController.text,
          'booking_advance': _bookingAdvanceController.text,
          'office_name': _selectedOfficeName ?? '',
          'office_nature_of_work_id': _selectedOfficeNatureOfId ?? '',
          'latitude': latitude?.toString() ?? '',
          'longitude': longitude?.toString() ?? '',
          'location': locationName ?? 'Unknown',
        };

        print('Submitting data: $data');

        var request = http.MultipartRequest(
          'POST',
          Uri.parse(
              'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/insertActivity.php'),
        );

        request.headers['Content-Type'] = 'multipart/form-data';
        request.fields
            .addAll(data.map((key, value) => MapEntry(key, value.toString())));
        if (_image != null) {
          request.files.add(
              await http.MultipartFile.fromPath('spot_picture', _image!.path));
        }

        var response = await request.send();
        var responseBody = await response.stream.bytesToString();

        if (response.statusCode == 201) {
          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activity submitted successfully!'),
              backgroundColor: Color.fromRGBO(40, 167, 70, 1),
            ),
          );
        } else {
          print('API Response: $responseBody');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to submit activity! Status: ${response.statusCode}, Response: $responseBody'),
              backgroundColor: const Color.fromRGBO(255, 0, 0, 1),
            ),
          );
        }
      } catch (e) {
        print('Submission Error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildMultiSelectDropdown(
    String label,
    List<String> selectedValues,
    List<Map<String, dynamic>> items,
    Function(List<String>) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label *", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              List<String> newSelectedValues = await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      List<String> tempSelected = List.from(selectedValues);
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
                                          tempSelected
                                              .remove(item['id'].toString());
                                        }
                                      });
                                    },
                                    activeColor:
                                        const Color.fromRGBO(40, 167, 70, 1),
                                    checkColor: Colors.white,
                                  );
                                }).toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, selectedValues),
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
                          : _demoProducts
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _selectedStatusOfWork == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Insert Activity',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
          iconTheme: const IconThemeData(color: Colors.white),
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
        title: const Text('Insert Activity',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField(
                    decoration: InputDecoration(
                      labelText: 'Select Status of work *',
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
                    items: _statusOfWork.statusOfWorkItems,
                    value: _selectedStatusOfWork,
                    onChanged: (value) {
                      setState(() {
                        _selectedStatusOfWork = value;
                        _clearForm();
                        _selectedStatusOfWork = value;
                        if (value == '1') {
                          _isCampEnabled = true;
                          _isOfficeEnabled = false;
                          _isInterviewEnabled = false;
                          _isLeaveEnabled = false;
                        } else if (value == '2') {
                          _isCampEnabled = false;
                          _isOfficeEnabled = true;
                          _isInterviewEnabled = false;
                          _isLeaveEnabled = false;
                        } else if (value == '3' || value == '4') {
                          _isCampEnabled = false;
                          _isOfficeEnabled = false;
                          _isInterviewEnabled = value == '3';
                          _isLeaveEnabled = value == '4';
                        }
                        _validateForm();
                      });
                    },
                    validator: (value) =>
                        value == null ? 'Please select status of work' : null,
                  ),
                  if (_isCampEnabled) ...[
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _campNameController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Enter Camp Name *',
                        border: 
                        OutlineInputBorder(
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Camp Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Camp nature of work *',
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
                      items: _natureOfWork.natureOfWorkItems,
                      value: _selectedNatureOfWork,
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              setState(() {
                                _selectedNatureOfWork = value;
                                _isCampEnabled = true;
                                _validateForm();
                              });
                            },
                      validator: (value) => value == null
                          ? 'Please select a nature of work'
                          : null,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _nameGCACGLController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Enter name of GC/SE/GL *',
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name of GC/SE/GL is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    if (_isFieldSupportSelected) ...[
                      _buildMultiSelectDropdown(
                        "Demo Products",
                        _selectedDemoProducts,
                        _demoProducts,
                        (values) {
                          setState(() {
                            _selectedDemoProducts = values;
                            _validateForm();
                          });
                        },
                      ),
                    ],
                    if (!_isCampVisitOrCollection) ...[
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _customerNameController,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Enter customer name *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Customer Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _customerAddressController,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Enter customer address *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Customer Address is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _customerMobileController,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Enter customer mobile no *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Customer Mobile No is required';
                          } else if (value.length != 10) {
                            return 'Mobile No must be 10 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Result *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                        ),
                        items: _activityResult.activityResults,
                        value: _selectedResult,
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedResult = value;
                                  if (value != '2') {
                                    _orderNoController.clear();
                                    _orderUnitController.clear();
                                    _bookingAdvanceController.clear();
                                  }
                                  _validateForm();
                                });
                              },
                        validator: (value) =>
                            value == null ? 'Please select a result' : null,
                      ),
                    ],
                    if (!_isCampVisitOrCollection && _selectedResult == '2') ...[
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _orderNoController,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'Enter order no *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color.fromRGBO(40, 167, 70, 1),
                                width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.text,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Order No is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _orderUnitController,
                              enabled: !_isSubmitting,
                              decoration: InputDecoration(
                                labelText: 'Booking Unit *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color.fromRGBO(40, 167, 70, 1),
                                      width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color.fromRGBO(40, 167, 70, 1),
                                      width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Booking Unit is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: TextFormField(
                              controller: _bookingAdvanceController,
                              enabled: !_isSubmitting,
                              decoration: InputDecoration(
                                labelText: 'Booking Advance *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color.fromRGBO(40, 167, 70, 1),
                                      width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color.fromRGBO(40, 167, 70, 1),
                                      width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Booking Advance is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _remarksController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Enter remarks',
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
                    if (_isFieldSupportSelected) ...[
                      const SizedBox(height: 16.0),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _spotPictureController,
                              enabled: !_isSubmitting,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Spot Picture Path *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color.fromRGBO(40, 167, 70, 1),
                                      width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color.fromRGBO(40, 167, 70, 1),
                                      width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (_image == null) {
                                  return 'Spot Picture is required for FIELD SUPPORT';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _pickImage,
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                              backgroundColor:
                                  const Color.fromRGBO(40, 167, 70, 1),
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
                  ],
                  if (_isOfficeEnabled) ...[
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Office Name *',
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
                      value: _selectedOfficeName,
                      items: _officeNames.map((String office) {
                        return DropdownMenuItem<String>(
                          value: office,
                          child: Text(office),
                        );
                      }).toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (String? value) {
                              setState(() {
                                _selectedOfficeName = value;
                                _validateForm();
                              });
                            },
                      validator: (value) =>
                          value == null ? 'Please select an office name' : null,
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select office nature of work *',
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
                      items: _officeNatureOfId.officeNatureOfItems,
                      value: _selectedOfficeNatureOfId,
                      onChanged: _isSubmitting
                          ? null
                          : (value) {
                              setState(() {
                                _selectedOfficeNatureOfId = value;
                                _validateForm();
                              });
                            },
                      validator: (value) => value == null
                          ? 'Please select office nature of work'
                          : null,
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _remarksController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Enter remarks',
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
                  ],
                  if (_isInterviewEnabled || _isLeaveEnabled) ...[
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _remarksController,
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Enter remarks *',
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
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Remarks are required';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: isFormValid &&
                            !_isLoading &&
                            !_isSubmitting &&
                            _isLocationFetched
                        ? _showConfirmationDialog
                        : null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: isFormValid &&
                              !_isLoading &&
                              !_isSubmitting &&
                              _isLocationFetched
                          ? const Color.fromRGBO(40, 167, 70, 1)
                          : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 90, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                    ),
                    child: _isLocationLoading || _isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text('Submit', style: TextStyle(fontSize: 18)),
                  ),
                ],
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
