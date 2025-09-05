import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nabeenkishan/dailyactivity/dailyactivity_provider.dart';
import 'package:nabeenkishan/dailyactivity/pending_activities_page.dart';
import 'package:nabeenkishan/emp_hierarchy.dart';
import 'package:nabeenkishan/godown/stock_transfar.dart';
import 'package:nabeenkishan/godown/stock_transfar_report.dart';
import 'package:nabeenkishan/manager/attandance_manager.dart';
import 'package:nabeenkishan/manager/cumulative_report.dart';
import 'package:nabeenkishan/manager/salary_report.dart';
import 'package:nabeenkishan/manager/salary_upload.dart';
import 'package:nabeenkishan/manager/manager_activity_provider.dart';
import 'package:nabeenkishan/subordinate_attandance.dart';
import 'package:provider/provider.dart';
import 'package:nabeenkishan/attandance.dart';
import 'package:nabeenkishan/attendance_out_time.dart';
import 'package:nabeenkishan/godown/current_stock.dart';
import 'package:nabeenkishan/dailyactivity/daily_activity.dart';
import 'package:nabeenkishan/godown/home_page_godwon.dart';
import 'package:nabeenkishan/godown/report_damage.dart';
import 'package:nabeenkishan/godown/report_return.dart';
import 'package:nabeenkishan/godown/report_stock_allocation.dart';
import 'package:nabeenkishan/godown/report_stock_in.dart';
import 'package:nabeenkishan/godown/stock_allocation.dart';
import 'package:nabeenkishan/godown/stock_damage.dart';
import 'package:nabeenkishan/godown/stock_return.dart';
import 'package:nabeenkishan/godown/stock_in.dart';
import 'package:nabeenkishan/home_page_sales.dart';
import 'package:nabeenkishan/login_page.dart';
import 'package:nabeenkishan/manager/insert_activity.dart';
import 'package:nabeenkishan/manager/manager_activity.dart';
import 'package:nabeenkishan/manager/subordinate_report.dart';
import 'package:nabeenkishan/profile.dart';
import 'package:nabeenkishan/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'activityreport.dart';
import 'manager/home_page_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? empId = prefs.getString('emp_id');
  String? designationCategory = prefs.getString('designation_category');
  print('Main: emp_id = $empId, designationCategory = $designationCategory');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        ChangeNotifierProvider(create: (_) => ManagerActivityProvider()),
      ],
      child: MyApp(empId: empId, designationCategory: designationCategory),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String? empId;
  final String? designationCategory;

  const MyApp({this.empId, this.designationCategory, super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class StatusCheckNavigatorObserver extends NavigatorObserver {
  final void Function(String empId) startStatusCheck;

  StatusCheckNavigatorObserver(this.startStatusCheck);

  Future<String?> _getEmpId(Route<dynamic>? route) async {
    String? empId;
    if (route?.settings.arguments is Map) {
      empId = (route?.settings.arguments as Map)['empId'];
    }
    if (empId == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      empId = prefs.getString('emp_id');
    }
    return empId;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) async {
    if (route.settings.name == 'splash_screen' || route.settings.name == 'login_page') {
      print('Skipping status check for ${route.settings.name}');
      return;
    }
    final empId = await _getEmpId(route);
    if (empId != null) {
      print('Route pushed: ${route.settings.name}, calling startStatusCheck for empId: $empId');
      startStatusCheck(empId);
    } else {
      print('Route pushed: ${route.settings.name}, no empId found.');
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) async {
    if (previousRoute?.settings.name == 'splash_screen' || previousRoute?.settings.name == 'login_page') {
      print('Skipping status check for ${previousRoute?.settings.name}');
      return;
    }
    final empId = await _getEmpId(previousRoute);
    if (empId != null) {
      print('Route popped, checking previous route: ${previousRoute?.settings.name}, calling startStatusCheck for empId: $empId');
      startStatusCheck(empId);
    } else {
      print('Route popped, previous route: ${previousRoute?.settings.name}, no empId found.');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) async {
    if (newRoute?.settings.name == 'splash_screen' || newRoute?.settings.name == 'login_page') {
      print('Skipping status check for ${newRoute?.settings.name}');
      return;
    }
    final empId = await _getEmpId(newRoute);
    if (empId != null) {
      print('Route replaced: ${newRoute?.settings.name}, calling startStatusCheck for empId: $empId');
      startStatusCheck(empId);
    } else {
      print('Route replaced: ${newRoute?.settings.name}, no empId found.');
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) async {
    if (previousRoute?.settings.name == 'splash_screen' || previousRoute?.settings.name == 'login_page') {
      print('Skipping status check for ${previousRoute?.settings.name}');
      return;
    }
    final empId = await _getEmpId(previousRoute);
    if (empId != null) {
      print('Route removed, checking previous route: ${previousRoute?.settings.name}, calling startStatusCheck for empId: $empId');
      startStatusCheck(empId);
    } else {
      print('Route removed, previous route: ${previousRoute?.settings.name}, no empId found.');
    }
  }
}

class _MyAppState extends State<MyApp> {
  Timer? _statusTimer;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    print('MyApp initState: empId = ${widget.empId}');
    // Determine initial route and call _startStatusCheck if appropriate
    final initialRoute = widget.empId != null
        ? (widget.designationCategory == 'GODOWN'
            ? '/home_page_godown'
            : widget.designationCategory == 'MANAGER'
                ? '/home_page_manager'
                : '/home_page_sales')
        : 'splash_screen';
    if (widget.empId != null && initialRoute != 'splash_screen' && initialRoute != 'login_page') {
      print('Initial route: $initialRoute, calling startStatusCheck for empId: ${widget.empId}');
      _startStatusCheck(widget.empId!);
    } else {
      print('No empId or initial route is splash_screen/login_page, skipping initial status check.');
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    print('MyApp disposed, timer canceled.');
    super.dispose();
  }

  void _startStatusCheck(String empId) {
    // Cancel any existing timer to prevent duplicates
    if (_statusTimer?.isActive ?? false) {
      print('Status check timer already active for empId: $empId, skipping restart.');
      return;
    }
    print('Starting status check for empId: $empId');
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final response = await http.get(
          Uri.parse(
              'https://www.nabeenkishan.net.in/newproject/api/routes/EmployeeController/getEmployeeDetails.php?emp_id=$empId'),
        );
        print('API Response Status: ${response.statusCode}');
        print('API Response Body: ${response.body}');

        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            String? empStatus = data['emp_status'];
            int? loginStatus = data['login_status'];
            print('Employee Status: $empStatus, Login Status: $loginStatus');

            if (empStatus != null && empStatus != 'ACTIVE' || loginStatus != 1) {
              print('Status is not ACTIVE or login status invalid, logging out...');
              await _logoutUser(reason: 'inactive');
              timer.cancel();
            } else {
              print('Status is ACTIVE, no action needed.');
            }
          } catch (e) {
            print('Error parsing JSON response: $e');
          }
        } else {
          print('Failed to fetch employee status: ${response.statusCode}');
        }
      } catch (e) {
        print('Error checking employee status: $e');
      }
    });
  }

  Future<void> _logoutUser({required String reason}) async {
    print('Showing logout dialog...');

    // Ensure the navigator key is attached to a widget
    if (navigatorKey.currentState == null) {
      print('Navigator not ready yet, delaying logout...');
      await Future.delayed(const Duration(milliseconds: 500));
      return _logoutUser(reason: reason);
    }

    String title;
    String message;

    if (reason == 'inactive') {
      title = 'Account Inactive';
      message =
          'Your account has been deactivated by the admin. Please contact support for assistance.';
    } else {
      title = 'Session Invalid';
      message =
          'You have been logged out due to an invalid session. Please log in again.';
    }

    // Show dialog and automatically dismiss after clearing session
    await showDialog(
      context: navigatorKey.currentState!.context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Automatically perform logout actions and close dialog
        Future.delayed(const Duration(seconds: 2), () async {
          print('Clearing session...');
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          if (context.mounted) {
            print('Navigating to login page...');
            Navigator.of(context).pop(); // Close dialog
            Navigator.pushNamedAndRemoveUntil(
                context, 'login_page', (route) => false);
          }
        });

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [], // No manual action buttons
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [
        StatusCheckNavigatorObserver(_startStatusCheck),
      ],
      initialRoute: widget.empId != null
          ? (widget.designationCategory == 'GODOWN'
              ? '/home_page_godown'
              : widget.designationCategory == 'MANAGER'
                  ? '/home_page_manager'
                  : '/home_page_sales')
          : 'splash_screen',
      routes: {
        'splash_screen': (context) => const SplashScreen(),
        'login_page': (context) => const LoginPage(),
        'attandance': (context) => const AttandancePage(),
        '/home_page_sales': (context) => const HomePageSales(),
        '/home_page_manager': (context) => const HomePageManager(),
        '/home_page_godown': (context) => const HomePageGodown(),
        'daily_activity': (context) => DailyActivityForm(),
        'activity_report': (context) => const ActivityReport(),
        'current_stock': (context) => const CurrentStockPage(),
        'transaction': (context) => TransactionPage(),
        'stock_allocation': (context) => StockAllocationPage(),
        'stock_return': (context) => StockReturnPage(),
        'stock_damage': (context) => StockDamagePage(),
        'report_stock_in': (context) => const ReportStockIn(),
        'insert_activity': (context) => const InsertActivityPage(),
        'report_stock_allocation': (context) => const ReportStockAllocation(),
        'report_stock_return': (context) => const ReportStockReturn(),
        'report_stock_damage': (context) => const ReportStockDamage(),
        'manager_activity_report': (context) => const ManagerActivityReport(),
        'stock_transfer': (context) => StockTransferPage(),
        'stock_transfer_report': (context) => const ReportStockTransfer(),
        'profile': (context) => const ProfilePage(),
        'out_time_attendance': (context) => const OutAttandancePage(),
        'salary_upload': (context) => const SalaryUploadPage(),
        'salary_report': (context) => const SalaryReportPage(),
        // 'pending_activities': (context) => const PendingActivitiesPage(),
        'cumulative_report': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final currentDate = DateTime.now();
          final formattedDate =
              "${currentDate.day.toString().padLeft(2, '0')}/"
              "${currentDate.month.toString().padLeft(2, '0')}/${currentDate.year}";
          return CumulativeReportPage(
            selectedEmpId: arguments?['empId'] ?? '',
            fromDate: arguments?['fromDate'] ?? formattedDate,
            toDate: arguments?['toDate'] ?? formattedDate,
            returnOrientation: arguments?['returnOrientation'] ?? 'portrait',
            selectedEmpName: arguments?['employeeName'] ?? '',
          );
        },
        'managerAttandance': (context) => const ManagerAttendancePage(),
        'subordinate_attendance_report_page': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return SubordinateAttendanceReportPage(
            preSelectedEmpId: arguments?['empId'],
            preSelectedEmployeeName: arguments?['employeeName'],
          );
        },
        'EmployeeNode': (context) => const OrgTreePage(),
        'subordinate_report': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return SubordinateReportPage(
            preSelectedEmpId: arguments?['empId'],
            preSelectedEmployeeName: arguments?['employeeName'],
          );
        },
      },
    );
  }
}