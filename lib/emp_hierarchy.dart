import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Employee Model
class Employee {
  final int empId;
  final String eCode;
  final String firstName;
  final String middleName;
  final String lastName;
  final String designation;
  final String shortDesignation;
  final int branchId;
  final String branchName;
  final List<Employee> subordinates;

  Employee({
    required this.empId,
    required this.eCode,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.designation,
    required this.shortDesignation,
    required this.branchId,
    required this.branchName,
    this.subordinates = const [],
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      empId: json['emp_id'] ?? 0,
      eCode: json['e_code'] ?? '',
      firstName: json['first_name'] ?? '',
      middleName: json['middle_name'] ?? '',
      lastName: json['last_name'] ?? '',
      designation: json['designation'] ?? '',
      shortDesignation: json['short_designation'] ?? '',
      branchId: json['branch_id'] ?? 0,
      branchName: json['branch_name'] ?? 'Unassigned',
      subordinates: (json['subordinates'] as List<dynamic>?)
              ?.map((e) => Employee.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// Branch Model to hold branch data
class Branch {
  final int branchId;
  final String branchName;
  final List<Employee> employees;

  Branch({
    required this.branchId,
    required this.branchName,
    required this.employees,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    List<Employee> employees = [];
    if (json['employees'] != null) {
      employees = (json['employees'] as List<dynamic>)
          .map((e) => Employee.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // Add top-level employees not under 'employees' array
    if (json['emp_id'] != null) {
      employees.add(Employee.fromJson(json));
    }
    return Branch(
      branchId: json['branch_id'] ?? 0,
      branchName: json['branch_name'] ?? 'Unassigned',
      employees: employees,
    );
  }
}

// Employee Tree Tile Widget (Unchanged)
class EmployeeTreeTile extends StatelessWidget {
  final Employee employee;

  const EmployeeTreeTile({required this.employee, super.key});

  Color _getDesignationColor(String shortDesignation) {
    switch (shortDesignation.toUpperCase()) {
      case 'SR DSM':
        return Colors.blue[300]!;
      case 'SR BM':
        return Colors.green[300]!;
      case 'DDSM':
        return Colors.purple[400]!;
      case 'DSM':
        return Colors.teal[400]!;
      case 'DBM':
        return Colors.teal[500]!;
      case 'BM':
        return Colors.indigo[400]!;
      case 'ABM':
        return Colors.purple[500]!;
      case 'TM':
        return Colors.deepPurple[600]!;
      case 'GC':
        return Colors.orange[600]!;
      case 'GL':
        return Colors.deepOrange[600]!;
      case 'SE':
        return Colors.red[600]!;
      case 'ARSM':
        return Colors.blue[500]!;
      default:
        return Colors.grey[500]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 10,
        margin: const EdgeInsets.fromLTRB(2, 0, 8, 8),
        child: ExpansionTile(
          backgroundColor: Colors.grey[300],
          leading: CircleAvatar(
            backgroundColor: _getDesignationColor(employee.shortDesignation),
            child: Text(
              employee.shortDesignation,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Select Report'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('Activity Report'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context,
                              'subordinate_report',
                              arguments: {
                                'empId': employee.empId.toString(),
                                'employeeName':
                                    '${employee.firstName} ${employee.lastName}',
                              },
                            );
                          },
                        ),
                        ListTile(
                          title: const Text('Attendance Report'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(
                              context,
                              'subordinate_attendance_report_page',
                              arguments: {
                                'empId': employee.empId.toString(),
                                'employeeName':
                                    '${employee.firstName} ${employee.lastName}',
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: Text(
              '${employee.firstName} ${employee.lastName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(employee.designation),
              Text(
                'Ecode: ${employee.eCode}',
                style: TextStyle(fontSize: 12, color: Colors.grey[900]),
              ),
              // Text(
              //   'Branch: ${employee.branchName}',
              //   style: TextStyle(fontSize: 12, color: Colors.grey[900]),
              // ),
            ],
          ),
          children: employee.subordinates
              .map((subordinate) => Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: EmployeeTreeTile(employee: subordinate),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// Main Page
class OrgTreePage extends StatefulWidget {
  const OrgTreePage({super.key});

  @override
  _OrgTreePageState createState() => _OrgTreePageState();
}

class _OrgTreePageState extends State<OrgTreePage> {
  List<Branch> branches = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchOrgData();
  }

  // Function to recursively count all employees, including subordinates
  int _countAllEmployees(List<Employee> employees) {
    int count = employees.length;
    for (var employee in employees) {
      count += _countAllEmployees(employee.subordinates);
    }
    return count;
  }

  Future<void> fetchOrgData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? empId = prefs.getString('emp_id');

      if (empId == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Employee ID not found in session';
        });
        return;
      }
      final response = await http.get(Uri.parse(
          'https://www.nabeenkishan.net.in/newproject/api/routes/SubordinateTreeController/getSubordinateTree.php?emp_id=$empId'));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        List<Branch> fetchedBranches = [];

        // Process the data array which contains branches
        for (var branchJson in jsonData['data']) {
          fetchedBranches.add(Branch.fromJson(branchJson));
        }

        setState(() {
          branches = fetchedBranches;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'No subordinates found for your account.';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching data: $e';
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    await fetchOrgData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Employee Node',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF28A746),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF28A746)))
            : errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              border: Border.all(color: Colors.orange),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning, color: Colors.orange),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    errorMessage,
                                    style: const TextStyle(
                                        color: Color.fromARGB(255, 19, 17, 17),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ElevatedButton(
                        //   onPressed: _refreshData,
                        //   child: const Text('Retry'),
                        // ),
                      ],
                    ),
                  )
                : branches.isEmpty
                    ? const Center(child: Text('No branches available'))
                    : SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: branches.map((branch) {
                              return Card(
                                elevation: 8,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ExpansionTile(
                                  leading: const Icon(
                                    Icons.account_tree,
                                    color: Color(0xFF28A746),
                                  ),
                                  title: Text(
                                    branch.branchName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_countAllEmployees(branch.employees)} Employee${_countAllEmployees(branch.employees) != 1 ? 's' : ''}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  children: branch.employees
                                      .map((employee) => EmployeeTreeTile(
                                            employee: employee,
                                          ))
                                      .toList(),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
      ),
    );
  }
}
