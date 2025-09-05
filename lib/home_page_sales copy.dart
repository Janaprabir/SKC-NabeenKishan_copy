import 'package:flutter/material.dart';
import 'package:nabeenkishan/attandance.dart';
import 'package:nabeenkishan/attendance_out_time.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

class HomePageSales extends StatefulWidget {
  const HomePageSales({super.key});

  @override
  State<HomePageSales> createState() => _HomePageState();
}

class _HomePageState extends State<HomePageSales> {
  String? _designation;
  String? _empId;
  bool _isInTimeActive = false;
  bool _isOutTimeActive = false;
  bool _isDailyActivityActive = false;
  bool _isLoading = true;
  bool _isNetworkConnected = true;
  bool _isOfflineMode = false; // Track explicit offline mode
  String? _profileImageUrl;
  bool _hasCheckedAttendance = false;
  bool _showExtraButtons = false;

  @override
  void initState() {
    super.initState();
    _loadData(checkAttendance: true);
    _listenForConnectivityChanges();
  }

  void _listenForConnectivityChanges() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final isConnected = results.any((result) => result != ConnectivityResult.none);
      if (isConnected && _isOfflineMode) {
        setState(() => _isNetworkConnected = true);
        _showOnlineModeDialog();
      }
    });
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
                          _isDailyActivityActive = true;
                        });
                        Navigator.of(context).pop();
                        _loadData(checkAttendance: true);
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

  void _showNetworkErrorDialog() {
    if (_isOfflineMode) return; // Don't show dialog in offline mode
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
                  'No internet connection or slow network detected.\nPlease check your connection and try again or use offline mode.',
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
                        _loadData(checkAttendance: false);
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
                          _isDailyActivityActive = true;
                          _isInTimeActive = false;
                          _isOutTimeActive = false;
                        });
                        Navigator.of(context).pop();
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

  Future<void> _loadData({required bool checkAttendance}) async {
    if (_isOfflineMode) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    final isConnected = await _checkNetworkConnectivity();
    setState(() => _isNetworkConnected = isConnected);

    if (!isConnected) {
      setState(() => _isLoading = false);
      _showNetworkErrorDialog();
      return;
    }

    try {
      await _loadDesignation();
      await _loadEmpId();
      if (_empId != null) {
        await Future.wait([
          if (checkAttendance && !_hasCheckedAttendance) _checkAttendanceStatus(),
          _fetchProfilePicture(),
          _checkSubordinateTree(),
        ]);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      _showNetworkErrorDialog();
    } finally {
      setState(() {
        _isLoading = false;
        if (checkAttendance) _hasCheckedAttendance = true;
      });
    }
  }

  Future<void> _loadDesignation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _designation = prefs.getString('short_designation') ?? '';
    });
  }

  Future<void> _loadEmpId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empId = prefs.getString('emp_id');
    });
  }

  Future<void> _fetchProfilePicture() async {
    if (_isOfflineMode || _empId == null) return;

    try {
      final url = Uri.parse(
          'https://www.nabeenkishan.net.in/newproject/api/routes/EmployeeController/getEmployeeDetails.php?emp_id=$_empId');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final profilePicturePath = jsonResponse['profile_picture_path'] ?? '';
        if (profilePicturePath.isNotEmpty) {
          final cleanedPath = profilePicturePath.replaceFirst('../../../', '');
          setState(() {
            _profileImageUrl = 'https://www.nabeenkishan.net.in/$cleanedPath';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile picture: $e');
      throw Exception('Failed to fetch profile picture');
    }
  }

  Future<void> _checkSubordinateTree() async {
    if (_isOfflineMode || _empId == null) {
      debugPrint('Error: Employee ID not found or in offline mode');
      setState(() => _showExtraButtons = false);
      return;
    }

    try {
      final url = Uri.parse(
          'https://www.nabeenkishan.net.in/newproject/api/routes/SubordinateTreeController/getSubordinateTree.php?emp_id=$_empId');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          _showExtraButtons = !(jsonResponse['message'] ==
              'No subordinates found for the given manager ID.');
        });
      } else {
        setState(() => _showExtraButtons = false);
      }
    } catch (e) {
      debugPrint('Error checking subordinate tree: $e');
      setState(() => _showExtraButtons = false);
    }
  }

  Future<void> _checkAttendanceStatus() async {
    if (_isOfflineMode || _empId == null) {
      debugPrint('Error: Employee ID not found or in offline mode');
      return;
    }

    try {
      final currentDate = DateTime.now().toString().split(' ')[0];
      final url = Uri.parse(
          'https://www.nabeenkishan.net.in/newproject/api/routes/AttendanceController/attendanceReport.php'
          '?emp_id=$_empId&from_date=$currentDate&to_date=$currentDate');

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      debugPrint('Attendance Check Status: ${response.statusCode}');
      debugPrint('Attendance Check Response: ${response.body}');

      final jsonResponse = json.decode(response.body);

      setState(() {
        if (jsonResponse['message'].contains('successfully')) {
          final attendanceData = jsonResponse['data'][0];
          if (attendanceData['out_time'] == '00:00:00' ||
              attendanceData['out_time'] == '') {
            _isInTimeActive = false;
            _isOutTimeActive = true;
            _isDailyActivityActive = true;
          } else {
            _isInTimeActive = false;
            _isOutTimeActive = false;
            _isDailyActivityActive = false;
          }
        } else {
          _isInTimeActive = true;
          _isOutTimeActive = false;
          _isDailyActivityActive = false;
        }
      });
    } catch (e) {
      debugPrint('Error checking attendance: $e');
      setState(() {
        _isInTimeActive = true;
        _isOutTimeActive = false;
        _isDailyActivityActive = false;
      });
    }
  }

  Future<void> _recordOutAttendance(String type) async {
    if (_isOfflineMode || !_isNetworkConnected) {
      if (!_isOfflineMode) _showNetworkErrorDialog();
      return;
    }
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => OutAttandancePage()),
    );
    _loadData(checkAttendance: true);
  }

  Future<void> _recordInAttendance(String type) async {
    if (_isOfflineMode || !_isNetworkConnected) {
      if (!_isOfflineMode) _showNetworkErrorDialog();
      return;
    }
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AttandancePage()),
    );
    _loadData(checkAttendance: true);
  }

  void _navigateToRoute(String route) {
    if (route != 'daily_activity' && route != 'pending_activities' && (_isOfflineMode || !_isNetworkConnected)) {
      if (!_isOfflineMode) _showNetworkErrorDialog();
      return;
    }
    Navigator.pushNamed(context, route).then((_) => _loadData(checkAttendance: false));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = screenSize.width * 0.05;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Sales Dashboard${_isOfflineMode ? ' (Offline)' : ''}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green
                      .withOpacity(_isNetworkConnected && !_isOfflineMode ? 0.3 : 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: CircleAvatar(
                radius: screenSize.width * 0.04,
                backgroundColor:
                    Colors.grey[300]!.withOpacity(_isNetworkConnected && !_isOfflineMode ? 1.0 : 0.5),
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? Icon(
                        Icons.person_outline,
                        color: Colors.black87
                            .withOpacity(_isNetworkConnected && !_isOfflineMode ? 1.0 : 0.5),
                        size: 28,
                      )
                    : null,
              ),
              onPressed: (_isNetworkConnected && !_isOfflineMode)
                  ? () => Navigator.pushNamed(context, 'profile')
                      .then((_) => _loadData(checkAttendance: false))
                  : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF28A746)))
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF28A746), Color(0xFF219653)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOfflineMode ? 'Offline Mode' : 'Welcome Back!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isOfflineMode
                                  ? 'Manage your activities offline'
                                  : 'Manage your sales activities efficiently',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Attendance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildAttendanceButton(
                                    title: 'In Time',
                                    icon: Icons.login,
                                    color: Colors.green,
                                    onTap: _isInTimeActive && _isNetworkConnected && !_isOfflineMode
                                        ? () => _recordInAttendance('In Time')
                                        : null,
                                    isActive: _isInTimeActive && _isNetworkConnected && !_isOfflineMode,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildAttendanceButton(
                                    title: 'Out Time',
                                    icon: Icons.logout,
                                    color: Colors.red,
                                    onTap: _isOutTimeActive && _isNetworkConnected && !_isOfflineMode
                                        ? () => _recordOutAttendance('Out Time')
                                        : null,
                                    isActive: _isOutTimeActive && _isNetworkConnected && !_isOfflineMode,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                        children: [
                          _buildButton(
                            context: context,
                            title: 'Daily Activity',
                            icon: Icons.today,
                            route: 'daily_activity',
                            isActive: _isDailyActivityActive,
                          ),
                          _buildButton(
                            context: context,
                            title: 'Pending Activities',
                            icon: Icons.pending_actions,
                            route: 'pending_activities',
                            isActive: true, // Always active as it uses local data
                          ),
                          _buildButton(
                            context: context,
                            title: 'Activity Report',
                            icon: Icons.analytics,
                            route: 'activity_report',
                            isActive: _isNetworkConnected && !_isOfflineMode,
                          ),
                          if (_showExtraButtons)
                            _buildButton(
                              context: context,
                              title: 'Employee Node',
                              icon: Icons.group,
                              route: 'EmployeeNode',
                              isActive: _isNetworkConnected && !_isOfflineMode,
                            ),
                          if (_showExtraButtons)
                            _buildButton(
                              context: context,
                              title: 'Subordinate Report',
                              icon: Icons.assessment,
                              route: 'subordinate_report',
                              isActive: _isNetworkConnected && !_isOfflineMode,
                            ),
                          if (_showExtraButtons)
                            _buildButton(
                              context: context,
                              title: 'Subordinate Attendance',
                              icon: Icons.schedule,
                              route: 'subordinate_attendance_report_page',
                              isActive: _isNetworkConnected && !_isOfflineMode,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String route,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: isActive ? () => _navigateToRoute(route) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(isActive ? 0.2 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF28A746).withOpacity(isActive ? 0.1 : 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: Color(0xFF28A746).withOpacity(isActive ? 1.0 : 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87.withOpacity(isActive ? 1.0 : 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isActive ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(isActive ? 1.0 : 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color.withOpacity(isActive ? 1.0 : 0.5),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color.withOpacity(isActive ? 1.0 : 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}