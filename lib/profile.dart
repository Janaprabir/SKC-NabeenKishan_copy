import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:nabeenkishan/attandance_report.dart';
import 'package:nabeenkishan/attendance_out_time.dart';
import 'package:nabeenkishan/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? employeeDetails;
  bool isLoading = true;
  int? empId;
  String? currentPassword;

  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _oldPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  static const Color primaryColor = Color.fromRGBO(40, 167, 70, 1);
  static const String apiBaseUrl = 'https://www.nabeenkishan.net.in/';

  @override
  void initState() {
    super.initState();
    getSessionData();
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> getSessionData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? empIdString = prefs.getString('emp_id');
    print('Session emp_id: $empIdString'); // Debug log
    if (empIdString != null) {
      empId = int.tryParse(empIdString);
      if (empId != null) {
        fetchEmployeeDetails(empId!);
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid emp_id in session.')));
      }
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee ID not found in session.')));
    }
  }

  Future<void> fetchEmployeeDetails(int empId) async {
    final url =
        'https://www.nabeenkishan.net.in/newproject/api/routes/EmployeeController/getEmployeeDetails.php?emp_id=$empId';
    try {
      final response = await http.get(Uri.parse(url));
      print('API Response Status: ${response.statusCode}'); // Debug log
      print('API Response Body: ${response.body}'); // Debug log
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Parsed Employee Details: $data'); // Debug log
        setState(() {
          employeeDetails = data;
          currentPassword = data['password'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load employee details: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching employee details: $e'); // Debug log
    }
  }

  Future<void> updateLoginStatus(int empId, String status) async {
    const String updateLoginStatusUrl =
        'https://www.nabeenkishan.net.in/newproject/api/routes/EmployeeController/updateLoginStatus.php';
    try {
      final response = await http.post(
        Uri.parse(updateLoginStatusUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'emp_id': empId.toString(),
          'login_status': status,
        },
      ).timeout(const Duration(seconds: 5));

      print('Update login status response: ${response.statusCode} ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        var statusJson = jsonDecode(response.body);
        if (statusJson['message'] != 'Login status updated successfully.') {
          print('Failed to update login status: ${statusJson['message']}'); // Debug log
        }
      } else {
        print('Update login status API failed: ${response.statusCode}'); // Debug log
      }
    } catch (e) {
      print('Error updating login status: $e'); // Debug log
    }
  }

  Future<void> changePassword(
      String oldPassword, String newPassword, String confirmPassword) async {
    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required.')),
      );
      return;
    }

    if (currentPassword == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to verify current password.')),
      );
      return;
    }
    if (oldPassword != currentPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Old password is incorrect.')),
      );
      return;
    }

    if (oldPassword == newPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('New password cannot be the same as the old password.')),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('New password and confirm password do not match.')),
      );
      return;
    }

    try {
      const url =
          'https://www.nabeenkishan.net.in/newproject/api/routes/EmployeeController/changePassword.php';
      final response = await http.post(
        Uri.parse(url),
        body: {
          'emp_id': empId.toString(),
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
      if (response.statusCode == 200) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.remove('emp_id');
        if (empId != null) {
          await updateLoginStatus(empId!, '0'); // Update login status to 0
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
          (Route<dynamic> route) => false,
        );
      } else {
        throw Exception('Failed to change password: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      print('Error changing password: $e'); // Debug log
    }
  }

  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.redAccent),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                SharedPreferences prefs = await SharedPreferences.getInstance();
                if (empId != null) {
                  await updateLoginStatus(empId!, '0'); // Update login status to 0
                }
                await prefs.clear();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Construct the profile picture URL using only profile_picture_path
    String? profilePictureUrl;
    if (employeeDetails != null) {
      String? path = employeeDetails!['profile_picture_path'];
      print('Profile Picture Path: $path'); // Debug log
      if (path != null && path.trim().isNotEmpty) {
        if (path.startsWith('http')) {
          profilePictureUrl = path;
        } else {
          // Adjust relative path to stay within /software/Nabeen Kishan/
          String adjustedPath = path.replaceFirst('../../../', '');
          profilePictureUrl = Uri.parse(apiBaseUrl).resolve(adjustedPath).toString();
        }
      }
    }
    print('Profile Picture URL: $profilePictureUrl'); // Debug log

    // Test the image URL
    if (profilePictureUrl != null) {
      http.get(Uri.parse(profilePictureUrl)).then((response) {
        print('Image URL Response Status: ${response.statusCode}'); // Debug log
      }).catchError((e) {
        print('Error testing image URL: $e'); // Debug log
      });
    }

    return Scaffold(
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28A746)))
          : empId == null
              ? const Center(child: Text('No employee ID found in session'))
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: screenHeight * 0.25,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF28A746), Colors.teal],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: screenHeight * 0.02),
                              CircleAvatar(
                                radius: screenWidth * 0.13,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                backgroundImage: profilePictureUrl != null
                                    ? NetworkImage(profilePictureUrl)
                                    : null,
                                child: profilePictureUrl == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 80,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              SizedBox(height: screenHeight * 0.02),
                              Text(
                                employeeDetails != null
                                    ? '${employeeDetails!['first_name']} ${employeeDetails!['middle_name']} ${employeeDetails!['last_name']}'
                                    : 'N/A',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.06,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                employeeDetails != null
                                    ? '${employeeDetails!['designation']} • ${employeeDetails!['e_code']}'
                                    : 'N/A',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pinned: true,
                      backgroundColor: Colors.green,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(screenWidth * 0.05),
                        child: Column(
                          children: [
                            _buildAccordion('Basic Details', screenWidth),
                            _buildAccordion('Change Password', screenWidth),
                            _buildButton(
                              'Attendance Report',
                              primaryColor.withOpacity(0.1),
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AttendancePage()),
                              ),
                            ),
                            _buildButton(
                              'Logout',
                              Colors.redAccent.withOpacity(0.1),
                              _showLogoutConfirmationDialog,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAccordion(String title, double screenWidth) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.all(16),
        children: title == 'Change Password'
            ? [
                TextField(
                  controller: _oldPasswordController,
                  obscureText: !_oldPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Old Password',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _oldPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _oldPasswordVisible = !_oldPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPasswordController,
                  obscureText: !_newPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _newPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _newPasswordVisible = !_newPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_confirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _confirmPasswordVisible = !_confirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => changePassword(
                    _oldPasswordController.text,
                    _newPasswordController.text,
                    _confirmPasswordController.text,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.18,
                        vertical: screenWidth * 0.04),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Submit',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ]
            : employeeDetails == null
                ? [const Text('No details available')]
                : [
                    _buildDetailTile(
                      icon: Icons.person,
                      label: 'Name',
                      value:
                          '${employeeDetails!['first_name']} ${employeeDetails!['middle_name']} ${employeeDetails!['last_name']}',
                    ),
                    _buildDetailTile(
                      icon: Icons.phone,
                      label: 'Mobile No',
                      value: employeeDetails!['mobile_no'],
                    ),
                    _buildDetailTile(
                      icon: Icons.email,
                      label: 'Email',
                      value: employeeDetails!['email_id'],
                    ),
                    _buildDetailTile(
                      icon: Icons.home,
                      label: 'Address',
                      value: employeeDetails!['address'] ?? 'N/A',
                    ),
                    _buildDetailTile(
                      icon: Icons.local_police,
                      label: 'Police Station',
                      value: employeeDetails!['police_station'] ?? 'N/A',
                    ),
                    _buildDetailTile(
                      icon: Icons.pin_drop,
                      label: 'Pin Code',
                      value: employeeDetails!['pin_code'] ?? 'N/A',
                    ),
                    _buildDetailTile(
                      icon: Icons.image,
                      label: 'Profile Picture',
                      value: employeeDetails!['profile_picture'] ?? 'N/A',
                    ),
                    _buildDetailTile(
                      icon: Icons.location_city,
                      label: 'District',
                      value: employeeDetails!['district'] ?? 'N/A',
                    ),
                    _buildDetailTile(
                      icon: Icons.map,
                      label: 'State',
                      value: employeeDetails!['state_name'] ?? 'N/A',
                    ),
                  ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.isNotEmpty ? value : 'N/A',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, Color? color, VoidCallback onPressed) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(
          text == 'Logout'
              ? Icons.logout
              : text == 'Attendance Report'
                  ? Icons.bar_chart
                  : Icons.access_time,
          color: text == 'Logout' ? Colors.redAccent : primaryColor,
        ),
        onTap: onPressed,
        tileColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}