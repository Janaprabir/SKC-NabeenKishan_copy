import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nabeenkishan/attandance.dart';
import 'package:nabeenkishan/attendance_out_time.dart';
import 'package:nabeenkishan/notification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomePageGodown extends StatefulWidget {
  const HomePageGodown({super.key});

  @override
  State<HomePageGodown> createState() => _HomePageState();
}

class _HomePageState extends State<HomePageGodown> {
  String? _empId;
  int? _godownId;
  String? _godownName; // New variable for godown name
  bool _isInTimeActive = false;
  bool _isOutTimeActive = false;
  bool _isStockInActive = false;
  bool _isStockAllocationActive = false;
  bool _isStockReturnActive = false;
  bool _isStockDamageActive = false;
  bool _isStockTransferActive = false;
  bool _isLoading = true;
  bool _isNetworkConnected = true;
  String? _profileImageUrl;
  int _unreadNotificationCount = 0;
  bool _hasCheckedAttendance = false;
  final String _baseUrl =
      'https://www.nabeenkishan.net.in/newproject/api/routes/StockTransferController';

  // Getter to return the capitalized godown name or an empty string if null
  String get godownName => _godownName?.toLowerCase() ?? '';
  //slice the first letter and capitalize it
  String get godownNameCapitalized =>
      godownName.isNotEmpty ? '${godownName[0].toUpperCase()}${godownName.substring(1)}' : '';

  @override
  void initState() {
    super.initState();
    _loadData(checkAttendance: true);
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
    setState(() => _isLoading = true);

    final isConnected = await _checkNetworkConnectivity();
    setState(() => _isNetworkConnected = isConnected);

    if (!isConnected) {
      setState(() => _isLoading = false);
      _showNetworkErrorDialog();
      return;
    }

    try {
      await _loadEmpIdAndGodownId();
      if (_empId != null && _godownId != null) {
        await Future.wait([
          if (checkAttendance && !_hasCheckedAttendance) _checkAttendanceStatus(),
          _fetchProfilePicture(),
          _fetchNotificationCount(),
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

  Future<void> _loadEmpIdAndGodownId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _empId = prefs.getString('emp_id');
      _godownId = prefs.getInt('godown_id');
      _godownName = prefs.getString('godown_name'); // Fetch godown name
    });
   
  }

  Future<void> _fetchProfilePicture() async {
    if (_empId == null) return;

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
            _profileImageUrl =
                'https://www.nabeenkishan.net.in/$cleanedPath';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile picture: $e');
      throw Exception('Failed to fetch profile picture');
    }
  }

  Future<void> _fetchNotificationCount() async {
    if (_godownId == null) {
      debugPrint('Error: Godown ID not found');
      return;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl/get_notifications_with_details.php?godown_id=$_godownId&limit=20');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final notifications = json.decode(response.body) as List;
        setState(() {
          _unreadNotificationCount = notifications
              .where((notification) => notification['status'] == 'unread')
              .length;
        });
      } else {
        debugPrint('Failed to fetch notifications: ${response.statusCode}');
        throw Exception('Failed to fetch notifications');
      }
    } catch (e) {
      debugPrint('Error fetching notification count: $e');
      throw Exception('Failed to fetch notification count');
    }
  }

