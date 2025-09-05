import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as loc;
import 'package:nabeenkishan/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class ManagerAttendancePage extends StatefulWidget {
  const ManagerAttendancePage({super.key});

  @override
  _ManagerAttendancePageState createState() => _ManagerAttendancePageState();
}

class _ManagerAttendancePageState extends State<ManagerAttendancePage> {
  File? _image;
  String empId = '';
  String? latitude;
  String? longitude;
  String? shortDesignation;
  String? designationCategory;
  String statusOfWork = 'camp';
  String? inLocation;
  int? selectedCampNatureWorkId;
  int? selectedOfficeId;
  final TextEditingController campNameController = TextEditingController();
  final TextEditingController remarksController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  DateTime? _lastSubmitted; // For debouncing
  final Map<String, bool> _locationLoadingStates = {};
  List<Map<String, dynamic>> campNatureWorkList = [];
  List<Map<String, dynamic>> officeList = [];

  @override
  void initState() {
    super.initState();
    _loadEmpId();
    _getLocation();
    _fetchCampNatureWork();
    _fetchOfficeNames();
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

  void _showNetworkErrorDialog() {
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
                const Text(
                  'No internet connection or slow network detected.\nPlease check your connection and try again.',
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
                        SystemNavigator.pop();
                      },
                      child: const Text(
                        'Cancel',
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
                        Navigator.of(context).pop();
                        _fetchCampNatureWork();
                        _fetchOfficeNames();
                        if (_isLoading) _submitData();
                      },
                      child: const Text(
                        'Retry',
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

  Future<void> _loadEmpId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      empId = prefs.getString('emp_id') ?? '';
      shortDesignation = prefs.getString('short_designation') ?? '';
      designationCategory = prefs.getString('designation_category') ?? '';
    });
  }

