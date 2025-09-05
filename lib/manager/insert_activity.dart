import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'manager_activity_provider.dart'; // Ensure this import matches your file structure

class InsertActivityPage extends StatefulWidget {
  const InsertActivityPage({super.key});

  @override
  _InsertActivityPageState createState() => _InsertActivityPageState();
}

class _InsertActivityPageState extends State<InsertActivityPage> {
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
  File? _image;
  final picker = ImagePicker();
  String? _editingActivityId;
  bool _isEditing = false;
  String? _selectedOfficeName;
  bool _isCampEnabled = false;
  bool _isOfficeEnabled = false;
  bool _isInterviewEnabled = false;
  bool _isLeaveEnabled = false;
  double? latitude;
  double? longitude;
  String? locationName;
  bool _isLocationFetched = false;
  bool _isLocationLoading = false;
  bool _isNetworkConnected = true;
  bool _isOfflineMode = false;
  final Map<String, bool> _locationLoadingStates = {};
  bool _isFieldSupportSelected = false;
  bool isFormValid = false;
  String? _errorMessage;

  bool get _isCampVisitOrCollection =>
      _selectedNatureOfWork == '2' || _selectedNatureOfWork == '3';

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _getCurrentLocation();
    _listenForConnectivityChanges();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ManagerActivityProvider>(context, listen: false);
      provider.loadCachedData().then((_) {
        setState(() {
          _validateForm();
        });
        if (!_isOfflineMode && _isNetworkConnected) {
          _fetchOnlineData(provider);
        } else if (provider.statusOfWorkItems.isEmpty ||
            provider.natureOfWorkItems.isEmpty ||
            provider.activityResults.isEmpty ||
            provider.officeNames.isEmpty ||
            provider.officeNatureOfIdItems.isEmpty ||
            provider.demoProducts.isEmpty) {
          setState(() {
            _errorMessage = 'Some dropdown data is missing. Using cached data.';
          });
          _showOfflineDataWarning();
        }
      }).catchError((e) {
        setState(() {
          _errorMessage = 'Failed to load cached data: $e';
          _isOfflineMode = true;
        });
        _showOfflineDataWarning();
      });
    });
    _addValidationListeners();
  }

  void _addValidationListeners() {
    _orderNoController.addListener(_debouncedValidateForm);
    _orderUnitController.addListener(_debouncedValidateForm);
    _bookingAdvanceController.addListener(_debouncedValidateForm);
    _campNameController.addListener(_debouncedValidateForm);
    _nameGCACGLController.addListener(_debouncedValidateForm);
    _customerNameController.addListener(_debouncedValidateForm);
    _customerAddressController.addListener(_debouncedValidateForm);
    _customerMobileController.addListener(_debouncedValidateForm);
    _remarksController.addListener(_debouncedValidateForm);
    _spotPictureController.addListener(_debouncedValidateForm);
  }

  Timer? _debounce;
  void _debouncedValidateForm() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _validateForm();
      });
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final isConnected = await _checkNetworkConnectivity();
    setState(() {
      _isNetworkConnected = isConnected;
      _isOfflineMode = !isConnected;
    });
    if (!_isNetworkConnected) {
      _showOfflineDataWarning();
    }
  }

  void _listenForConnectivityChanges() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final isConnected = results.any((result) => result != ConnectivityResult.none);
      setState(() {
        _isNetworkConnected = isConnected;
        _isOfflineMode = !isConnected;
      });
      if (isConnected && _isOfflineMode) {
        _showOnlineModeDialog();
      } else if (!isConnected && !_isOfflineMode) {
        _showOfflineDataWarning();
      }
      if (isConnected) {
        final provider = Provider.of<ManagerActivityProvider>(context, listen: false);
        _fetchOnlineData(provider);
      }
    });
  }

  void _fetchOnlineData(ManagerActivityProvider provider) {
    Future.wait([
      provider.fetchOfficeNames(forceFetch: true).catchError((e) {
        setState(() {
          _errorMessage = 'Failed to fetch office names: $e';
        });
      }),
      provider.fetchDemoProducts(forceFetch: true).catchError((e) {
        setState(() {
          _errorMessage = 'Failed to fetch demo products: $e';
        });
      }),
      provider.fetchStatusOfWorkItems(forceFetch: true).catchError((e) {
        setState(() {
          _errorMessage = 'Failed to fetch status of work: $e';
        });
      }),
      provider.fetchOfficeNatureOfId(forceFetch: true).catchError((e) {
        setState(() {
          _errorMessage = 'Failed to fetch office nature of work: $e';
        });
      }),
      provider.fetchNatureOfWork(forceFetch: true).catchError((e) {
        setState(() {
          _errorMessage = 'Failed to fetch nature of work: $e';
        });
      }),
      provider.fetchActivityResults(forceFetch: true).catchError((e) {
        setState(() {
          _errorMessage = 'Failed to fetch activity results: $e';
        });
      }),
      provider.syncDrafts().catchError((e) {
        setState(() {
          _errorMessage = 'Failed to sync drafts: $e';
        });
      }),
    ]).then((_) {
      if (_errorMessage != null && !_isOfflineMode) {
        _showNetworkErrorDialog();
      }
    });
  }

  void _showNetworkErrorDialog() {
    if (_isOfflineMode) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Network Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'No internet connection or slow network detected.\nPlease check your connection and try again or use offline mode.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28A746),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        final provider = Provider.of<ManagerActivityProvider>(context, listen: false);
                        _fetchOnlineData(provider);
                      },
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        setState(() {
                          _isOfflineMode = true;
                          _isNetworkConnected = false;
                        });
                        Navigator.of(context).pop();
                        final provider = Provider.of<ManagerActivityProvider>(context, listen: false);
                        provider.loadCachedData().then((_) {
                          setState(() {
                            _validateForm();
                          });
                          if (provider.statusOfWorkItems.isEmpty ||
                              provider.natureOfWorkItems.isEmpty ||
                              provider.activityResults.isEmpty ||
                              provider.officeNames.isEmpty ||
                              provider.officeNatureOfIdItems.isEmpty ||
                              provider.demoProducts.isEmpty) {
                            setState(() {
                              _errorMessage = 'Some dropdown data is missing in offline mode.';
                            });
                            _showOfflineDataWarning();
                          }
                        });
                      },
                      child: const Text(
                        'Offline Mode',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOfflineDataWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Offline Mode'),
          content: Text(
            _errorMessage ?? 'You are in offline mode. Using cached data for dropdowns. Activities will be saved as drafts.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                final provider = Provider.of<ManagerActivityProvider>(context, listen: false);
                provider.loadCachedData().then((_) {
                  setState(() {
                    _validateForm();
                  });
                });
              },
              child: const Text('Retry Loading Cached Data'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue Offline'),
            ),
          ],
        );
      },
    );
  }

  void _showOnlineModeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Internet Restored',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Internet connection detected.\nWould you like to switch to online mode?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Stay Offline',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28A746),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        setState(() {
                          _isOfflineMode = false;
                          _isNetworkConnected = true;
                        });
                        Navigator.of(context).pop();
                        final provider = Provider.of<ManagerActivityProvider>(context, listen: false);
                        _fetchOnlineData(provider);
                      },
                      child: const Text(
                        'Go Online',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
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
        List<String> locationParts = [
          if (placemark.street?.isNotEmpty == true) placemark.street!,
          if (placemark.thoroughfare?.isNotEmpty == true) placemark.thoroughfare!,
          if (placemark.subLocality?.isNotEmpty == true) placemark.subLocality!,
          if (placemark.locality?.isNotEmpty == true) placemark.locality!,
          if (placemark.postalCode?.isNotEmpty == true) placemark.postalCode!,
          if (placemark.subAdministrativeArea?.isNotEmpty == true)
            placemark.subAdministrativeArea!,
          if (placemark.administrativeArea?.isNotEmpty == true)
            placemark.administrativeArea!,
          if (placemark.country?.isNotEmpty == true) placemark.country!,
        ].where((part) => part.isNotEmpty).toList();
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
        if (!_isLocationFetched && !_isOfflineMode) {
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
      debugPrint('Error fetching location: $e');
      if (!_isOfflineMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _validateForm() {
    _isFieldSupportSelected = _selectedNatureOfWork == '1';
    bool isBasicValid = _selectedStatusOfWork != null;
    bool isCampValid = true;
    if (_isCampEnabled) {
      isCampValid = _campNameController.text.trim().isNotEmpty &&
          _selectedNatureOfWork != null &&
          _nameGCACGLController.text.trim().isNotEmpty;
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
      _selectedStatusOfWork = null;
      _selectedDemoProducts = [];
      _image = null;
      _isCampEnabled = false;
      _isOfficeEnabled = false;
      _isInterviewEnabled = false;
      _isLeaveEnabled = false;
      _isEditing = false;
      _isFieldSupportSelected = false;
      isFormValid = false;
      _errorMessage = null;
    });
    _getCurrentLocation();
  }

  void _editEntry(int activityId) async {
    if (_isOfflineMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Editing is not available in offline mode.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final provider = Provider.of<ManagerActivityProvider>(context, listen: false);
    try {
      final activityData = await provider.fetchActivityById(activityId);
      setState(() {
        _customerNameController.text = activityData['customer_name'] ?? '';
        _customerAddressController.text = activityData['customer_address'] ?? '';
        _customerMobileController.text = activityData['customer_phone_no'] ?? '';
        _orderNoController.text = activityData['order_no'] ?? '0';
        _orderUnitController.text = activityData['booking_unit'].toString();
        _bookingAdvanceController.text = activityData['booking_advance'].toString();
        _remarksController.text = activityData['remarks'] ?? '';
        _campNameController.text = activityData['camp_name'] ?? '';
        _nameGCACGLController.text = activityData['name_of_se_gc_gl'] ?? '';
        _selectedOfficeName = activityData['office_name'] ?? '';
        _selectedNatureOfWork = activityData['camp_nature_of_work_id'];
        _selectedResult = activityData['result_id'];
        _selectedOfficeNatureOfId = activityData['office_nature_of_work_id'];
        _selectedStatusOfWork = activityData['status_of_work_id'];
        _editingActivityId = activityData['activity_id'].toString();
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
    } catch (e) {
      if (!_isOfflineMode) {
        setState(() => _errorMessage = 'Failed to load activity: $e');
        _showNetworkErrorDialog();
      }
    }
  }

  void _showConfirmationDialog() {
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Submission"),
          content: Text(_isOfflineMode
              ? "You are in offline mode. The activity will be saved as a draft and synced when online."
              : "Are you sure you want to submit this activity?"),
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
              child: const Text("Confirm", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() == true && isFormValid) {
      FocusScope.of(context).unfocus();
      final provider = Provider.of<ManagerActivityProvider>(context, listen: false);
      try {
        final data = {
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
          'latitude': _isOfflineMode ? '' : latitude?.toString() ?? '',
          'longitude': _isOfflineMode ? '' : longitude?.toString() ?? '',
          'location': _isOfflineMode ? 'Pending' : locationName ?? 'Unknown',
          'sync_status': _isOfflineMode ? 'pending' : 'synced',
        };
        bool success = await provider.submitActivity(data: data, image: _image);
        if (success || _isOfflineMode) {
          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isOfflineMode
                  ? 'Activity saved as draft successfully!'
                  : 'Activity submitted successfully!'),
              backgroundColor: const Color.fromRGBO(40, 167, 70, 1),
            ),
          );
        }
      } catch (e) {
        if (!_isOfflineMode) {
          setState(() => _errorMessage = 'Submission failed: $e');
          _showNetworkErrorDialog();
        }
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
            onTap: items.isEmpty
                ? null
                : () async {
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
                                          title: Text(item['name']?.toString() ?? 'Unknown'),
                                          value: tempSelected.contains(item['id'].toString()),
                                          onChanged: (bool? value) {
                                            setState(() {
                                              if (value == true) {
                                                tempSelected.add(item['id'].toString());
                                              } else {
                                                tempSelected.remove(item['id'].toString());
                                              }
                                            });
                                          },
                                          activeColor: const Color.fromRGBO(40, 167, 70, 1),
                                          checkColor: Colors.white,
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, selectedValues),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, tempSelected),
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
                          : items
                              .where((item) =>
                                  selectedValues.contains(item['id'].toString()))
                              .map((item) => item['name']?.toString() ?? 'Unknown')
                              .join(', '),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (items.isEmpty && _isOfflineMode)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'No products available in offline mode. Using cached data.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ManagerActivityProvider>(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Insert Activity${_isOfflineMode ? ' (Offline)' : ''}',
          style: const TextStyle(color: Colors.white),
        ),
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
                  if (_isOfflineMode)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Offline Mode: Using cached data. Activities will be saved as drafts and synced when online.',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  DropdownButtonFormField<String>(
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
                    items: provider.statusOfWorkItems,
                    value: _selectedStatusOfWork,
                    onChanged: provider.isSubmitting
                        ? null
                        : (value) {
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
                    hint: provider.statusOfWorkItems.isEmpty
                        ? const Text('No status available in offline mode')
                        : null,
                  ),
                  if (provider.statusOfWorkItems.isEmpty && _isOfflineMode)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'No Status of Work available. Using cached data.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  if (_isCampEnabled) ...[
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _campNameController,
                      enabled: !provider.isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'Enter Camp Name *',
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
                      items: provider.natureOfWorkItems,
                      value: _selectedNatureOfWork,
                      onChanged: provider.isSubmitting
                          ? null
                          : (value) {
                              setState(() {
                                _selectedNatureOfWork = value;
                                _isCampEnabled = true;
                                _validateForm();
                              });
                            },
                      validator: (value) =>
                          value == null ? 'Please select a nature of work' : null,
                      hint: provider.natureOfWorkItems.isEmpty
                          ? const Text('No nature of work available in offline mode')
                          : null,
                    ),
                    if (provider.natureOfWorkItems.isEmpty && _isOfflineMode)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'No Nature of Work available. Using cached data.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _nameGCACGLController,
                      enabled: !provider.isSubmitting,
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
                        provider.demoProducts,
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
                        enabled: !provider.isSubmitting,
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
                        enabled: !provider.isSubmitting,
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
                        enabled: !provider.isSubmitting,
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
                        items: provider.activityResults,
                        value: _selectedResult,
                        onChanged: provider.isSubmitting
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
                        hint: provider.activityResults.isEmpty
                            ? const Text('No results available in offline mode')
                            : null,
                      ),
                      if (provider.activityResults.isEmpty && _isOfflineMode)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'No Activity Results available. Using cached data.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                    if (!_isCampVisitOrCollection && _selectedResult == '2') ...[
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _orderNoController,
                        enabled: !provider.isSubmitting,
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
                              enabled: !provider.isSubmitting,
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
                              enabled: !provider.isSubmitting,
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
                      enabled: !provider.isSubmitting,
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
                              enabled: !provider.isSubmitting,
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
                            onPressed: provider.isSubmitting ? null : _pickImage,
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
                      items: provider.officeNames.map((String office) {
                        return DropdownMenuItem<String>(
                          value: office,
                          child: Text(office),
                        );
                      }).toList(),
                      onChanged: provider.isSubmitting
                          ? null
                          : (String? value) {
                              setState(() {
                                _selectedOfficeName = value;
                                _validateForm();
                              });
                            },
                      validator: (value) =>
                          value == null ? 'Please select an office name' : null,
                      hint: provider.officeNames.isEmpty
                          ? const Text('No office names available in offline mode')
                          : null,
                    ),
                    if (provider.officeNames.isEmpty && _isOfflineMode)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'No Office Names available. Using cached data.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
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
                      items: provider.officeNatureOfIdItems,
                      value: _selectedOfficeNatureOfId,
                      onChanged: provider.isSubmitting
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
                      hint: provider.officeNatureOfIdItems.isEmpty
                          ? const Text('No office nature of work available in offline mode')
                          : null,
                    ),
                    if (provider.officeNatureOfIdItems.isEmpty && _isOfflineMode)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'No Office Nature of Work available. Using cached data.',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _remarksController,
                      enabled: !provider.isSubmitting,
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
                      enabled: !provider.isSubmitting,
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
                    onPressed: isFormValid && !provider.isLoading && !provider.isSubmitting
                        ? _showConfirmationDialog
                        : null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: isFormValid &&
                              !provider.isLoading &&
                              !provider.isSubmitting
                          ? const Color.fromRGBO(40, 167, 70, 1)
                          : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 90, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                    ),
                    child: _isLocationLoading || provider.isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Text(
                            _isOfflineMode ? 'Save Draft' : 'Submit',
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (provider.isSubmitting)
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

  @override
  void dispose() {
    _debounce?.cancel();
    _orderNoController.removeListener(_debouncedValidateForm);
    _orderUnitController.removeListener(_debouncedValidateForm);
    _bookingAdvanceController.removeListener(_debouncedValidateForm);
    _campNameController.removeListener(_debouncedValidateForm);
    _nameGCACGLController.removeListener(_debouncedValidateForm);
    _customerNameController.removeListener(_debouncedValidateForm);
    _customerAddressController.removeListener(_debouncedValidateForm);
    _customerMobileController.removeListener(_debouncedValidateForm);
    _remarksController.removeListener(_debouncedValidateForm);
    _spotPictureController.removeListener(_debouncedValidateForm);
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
}