  Future<void> _checkAttendanceStatus() async {
    if (_empId == null) {
      debugPrint('Error: Employee ID not found');
      return;
    }

    try {
      final currentDate = DateTime.now().toString().split(' ')[0];
      final url = Uri.parse(
          'https://www.nabeenkishan.net.in/newproject/api/routes/AttendanceController/attendanceReport.php'
          '?emp_id=$_empId&from_date=$currentDate&to_date=$currentDate');

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      final jsonResponse = json.decode(response.body);

      setState(() {
        if (jsonResponse['message'].contains('successfully')) {
          final attendanceData = jsonResponse['data'][0];
          if (attendanceData['out_time'] == '00:00:00' ||
              attendanceData['out_time'] == '') {
            _isInTimeActive = false;
            _isOutTimeActive = true;
            _isStockInActive = true;
            _isStockAllocationActive = true;
            _isStockReturnActive = true;
            _isStockDamageActive = true;
            _isStockTransferActive = true;
          } else {
            _isInTimeActive = false;
            _isOutTimeActive = false;
            _isStockInActive = false;
            _isStockAllocationActive = false;
            _isStockReturnActive = false;
            _isStockDamageActive = false;
            _isStockTransferActive = false;
          }
        } else {
          _isInTimeActive = true;
          _isOutTimeActive = false;
          _isStockInActive = false;
          _isStockAllocationActive = false;
          _isStockReturnActive = false;
          _isStockDamageActive = false;
          _isStockTransferActive = false;
        }
      });
    } catch (e) {
      debugPrint('Error checking attendance: $e');
      setState(() {
        _isInTimeActive = true;
        _isOutTimeActive = false;
        _isStockInActive = false;
        _isStockAllocationActive = false;
        _isStockReturnActive = false;
        _isStockDamageActive = false;
        _isStockTransferActive = false;
      });
    }
  }

