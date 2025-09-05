import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:nabeenkishan/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:nabeenkishan/login_page.dart';
class OutAttandancePage extends StatefulWidget {
  const OutAttandancePage({super.key});

  @override
  _OutAttdancePageState createState() => _OutAttdancePageState();
}

class _OutAttdancePageState extends State<OutAttandancePage> {
  File? _image;
  String empId = '';
  String? latitude;
  String? longitude;
  String? shortDesignation;
  String? designationCategory;
  String? outLocation;
  bool _isLoading = false;
  final Map<String, bool> _locationLoadingStates = {};

  Future<void> _loadEmpId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      empId = prefs.getString('emp_id') ?? '';
      shortDesignation = prefs.getString('short_designation') ?? '';
      designationCategory = prefs.getString('DesignationCategory') ?? '';
    });
    print('Saved emp_id: $empId');

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
      if (!serviceEnabled) {
        return;
      }
    }
    loc.PermissionStatus permissionStatus = await location.hasPermission();
    if (permissionStatus == loc.PermissionStatus.denied) {
      permissionStatus = await location.requestPermission();
      if (permissionStatus != loc.PermissionStatus.granted) {
        return;
      }
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
        outLocation = locationName;
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

  Future<void> _submitData() async {
    if (_image == null ||
        latitude == null ||
        longitude == null ||
        empId.isEmpty ||
        outLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please capture image, get location, and location name.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(
      'https://www.nabeenkishan.net.in/newproject/api/routes/AttendanceController/insertOutTimeAttendance.php',
    );

    var request = http.MultipartRequest('POST', url);

    request.fields['emp_id'] = empId;
    request.fields['out_latitude'] = latitude!;
    request.fields['out_longitude'] = longitude!;
    request.fields['out_location'] = outLocation!;

    try {
      List<int> imageBytes = await _image!.readAsBytes();
      http.MultipartFile file = http.MultipartFile.fromBytes(
        'out_picture',
        imageBytes,
        filename: 'image.jpg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(file);
    } catch (e) {
      print('Error reading image file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error with image file.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      var response = await request.send();

      response.stream.transform(utf8.decoder).listen((value) {
        print(value);
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance Submitted Successfully'),
              backgroundColor: Color.fromRGBO(40, 167, 70, 1),
            ),
          );
          // Navigate to LoginPage after successful submission
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit attendance. Error: $value'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error occurred during the request: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEmpId();
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
            colors: [
              primaryColor.withOpacity(0.1),
              Colors.white,
            ],
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
                  const Text(
                    'Out Attendance',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: size.height * 0.01),
                  Text(
                    'Record your departure',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                  Container(
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
                      radius: size.width * 0.23,
                      backgroundImage:
                          _image != null ? FileImage(_image!) : null,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: _image == null
                          ? Icon(
                              Icons.person_rounded,
                              size: size.width * 0.3,
                              color: primaryColor,
                            )
                          : null,
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                  ElevatedButton(
                    onPressed: _captureImage,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.08,
                        vertical: size.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt,
                            size: size.width * 0.05, color: Colors.white),
                        SizedBox(width: size.width * 0.02),
                        Text(
                          'Capture Photo',
                          style: TextStyle(fontSize: size.width * 0.04),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.04,
                      vertical: size.height * 0.015,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: size.width * 0.05,
                          color: primaryColor,
                        ),
                        SizedBox(width: size.width * 0.02),
                        Text(
                          latitude != null && longitude != null
                              ? 'Active'
                              : 'Inactive',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: size.width * 0.035,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitData,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(
                          vertical: size.height * 0.015,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: size.width * 0.04,
                              width: size.width * 0.04,
                              child: const CircularProgressIndicator(
                                color: Color(0xFF28A746),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit',
                              style: TextStyle(
                                fontSize: size.width * 0.04,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Go to Home',
                      style: TextStyle(
                        fontSize: size.width * 0.04,
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
    );
  }
}