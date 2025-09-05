import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:nabeenkishan/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

class AttandancePage extends StatefulWidget {
  const AttandancePage({super.key});

  @override
  _AttdancePageState createState() => _AttdancePageState();
}

class _AttdancePageState extends State<AttandancePage> {
  File? _image;
  String empId = '';
  String? latitude;
  String? longitude;
  String? shortDesignation;
  String? designationCategory;
  String? inLocation;
  bool _isLoading = false;
  bool _isInTimeActive = true; // Controls Submit button state
  DateTime? _lastSubmitted;
  final Map<String, bool> _locationLoadingStates = {};

  Future<void> _loadEmpId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      empId = prefs.getString('emp_id') ?? '';
      shortDesignation = prefs.getString('short_designation') ?? '';
      designationCategory = prefs.getString('designation_category') ?? '';
    });
  }

  Future<void> _checkAttendanceStatus() async {
    if (empId.isEmpty) {
      debugPrint('Error: Employee ID not found');
      return;
    }

    try {
      final currentDate = DateTime.now().toString().split(' ')[0];
      final url = Uri.parse(
          'https://www.nabeenkishan.net.in/newproject/api/routes/AttendanceController/attendanceReport.php'
          '?emp_id=$empId&from_date=$currentDate&to_date=$currentDate');

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      debugPrint('Attendance Check Status: ${response.statusCode}');
      debugPrint('Attendance Check Response: ${response.body}');

      final jsonResponse = json.decode(response.body);

      setState(() {
        if (jsonResponse['message'].contains('successfully')) {
          final attendanceData = jsonResponse['data'][0];
          if (attendanceData['in_time'] != '00:00:00' && attendanceData['in_time'] != '') {
            _isInTimeActive = false; // Disable in-time if already submitted
          } else {
            _isInTimeActive = true;
          }
        } else {
          _isInTimeActive = true; // No attendance data, allow in-time
        }
      });
    } catch (e) {
      debugPrint('Error checking attendance: $e');
      setState(() {
        _isInTimeActive = true; // Default to allowing in-time on error
      });
    }
  }

  Future<void> _captureImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );
    setState(() {
      _image = image != null ? File(image.path) : null;
    });
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

  Future<String?> _getLocationName(double latitude, double longitude, String activityId) async {
    setState(() => _locationLoadingStates[activityId] = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        List<String> locationParts = [
          if (placemark.street?.isNotEmpty == true) placemark.street!,
          if (placemark.subLocality?.isNotEmpty == true) placemark.subLocality!,
          if (placemark.locality?.isNotEmpty == true) placemark.locality!,
          if (placemark.postalCode?.isNotEmpty == true) placemark.postalCode!,
          if (placemark.administrativeArea?.isNotEmpty == true) placemark.administrativeArea!,
          if (placemark.country?.isNotEmpty == true) placemark.country!,
        ];
        String locationName = locationParts.join(', ');
        return locationName.isNotEmpty ? locationName : 'Unknown Location';
      }
      return 'No Location Found';
    } catch (e) {
      return 'Error: $e';
    } finally {
      setState(() => _locationLoadingStates[activityId] = false);
    }
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  child: const Icon(Icons.wifi_off, color: Colors.red, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('Network Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                const Text(
                  'No internet connection or slow network detected.\nPlease check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 2,
                      ),
                      onPressed: () => SystemNavigator.pop(),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28A746),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 2,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _submitData();
                      },
                      child: const Text('Retry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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

  Future<void> _submitData() async {
    if (_lastSubmitted != null &&
        DateTime.now().difference(_lastSubmitted!).inMilliseconds < 500) {
      debugPrint('Submission ignored due to debouncing');
      return;
    }

    if (_isLoading) return;

    if (_image == null || latitude == null || longitude == null || empId.isEmpty || inLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture image, get location, and location name.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _lastSubmitted = DateTime.now();
    });

    final isConnected = await _checkNetworkConnectivity();
    if (!isConnected) {
      setState(() => _isLoading = false);
      _showNetworkErrorDialog();
      return;
    }

    final url = Uri.parse(
      'https://www.nabeenkishan.net.in/newproject/api/routes/AttendanceController/insertInTimeAttendance.php',
    );

    final client = http.Client();
    var request = http.MultipartRequest('POST', url);
    final requestId = Uuid().v4();

    request.fields['request_id'] = requestId;
    request.fields['emp_id'] = empId;
    request.fields['in_latitude'] = latitude!;
    request.fields['in_longitude'] = longitude!;
    request.fields['in_location'] = inLocation!;

    try {
      List<int> imageBytes = await _image!.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'in_picture',
        imageBytes,
        filename: 'image.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error with image file.')),
      );
      setState(() => _isLoading = false);
      client.close();
      return;
    }

    try {
      var response = await client.send(request).timeout(const Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        setState(() {
          _isInTimeActive = false; // Disable Submit button after success
          _image = null;
          latitude = null;
          longitude = null;
          inLocation = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('In-Time Submitted Successfully'),
            backgroundColor: Color.fromRGBO(40, 167, 70, 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit attendance. Error: $responseBody'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      _showNetworkErrorDialog();
    } finally {
      client.close();
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEmpId().then((_) => _checkAttendanceStatus()); // Check status after loading empId
    _getLocation();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const primaryColor = Color.fromRGBO(40, 167, 70, 1);

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(size.width * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.04),
                  const Text('Attendance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
                  SizedBox(height: size.height * 0.01),
                  Text('Record your in-time presence', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                  SizedBox(height: size.height * 0.04),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withOpacity(0.2), width: 4),
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
                      radius: size.width * 0.23,
                      backgroundImage: _image != null ? FileImage(_image!) : null,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: _image == null
                          ? Icon(Icons.person_rounded, size: size.width * 0.3, color: primaryColor)
                          : null,
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                  ElevatedButton(
                    onPressed: _isInTimeActive ? _captureImage : null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(horizontal: size.width * 0.08, vertical: size.height * 0.015),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      disabledBackgroundColor: primaryColor.withOpacity(0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt, size: size.width * 0.05, color: Colors.white),
                        SizedBox(width: size.width * 0.02),
                        Text('Capture Photo', style: TextStyle(fontSize: size.width * 0.04)),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: size.height * 0.015),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: size.width * 0.05, color: primaryColor),
                        SizedBox(width: size.width * 0.02),
                        Text(
                          latitude != null && longitude != null ? 'Active' : 'Inactive',
                          style: TextStyle(color: primaryColor, fontSize: size.width * 0.035),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isInTimeActive && !_isLoading ? _submitData : null,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: size.height * 0.015),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        disabledBackgroundColor: primaryColor.withOpacity(0.5),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: size.width * 0.04,
                              width: size.width * 0.04,
                              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Submit In-Time',
                              style: TextStyle(fontSize: size.width * 0.04, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),
                  TextButton(
                    onPressed: () {
                      if (designationCategory != null) {
                        HomeScreenNavigator.navigateToScreen(
                            context, designationCategory!);
                      }
                    },
                    child: Text(
                      'Go to Home',
                      style: TextStyle(fontSize: size.width * 0.04, color: primaryColor, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}