  Future<void> _fetchCampNatureWork() async {
    final isConnected = await _checkNetworkConnectivity();
    if (!isConnected) {
      _showNetworkErrorDialog();
      return;
    }

    final url = Uri.parse(
      'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=manager_camp_work_master',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          campNatureWorkList = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      } else {
        debugPrint('Failed to fetch camp nature work: ${response.statusCode}');
        _showNetworkErrorDialog();
      }
    } catch (e) {
      debugPrint('Error fetching camp nature work: $e');
      _showNetworkErrorDialog();
    }
  }

  Future<void> _fetchOfficeNames() async {
    final isConnected = await _checkNetworkConnectivity();
    if (!isConnected) {
      _showNetworkErrorDialog();
      return;
    }

    final url = Uri.parse(
      'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllBranch',
    );
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          officeList = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      } else {
        debugPrint('Failed to fetch office names: ${response.statusCode}');
        _showNetworkErrorDialog();
      }
    } catch (e) {
      debugPrint('Error fetching office names: $e');
      _showNetworkErrorDialog();
    }
  }

  Future<void> _getLocation() async {
    loc.Location location = loc.Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    loc.PermissionStatus permissionStatus = await location.hasPermission();
    if (permissionStatus == loc.PermissionStatus.denied) {
      permissionStatus = await location.requestPermission();
      if (permissionStatus != loc.PermissionStatus.granted) return;
    }

    loc.LocationData locationData = await location.getLocation();
    setState(() {
      latitude = locationData.latitude.toString();
      longitude = locationData.longitude.toString();
    });

    if (latitude != null && longitude != null) {
      String? locationName = await _getLocationName(
        double.parse(latitude!),
        double.parse(longitude!),
        empId,
      );
      setState(() {
        inLocation = locationName;
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

  Future<void> _captureImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    setState(() {
      _image = image != null ? File(image.path) : null;
    });
  }

  Future<void> _submitData() async {
  // Debouncing: Ignore clicks within 500ms of the last submission
  final now = DateTime.now();
  if (_lastSubmitted != null &&
      now.difference(_lastSubmitted!).inMilliseconds < 500) {
    debugPrint('Submission ignored due to debouncing');
    return;
  }

  if (_isLoading) {
    debugPrint('Submission ignored: already in progress');
    return;
  }

  if (!_formKey.currentState!.validate()) {
    debugPrint('Form validation failed');
    return;
  }

  // Additional validation for camp-specific fields
  if (statusOfWork == 'camp' && selectedCampNatureWorkId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select camp nature of work.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (_image == null ||
      latitude == null ||
      longitude == null ||
      empId.isEmpty ||
      inLocation == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please capture image, get location, and location name.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() {
    _isLoading = true;
    _lastSubmitted = now; // Record submission time
  });

  final isConnected = await _checkNetworkConnectivity();
  if (!isConnected) {
    setState(() {
      _isLoading = false;
    });
    _showNetworkErrorDialog();
    return;
  }

  final url = Uri.parse(
    'https://www.skcinfotech.net.in/nabeenkishan/api/routes/AttendanceController/insertInTimeAttendance.php',
  );

  final client = http.Client();
  var request = http.MultipartRequest('POST', url);

  // Add unique request ID to prevent duplicates
  final requestId = Uuid().v4();
  request.fields['request_id'] = requestId;
  request.fields['emp_id'] = empId;
  request.fields['in_latitude'] = latitude!;
  request.fields['in_longitude'] = longitude!;
  request.fields['in_location'] = inLocation!;
  request.fields['status_of_work_camp'] = (statusOfWork == 'camp') ? '1' : '0';
  request.fields['status_of_work_office'] = (statusOfWork == 'office') ? '1' : '0';
  request.fields['status_of_work_leave'] = (statusOfWork == 'leave') ? '1' : '0';
  request.fields['camp_name'] = statusOfWork == 'camp' ? campNameController.text : '';
  if (statusOfWork == 'camp' && selectedCampNatureWorkId != null) {
    request.fields['manager_camp_work_id'] = selectedCampNatureWorkId.toString();
  }
  if (statusOfWork == 'office' && selectedOfficeId != null) {
    request.fields['branch_id'] = selectedOfficeId.toString();
  }
  request.fields['remarks'] = remarksController.text;

  try {
    List<int> imageBytes = await _image!.readAsBytes();
    http.MultipartFile file = http.MultipartFile.fromBytes(
      'in_picture',
      imageBytes,
      filename: 'image.jpg',
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(file);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error with image file.')),
    );
    setState(() {
      _isLoading = false;
    });
    client.close();
    return;
  }

  try {
    debugPrint('Submitting attendance with request_id: $requestId');
    debugPrint('Request fields: ${request.fields}');
    var response = await client.send(request).timeout(const Duration(seconds: 10));
    String responseBody = await response.stream.bytesToString();
    debugPrint('Response: $responseBody');
    if (response.statusCode == 201) {
      // Clear form data to prevent resubmission
      setState(() {
        _image = null;
        latitude = null;
        longitude = null;
        inLocation = null;
        statusOfWork = 'camp';
        campNameController.clear();
        remarksController.clear();
        selectedCampNatureWorkId = null;
        selectedOfficeId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance Submitted Successfully'),
          backgroundColor: Color.fromRGBO(40, 167, 70, 1),
        ),
      );
      HomeScreenNavigator.navigateToScreen(context, designationCategory!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit attendance. Error: $responseBody'),
          backgroundColor: Colors.redAccent,
        ),
      );
      debugPrint('Failed to submit attendance: $responseBody');
    }
  } catch (e) {
    debugPrint('Error submitting attendance: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to submit attendance.')),
    );
    _showNetworkErrorDialog();
  } finally {
    client.close();
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    const primaryColor = Color.fromRGBO(40, 167, 70, 1);

    return Scaffold(
      body: Container(
        width: screenWidth,
        height: screenHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(screenWidth * 0.06),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: screenHeight * 0.04),
                    const Text(
                      'Manager Attendance',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      'Record your work status',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),

                    // Image Container
                    GestureDetector(
                      onTap: _captureImage,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: screenWidth * 0.23,
                          backgroundImage:
                              _image != null ? FileImage(_image!) : null,
                          backgroundColor: primaryColor.withOpacity(0.1),
                          child: _image == null
                              ? Icon(
                                  Icons.camera_alt,
                                  size: screenWidth * 0.15,
                                  color: primaryColor,
                                )
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),

                    // Form Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(screenWidth * 0.05),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status of Work',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.015),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildRadioButton('Camp', 'camp'),
                              _buildRadioButton('Office', 'office'),
                              _buildRadioButton('Leave', 'leave'),
                            ],
                          ),
                          SizedBox(height: screenHeight * 0.025),

                          // Camp Name Field (Visible for Camp)
                          if (statusOfWork == 'camp') ...[
                            TextFormField(
                              controller: campNameController,
                              decoration: InputDecoration(
                                labelText: 'Camp Name',
                                labelStyle: const TextStyle(color: primaryColor),
                                hintText: 'Enter Camp Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: primaryColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: primaryColor.withOpacity(0.5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: primaryColor, width: 2),
                                ),
                                prefixIcon: const Icon(Icons.location_city,
                                    color: primaryColor),
                              ),
                              validator: (value) {
                                if (statusOfWork == 'camp' &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Camp Name is required';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: screenHeight * 0.02),
                          ],

                          // Camp Nature of Work Dropdown (Visible for Camp)
                          if (statusOfWork == 'camp') ...[
                            DropdownButtonFormField<int>(
                              value: selectedCampNatureWorkId,
                              decoration: InputDecoration(
                                labelText: 'Camp Nature of Work',
                                labelStyle: const TextStyle(color: primaryColor),
                                hintText: 'Select Camp Nature of Work',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: primaryColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: primaryColor.withOpacity(0.5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: primaryColor, width: 2),
                                ),
                                prefixIcon: const Icon(Icons.work,
                                    color: primaryColor),
                              ),
                              items: campNatureWorkList
                                  .map((camp) => DropdownMenuItem<int>(
                                        value: camp['manager_camp_work_id'],
                                        child: Text(camp['manager_camp_work_name']),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedCampNatureWorkId = value;
                                });
                              },
                              validator: (value) {
                                if (statusOfWork == 'camp' && value == null) {
                                  return 'Please select camp nature of work';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: screenHeight * 0.02),
                          ],

                          // Office Name Dropdown (Visible for Office)
                          if (statusOfWork == 'office') ...[
                            DropdownButtonFormField<int>(
                              value: selectedOfficeId,
                              decoration: InputDecoration(
                                labelText: 'Office Name',
                                labelStyle: const TextStyle(color: primaryColor),
                                hintText: 'Select Office Name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: primaryColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: primaryColor.withOpacity(0.5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: primaryColor, width: 2),
                                ),
                                prefixIcon: const Icon(Icons.business,
                                    color: primaryColor),
                              ),
                              items: officeList
                                  .map((office) => DropdownMenuItem<int>(
                                        value: office['branch_id'],
                                        child: Text(office['branch_name']),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedOfficeId = value;
                                });
                              },
                              validator: (value) {
                                if (statusOfWork == 'office' && value == null) {
                                  return 'Please select office name';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: screenHeight * 0.02),
                          ],

                          // Remarks Field
                          if (statusOfWork == 'camp' ||
                              statusOfWork == 'office' ||
                              statusOfWork == 'leave') ...[
                            TextFormField(
                              controller: remarksController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Remarks',
                                labelStyle: const TextStyle(color: primaryColor),
                                hintText: 'Enter Remarks',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      const BorderSide(color: primaryColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: primaryColor.withOpacity(0.5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: primaryColor, width: 2),
                                ),
                                prefixIcon:
                                    const Icon(Icons.note, color: primaryColor),
                              ),
                              validator: (value) {
                                if ((statusOfWork == 'office' ||
                                        statusOfWork == 'leave') &&
                                    (value == null || value.trim().isEmpty)) {
                                  return 'Remarks is required';
                                }
                                return null;
                              },
                            ),
                          ],

                          SizedBox(height: screenHeight * 0.03),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitData, // Disable button when loading
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: primaryColor,
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.013,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                disabledBackgroundColor: primaryColor.withOpacity(0.5), // Visual feedback for disabled state
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Submit Attendance',
                                      style: TextStyle(
                                        fontSize: screenWidth * 0.036,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    TextButton(
                      onPressed: () {
                        if (designationCategory != null) {
                          HomeScreenNavigator.navigateToScreen(
                              context, designationCategory!);
                        }
                      },
                      child: Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRadioButton(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio(
          value: value,
          groupValue: statusOfWork,
          onChanged: (val) => setState(() {
            statusOfWork = val!;
            // Clear fields when status changes
            campNameController.clear();
            remarksController.clear();
            selectedCampNatureWorkId = null;
            selectedOfficeId = null;
          }),
          activeColor: const Color.fromRGBO(40, 167, 70, 1),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color.fromRGBO(40, 167, 70, 1),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}