  Future<void> _recordOutAttendance(String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OutAttandancePage()),
    );
    _loadData(checkAttendance: true);
  }

  Future<void> _recordInAttendance(String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AttandancePage()),
    );
    _loadData(checkAttendance: true);
  }

  void _showLoaderAndNavigate(String route) {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(const Duration(seconds: 1), () async {
      final isConnected = await _checkNetworkConnectivity();
      setState(() => _isNetworkConnected = isConnected);

      if (!isConnected) {
        setState(() => _isLoading = false);
        _showNetworkErrorDialog();
        return;
      }

      Navigator.pushNamed(context, route).then((_) => _loadData(checkAttendance: false));
      setState(() {
        _isLoading = false;
      });
    });
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
        title: const Text(
          'Godown Management',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.notification_important_outlined,
                  color: Colors.green.withOpacity(_isNetworkConnected ? 1.0 : 0.5),
                  size: 28,
                ),
                onPressed: _isNetworkConnected
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const NotificationPage()),
                        ).then((_) => _loadData(checkAttendance: false));
                      }
                    : null,
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red
                          .withOpacity(_isNetworkConnected ? 1.0 : 0.5),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_unreadNotificationCount',
                      style: TextStyle(
                        color: Colors.white
                            .withOpacity(_isNetworkConnected ? 1.0 : 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green
                      .withOpacity(_isNetworkConnected ? 0.3 : 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: CircleAvatar(
                radius: screenSize.width * 0.04,
                backgroundColor:
                    Colors.grey[300]!.withOpacity(_isNetworkConnected ? 1.0 : 0.5),
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null
                    ? Icon(
                        Icons.person_outline,
                        color: Colors.black87
                            .withOpacity(_isNetworkConnected ? 1.0 : 0.5),
                        size: 28,
                      )
                    : null,
              ),
              onPressed: _isNetworkConnected
                  ? () => Navigator.pushNamed(context, 'profile')
                      .then((_) => _loadData(checkAttendance: false))
                  : null,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF28A746)))
                : RefreshIndicator(
                    onRefresh: () => _loadData(checkAttendance: true),
                    color: const Color(0xFF28A746),
                    backgroundColor: Colors.white,
                    child: SingleChildScrollView(
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
                                    //concat _godownName Godow
                                    'Welcome to $godownNameCapitalized Godown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Track and manage your inventory',
                                    style: TextStyle(
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: _buildAttendanceButton(
                                          title: 'In Time',
                                          icon: Icons.login,
                                          color: Colors.green,
                                          onTap: _isInTimeActive &&
                                                  _isNetworkConnected
                                              ? () =>
                                                  _recordInAttendance('In Time')
                                              : null,
                                          isActive: _isInTimeActive &&
                                              _isNetworkConnected,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildAttendanceButton(
                                          title: 'OutTime',
                                          icon: Icons.logout,
                                          color: Colors.red,
                                          onTap: _isOutTimeActive &&
                                                  _isNetworkConnected
                                              ? () => _recordOutAttendance(
                                                  'Out Time')
                                              : null,
                                          isActive: _isOutTimeActive &&
                                              _isNetworkConnected,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            _buildButton(
                              context: context,
                              title: 'Current Stock',
                              icon: Icons.inventory,
                              route: 'current_stock',
                            ),
                            const SizedBox(height: 24),
                            const Row(
                              children: [
                                Icon(
                                  Icons.sync_alt_outlined,
                                  color: Color(0xFF28A746),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  'Transactions',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.2,
                              children: [
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock In',
                                  icon: Icons.archive,
                                  route: 'transaction',
                                  isActive:
                                      _isStockInActive && _isNetworkConnected,
                                ),
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock Dispatch',
                                  icon: Icons.playlist_add,
                                  route: 'stock_allocation',
                                  isActive: _isStockAllocationActive &&
                                      _isNetworkConnected,
                                ),
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock Return',
                                  icon: Icons.low_priority,
                                  route: 'stock_return',
                                  isActive: _isStockReturnActive &&
                                      _isNetworkConnected,
                                ),
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock Damage',
                                  icon: Icons.warning,
                                  route: 'stock_damage',
                                  isActive: _isStockDamageActive &&
                                      _isNetworkConnected,
                                ),
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock Transfer',
                                  icon: Icons.swap_horiz,
                                  route: 'stock_transfer',
                                  isActive: _isStockTransferActive &&
                                      _isNetworkConnected,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Row(
                              children: [
                                Icon(
                                  Icons.analytics,
                                  color: Color(0xFF28A746),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  'Reports',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color.fromARGB(255, 5, 5, 5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.2,
                              children: [
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock In',
                                  icon: Icons.archive,
                                  route: 'report_stock_in',
                                  isActive: _isNetworkConnected,
                                ),
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock Dispatch',
                                  icon: Icons.playlist_add,
                                  route: 'report_stock_allocation',
                                  isActive: _isNetworkConnected,
                                ),
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock Damage',
                                  icon: Icons.warning,
                                  route: 'report_stock_damage',
                                  isActive: _isNetworkConnected,
                                ),
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock Return',
                                  icon: Icons.low_priority,
                                  route: 'report_stock_return',
                                  isActive: _isNetworkConnected,
                                ),
                                _buildSmallButton(
                                  context: context,
                                  title: 'Stock Transfer',
                                  icon: Icons.swap_horiz,
                                  route: 'stock_transfer_report',
                                  isActive: _isNetworkConnected,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String route,
  }) {
    return GestureDetector(
      onTap: _isNetworkConnected ? () => _showLoaderAndNavigate(route) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(_isNetworkConnected ? 0.2 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF28A746)
                    .withOpacity(_isNetworkConnected ? 0.1 : 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: const Color(0xFF28A746)
                    .withOpacity(_isNetworkConnected ? 1.0 : 0.5),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87
                      .withOpacity(_isNetworkConnected ? 1.0 : 0.5),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey.withOpacity(_isNetworkConnected ? 1.0 : 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String route,
    required bool isActive,
  }) {
    final isButtonActive = isActive && _isNetworkConnected;
    return GestureDetector(
      onTap: isButtonActive ? () => _showLoaderAndNavigate(route) : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(isButtonActive ? 0.2 : 0.1),
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
                color: const Color(0xFF28A746)
                    .withOpacity(isButtonActive ? 0.1 : 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: Color(0xFF28A746).withOpacity(isButtonActive ? 1.0 : 0.5),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87.withOpacity(isButtonActive ? 1.0 : 0.5),
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
    final isButtonActive = isActive && _isNetworkConnected;
    return GestureDetector(
      onTap: isButtonActive ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isButtonActive ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(isButtonActive ? 1.0 : 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color.withOpacity(isButtonActive ? 1.0 : 0.5),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color.withOpacity(isButtonActive ? 1.0 : 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}