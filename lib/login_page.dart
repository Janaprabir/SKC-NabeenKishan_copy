import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Add this import
import 'navigation.dart';

// Custom TextInputFormatter to block paste actions
class NoPasteFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > oldValue.text.length + 1) {
      return oldValue;
    }
    return newValue;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController empIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  Timer? sessionTimer;
  bool isLoading = false;
  String errorMessage = '';
  bool isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
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
                        SystemNavigator.pop(); // Close the app
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
                        loginUser(); // Retry login
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

  Future<void> loginUser() async {
  setState(() {
    isLoading = true;
    errorMessage = '';
  });

  // Check network connectivity
  final isConnected = await _checkNetworkConnectivity();
  if (!isConnected) {
    setState(() {
      isLoading = false;
      errorMessage = 'No internet connection. Please check your network.';
    });
    _showNetworkErrorDialog();
    return;
  }

  String employeeId = empIdController.text;
  String userPassword = passwordController.text;

  if (employeeId.isEmpty || userPassword.isEmpty) {
    setState(() {
      isLoading = false;
      errorMessage = 'Please enter Employee ID and Password';
    });
    return;
  }

  final String loginApiUrl =
      'https://www.nabeenkishan.net.in/newproject/api/routes/EmployeeController/handleLogin.php';

  try {
    final response = await http.post(
      Uri.parse(loginApiUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'e_code': employeeId, 'password': userPassword},
    ).timeout(const Duration(seconds: 15));

    debugPrint('Login response: ${response.statusCode} ${response.body}');

    if (response.statusCode == 200) {
      try {
        var responseJson = jsonDecode(response.body);
        var userData = responseJson['user_data'];
        var shortDesignation = responseJson['short_designation'];
        var designationCategory = responseJson['designation_category'];
        var godownId = responseJson['godown_id'];
        var godownName = responseJson['godown_name'];

        if (userData != null) {
          var employeeId = userData['emp_id'];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('emp_id', employeeId);
          await prefs.setString('short_designation', shortDesignation);
          await prefs.setString('designation_category', designationCategory);
          if (shortDesignation == 'GK' && godownId != '') {
            try {
              int parsedGodownId = int.parse(godownId);
              await prefs.setInt('godown_id', parsedGodownId);
              await prefs.setString('godown_name', godownName);
            } catch (e) {
              debugPrint('Godown ID parse error: $e');
            }
          }
 // Call the update login status API
            final String updateLoginStatusUrl =
                'https://www.nabeenkishan.net.in/newproject/api/routes/EmployeeController/updateLoginStatus.php';
            try {
              final statusResponse = await http.post(
                Uri.parse(updateLoginStatusUrl),
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                body: {
                  'emp_id': employeeId,
                  'login_status': '1',
                },
              );

              debugPrint(
                  'Update login status response: ${statusResponse.statusCode} ${statusResponse.body}');

              if (statusResponse.statusCode == 200) {
                var statusJson = jsonDecode(statusResponse.body);
                if (statusJson['message'] !=
                    'Login status updated successfully.') {
                  debugPrint(
                      'Failed to update login status: ${statusJson['message']}');
                }
              } else {
                debugPrint(
                    'Update login status API failed: ${statusResponse.statusCode}');
              }
            } catch (e) {
              debugPrint('Error updating login status: $e');
            }
          bool isAttendanceSubmitted = await checkAttendanceStatus(employeeId);
          if (isAttendanceSubmitted) {
            String? designationCategory = prefs.getString('designation_category');
            HomeScreenNavigator.navigateToScreen(context, designationCategory!);
          } else {
            if (['MANAGER'].contains(designationCategory)) {
              Navigator.pushReplacementNamed(context, 'managerAttandance');
            } else {
              Navigator.pushReplacementNamed(context, 'attandance');
            }
          }
        } else {
          setState(() {
            errorMessage = 'Wrong Employee ID or Password';
          });
        }
      } catch (e) {
        setState(() {
          errorMessage = 'Invalid server response. Please try again.';
        });
        debugPrint('JSON parse error: $e');
      }
    } else {
      setState(() {
        errorMessage ='Invalid e_code or password.';
       print('Server error: ${response.statusCode}');
      });
    }
  } on TimeoutException catch (e) {
    setState(() {
      print('Request timed out. Please try again.');
    });
    debugPrint('Timeout error: $e');
  } on http.ClientException catch (e) {
    setState(() {
     errorMessage ='Network error. Please check your connection.';
    });
    debugPrint('HTTP client error: $e');
  } catch (e) {
    setState(() {
      print('Unexpected error occurred.');
    });
    debugPrint('Unexpected error: $e');
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

  // Check if the user has already submitted attendance for today
  Future<bool> checkAttendanceStatus(String employeeId) async {
    final String attendanceApiUrl =
        'https://www.nabeenkishan.net.in/newproject/api/routes/AttendanceController/checkAttendanceForToday.php?emp_id=$employeeId';

    try {
      final response = await http.get(
        Uri.parse(attendanceApiUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('Error checking attendance: $e');
    }

    return false;
  }

  void logoutUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('emp_id');
    SystemNavigator.pop();
  }

  Future<bool> isUserLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('emp_id');
  }

  Future<void> checkLoginStatus() async {
    bool loggedIn = await isUserLoggedIn();
    if (loggedIn) {
      await checkAttendanceStatus('');
    }
  }

  @override
  void dispose() {
    sessionTimer?.cancel();
    empIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    const primaryColor = Color.fromRGBO(40, 167, 70, 1);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: screenHeight * 0.02),
                    // Logo
                    Image.asset(
                      'assets/favicon.png',
                      height: screenHeight * 0.3,
                      width: screenWidth * 0.6,
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    // Employee ID Field
                    Container(
                      width: screenWidth * 0.85,
                      child: TextField(
                        controller: empIdController,
                        decoration: InputDecoration(
                          labelText: 'Employee ID',
                          labelStyle: TextStyle(color: Colors.grey[800]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: primaryColor, width: 2),
                          ),
                          prefixIcon:
                              Icon(Icons.person, color: Colors.grey[800]),
                        ),
                        enableInteractiveSelection:
                            false, // Disables selection and toolbar
                        contextMenuBuilder: (context, state) =>
                            const SizedBox(), // Disables context menu
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(
                              RegExp(r'\s')), // Prevents spaces
                          NoPasteFormatter(), // Blocks paste actions
                        ],
                        onChanged: (value) {
                          // Ensure no spaces are present
                          if (value.contains(' ')) {
                            empIdController.text = value.replaceAll(' ', '');
                            empIdController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: empIdController.text.length),
                            );
                          }
                        },
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    // Password Field
                    Container(
                      width: screenWidth * 0.85,
                      child: TextField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.grey[800]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: primaryColor, width: 2),
                          ),
                          prefixIcon: Icon(Icons.lock, color: Colors.grey[800]),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey[800],
                            ),
                            onPressed: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        enableInteractiveSelection:
                            false, // Disables selection and toolbar
                        contextMenuBuilder: (context, state) =>
                            const SizedBox(), // Disables context menu
                        inputFormatters: [
                          NoPasteFormatter(), // Blocks paste actions
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
                    // Error Message
                    if (errorMessage.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: screenHeight * 0.01),
                        child: Text(
                          errorMessage,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    SizedBox(height: screenHeight * 0.02),
                    // Login Button
                    SizedBox(
                      width: screenWidth * 0.85,
                      child: isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                loginUser();
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: primaryColor,
                                padding: EdgeInsets.symmetric(
                                  vertical: screenHeight * 0.015,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.045,
                                  fontWeight: FontWeight.w600,
                                ),
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
}
