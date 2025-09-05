
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';

class ManagerActivityProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isSyncing = false;
  List<String> _officeNames = [];
  List<Map<String, dynamic>> _demoProducts = [];
  List<DropdownMenuItem<String>> _statusOfWorkItems = [];
  List<DropdownMenuItem<String>> _officeNatureOfIdItems = [];
  List<DropdownMenuItem<String>> _natureOfWorkItems = [];
  List<DropdownMenuItem<String>> _activityResults = [];
  Database? _database;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isSyncing => _isSyncing;
  List<String> get officeNames => _officeNames;
  List<Map<String, dynamic>> get demoProducts => _demoProducts;
  List<DropdownMenuItem<String>> get statusOfWorkItems => _statusOfWorkItems;
  List<DropdownMenuItem<String>> get officeNatureOfIdItems => _officeNatureOfIdItems;
  List<DropdownMenuItem<String>> get natureOfWorkItems => _natureOfWorkItems;
  List<DropdownMenuItem<String>> get activityResults => _activityResults;

  ManagerActivityProvider() {
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    await resetDatabase(); // Force reset on initialization to ensure clean state
    await _listenForConnectivityChanges();
  }

  Future<void> _initDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(directory.path, 'manager_activities.db');
      _database = await openDatabase(
        dbPath,
        version: 4, // Incremented version to force onCreate
        onCreate: (db, version) async {
          await _createTables(db);
          await _prePopulateDefaultData(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _createTables(db);
          await _prePopulateDefaultData(db);
        },
      );
      print('Database initialized successfully at $dbPath');

      // Verify activity_results table integrity
      await _verifyActivityResultsTable();
      await loadCachedData();
      notifyListeners();
    } catch (e) {
      print('Error initializing database: $e');
      _database = null;
      _officeNames = [];
      _demoProducts = [];
      _statusOfWorkItems = [];
      _officeNatureOfIdItems = [];
      _natureOfWorkItems = [];
      _activityResults = [];
      notifyListeners();
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS drafts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        emp_id TEXT,
        data TEXT,
        image_path TEXT,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS status_of_work (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS office_names (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS office_nature_of_id (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS demo_products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nature_of_work (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_results (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
    print('Tables created successfully');
  }

  Future<void> _prePopulateDefaultData(Database db) async {
    try {
      await db.transaction((txn) async {
        // Clear all tables
        await txn.delete('activity_results');
        await txn.delete('status_of_work');
        await txn.delete('office_nature_of_id');
        await txn.delete('nature_of_work');
        await txn.delete('demo_products');

        // Populate status_of_work
        final statusOfWork = [
          {'id': 1, 'name': 'CAMP'},
          {'id': 2, 'name': 'OFFICE'},
          {'id': 3, 'name': 'INTERVIEW'},
          {'id': 4, 'name': 'OTHERS'},
        ];
        for (var item in statusOfWork) {
          await txn.insert('status_of_work', item, conflictAlgorithm: ConflictAlgorithm.replace);
          print('Inserted status_of_work: ${item['name']}');
        }

        // Populate office_nature_of_id
        final officeNature = [
          {'id': 1, 'name': 'MEETING'},
          {'id': 2, 'name': 'TRAINING'},
          {'id': 3, 'name': 'ADMINISTRATIVE'},
          {'id': 4, 'name': 'OTHERS'},
        ];
        for (var item in officeNature) {
          await txn.insert('office_nature_of_id', item, conflictAlgorithm: ConflictAlgorithm.replace);
          print('Inserted office_nature_of_id: ${item['name']}');
        }

        // Populate nature_of_work
        final natureOfWork = [
          {'id': 1, 'name': 'DEMO'},
          {'id': 2, 'name': 'DELIVERY & COLLECTION'},
          {'id': 3, 'name': 'SUBMISSION'},
          {'id': 4, 'name': 'MEETING'},
          {'id': 5, 'name': 'LEAVE'},
          {'id': 7, 'name': 'OTHERS'},
        ];
        for (var item in natureOfWork) {
          await txn.insert('nature_of_work', item, conflictAlgorithm: ConflictAlgorithm.replace);
          print('Inserted nature_of_work: ${item['name']}');
        }

        // Populate activity_results
        final activityResults = [
          {'id': 1, 'name': 'NEXT TIME VISIT'},
          {'id': 2, 'name': 'BOOKED'},
          {'id': 3, 'name': 'COME NEXT MONTH'},
          {'id': 4, 'name': 'DON’T WANT PRODUCT'},
          {'id': 5, 'name': 'MONEY PROBLEM'},
          {'id': 6, 'name': 'OTHERS'},
        ];
        for (var item in activityResults) {
          await txn.insert('activity_results', item, conflictAlgorithm: ConflictAlgorithm.replace);
          print('Inserted activity_results: ${item['name']}');
        }

        // Populate demo_products
        final demoProducts = [
          {'id': 1, 'name': 'N GROWTH 40KG'},
          {'id': 2, 'name': 'N STAR 1 LTR'},
          {'id': 3, 'name': 'N STAR 500 ML'},
          {'id': 4, 'name': 'N ZYMEL 1 LTR'},
          {'id': 5, 'name': 'N ZYME G PLUS 30 KG'},
          {'id': 6, 'name': 'N KILLER 500 GMS'},
          {'id': 7, 'name': 'N GUARD 4 KG'},
          {'id': 8, 'name': 'N POWER PLUS 500 ML'},
          {'id': 9, 'name': 'N POWER PLUS 250ML'},
          {'id': 10, 'name': 'NIMCO FIT 5 KG'},
          {'id': 11, 'name': 'NSPA-80 500ML'},
          {'id': 12, 'name': 'NIMCO FIT 10 KG'},
          {'id': 13, 'name': 'TEAK (Tectona-111)'},
          {'id': 14, 'name': 'Allhabadi Guava'},
          {'id': 15, 'name': 'Eureka Lemons'},
          {'id': 16, 'name': 'Thailand Jackfruit'},
          {'id': 17, 'name': 'Thailand Mango'},
        ];
        for (var item in demoProducts) {
          await txn.insert('demo_products', item, conflictAlgorithm: ConflictAlgorithm.replace);
          print('Inserted demo_products: ${item['name']}');
        }
      });
      print('Prepopulated default data successfully');
    } catch (e) {
      print('Error prepopulating default data: $e');
    }
  }

  Future<void> _verifyActivityResultsTable() async {
    if (_database == null) {
      print('Database is null, cannot verify activity_results table');
      return;
    }
    try {
      final count = Sqflite.firstIntValue(await _database!.rawQuery('SELECT COUNT(*) FROM activity_results')) ?? 0;
      print('activity_results table count: $count');
      if (count < 6) {
        print('activity_results table has $count entries (expected 6), repopulating...');
        await _prePopulateDefaultData(_database!);
      } else {
        final data = await _database!.query('activity_results');
        bool hasInvalidData = false;
        for (var item in data) {
          final id = item['id']?.toString();
          final name = item['name']?.toString();
          if (id == null || name == null || name.isEmpty || name == 'Unknown') {
            hasInvalidData = true;
            print('Invalid activity_results entry: $item');
          }
        }
        if (hasInvalidData) {
          print('Invalid data found in activity_results, repopulating...');
          await _prePopulateDefaultData(_database!);
        }
      }
      final updatedData = await _database!.query('activity_results');
      print('activity_results table after verification: $updatedData');
    } catch (e) {
      print('Error verifying activity_results table: $e');
      await _prePopulateDefaultData(_database!);
    }
  }

  Future<void> _listenForConnectivityChanges() async {
    Timer? debounce;
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final isConnected = results.any((result) => result != ConnectivityResult.none);
      if (isConnected && !_isSyncing) {
        if (debounce?.isActive ?? false) debounce!.cancel();
        debounce = Timer(const Duration(seconds: 2), () async {
          print('Network restored, refreshing data...');
          await Future.wait([
            fetchOfficeNames(forceFetch: true),
            fetchDemoProducts(forceFetch: true),
            fetchStatusOfWorkItems(forceFetch: true),
            fetchOfficeNatureOfId(forceFetch: true),
            fetchNatureOfWork(forceFetch: true),
            fetchActivityResults(forceFetch: true),
            syncDrafts(),
          ]);
        });
      } else if (!isConnected) {
        print('Offline mode detected, loading cached data...');
        await loadCachedData();
      }
    });
  }

  Future<void> loadCachedData() async {
    if (_database == null) {
      print('Database is null, initializing...');
      await _initDatabase();
      if (_database == null) {
        print('Failed to initialize database');
        _officeNames = [];
        _demoProducts = [];
        _statusOfWorkItems = [];
        _officeNatureOfIdItems = [];
        _natureOfWorkItems = [];
        _activityResults = [];
        notifyListeners();
        return;
      }
    }
    try {
      // Load status_of_work
      final statusOfWorkData = await _database!.query('status_of_work');
      _statusOfWorkItems = statusOfWorkData.map((item) {
        final id = item['id']?.toString();
        final name = item['name']?.toString();
        if (id == null || name == null || name.isEmpty || name == 'Unknown') {
          print('Invalid status_of_work data: $item');
          return DropdownMenuItem<String>(
            value: '0',
            child: Text('Unknown Status'),
          );
        }
        return DropdownMenuItem<String>(
          value: id,
          child: Text(name),
        );
      }).toList();
      print('Loaded status_of_work: ${_statusOfWorkItems.length} items');

      // Load office_names
      final officeNamesData = await _database!.query('office_names');
      _officeNames = officeNamesData.map((item) {
        final name = item['name']?.toString();
        if (name == null || name.isEmpty || name == 'Unknown') {
          print('Invalid office_names data: $item');
          return 'Unknown';
        }
        return name;
      }).toList();
      print('Loaded office_names: ${_officeNames.length} items');

      // Load office_nature_of_id
      final officeNatureData = await _database!.query('office_nature_of_id');
      _officeNatureOfIdItems = officeNatureData.map((item) {
        final id = item['id']?.toString();
        final name = item['name']?.toString();
        if (id == null || name == null || name.isEmpty || name == 'Unknown') {
          print('Invalid office_nature_of_id data: $item');
          return DropdownMenuItem<String>(
            value: '0',
            child: Text('Unknown Office Nature'),
          );
        }
        return DropdownMenuItem<String>(
          value: id,
          child: Text(name),
        );
      }).toList();
      print('Loaded office_nature_of_id: ${_officeNatureOfIdItems.length} items');

      // Load nature_of_work
      final natureOfWorkData = await _database!.query('nature_of_work');
      _natureOfWorkItems = natureOfWorkData.map((item) {
        final id = item['id']?.toString();
        final name = item['name']?.toString();
        if (id == null || name == null || name.isEmpty || name == 'Unknown') {
          print('Invalid nature_of_work data: $item');
          return DropdownMenuItem<String>(
            value: '0',
            child: Text('Unknown Nature of Work'),
          );
        }
        return DropdownMenuItem<String>(
          value: id,
          child: Text(name),
        );
      }).toList();
      print('Loaded nature_of_work: ${_natureOfWorkItems.length} items');

      // Load activity_results
      final activityResultsData = await _database!.query('activity_results');
      _activityResults = activityResultsData.map((item) {
        final id = item['id']?.toString();
        final name = item['name']?.toString();
        if (id == null || name == null || name.isEmpty || name == 'Unknown') {
          print('Invalid activity_results data: $item');
          return DropdownMenuItem<String>(
            value: '0',
            child: Text('Unknown Result'),
          );
        }
        return DropdownMenuItem<String>(
          value: id,
          child: Text(name),
        );
      }).toList();
      print('Loaded activity_results: ${_activityResults.length} items, data: $activityResultsData');

      // Load demo_products
      final demoProductsData = await _database!.query('demo_products');
      _demoProducts = demoProductsData.map((item) {
        final id = item['id']?.toString();
        final name = item['name']?.toString();
        if (id == null || name == null || name.isEmpty || name == 'Unknown') {
          print('Invalid demo_products data: $item');
          return {'id': '0', 'name': 'Unknown Product'};
        }
        return {'id': id, 'name': name};
      }).toList();
      print('Loaded demo_products: ${_demoProducts.length} items');

      // If activity_results is empty or invalid, repopulate
      if (_activityResults.isEmpty || _activityResults.every((item) => item.value == '0')) {
        print('activity_results empty or invalid, repopulating...');
        await _prePopulateDefaultData(_database!);
        final activityResultsData = await _database!.query('activity_results');
        _activityResults = activityResultsData.map((item) {
          final id = item['id']?.toString();
          final name = item['name']?.toString();
          if (id == null || name == null || name.isEmpty || name == 'Unknown') {
            print('Invalid activity_results data after repopulation: $item');
            return DropdownMenuItem<String>(
              value: '0',
              child: Text('Unknown Result'),
            );
          }
          return DropdownMenuItem<String>(
            value: id,
            child: Text(name),
          );
        }).toList();
        print('Repopulated activity_results: ${_activityResults.length} items, data: $activityResultsData');
      }

      notifyListeners();
    } catch (e) {
      print('Error loading cached data: $e');
      _officeNames = [];
      _demoProducts = [];
      _statusOfWorkItems = [];
      _officeNatureOfIdItems = [];
      _natureOfWorkItems = [];
      _activityResults = [];
      await _prePopulateDefaultData(_database!);
      notifyListeners();
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  Future<T> _retry<T>(Future<T> Function() fn, {int retries = 3, Duration delay = const Duration(seconds: 2)}) async {
    for (var i = 0; i < retries; i++) {
      try {
        return await fn().timeout(const Duration(seconds: 20)); // Increased timeout
      } catch (e) {
        if (i == retries - 1) {
          print('Failed after $retries retries: $e');
          rethrow;
        }
        await Future.delayed(delay);
        print('Retry ${i + 1} failed: $e');
      }
    }
    throw Exception('Failed after $retries retries');
  }

  Future<void> fetchOfficeNames({bool forceFetch = false}) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected && !forceFetch) {
      print('No connectivity, loading cached office names');
      await loadCachedData();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _retry(() => http.get(
            Uri.parse(
                'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllBranch'),
          ));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _officeNames = data.map((branch) => branch['branch_name']?.toString() ?? 'Unknown').toList();
          print('Fetched office_names from API: ${_officeNames.length} items');
          await _database?.transaction((txn) async {
            await txn.delete('office_names');
            for (var i = 0; i < _officeNames.length; i++) {
              await txn.insert('office_names', {'name': _officeNames[i]}, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
        } else {
          print('Empty or invalid office_names data from API: ${response.body}');
          await loadCachedData();
        }
      } else {
        print('Failed to fetch office_names: ${response.statusCode}, Body: ${response.body}');
        await loadCachedData();
      }
    } catch (e) {
      print('Error fetching office_names: $e');
      await loadCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDemoProducts({bool forceFetch = false}) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected && !forceFetch) {
      print('No connectivity, loading cached demo products');
      await loadCachedData();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _retry(() => http.get(Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllProducts')));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _demoProducts = data.map((item) => {
                'id': item['product_id']?.toString() ?? '',
                'name': item['product_name']?.toString() ?? 'Unknown',
              }).toList();
          print('Fetched demo_products from API: ${_demoProducts.length} items');
          await _database?.transaction((txn) async {
            await txn.delete('demo_products');
            for (var item in _demoProducts) {
              await txn.insert('demo_products', {
                'id': int.parse(item['id']),
                'name': item['name'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
        } else {
          print('Empty or invalid demo_products data from API: ${response.body}');
          await loadCachedData();
        }
      } else {
        print('Failed to fetch demo_products: ${response.statusCode}, Body: ${response.body}');
        await loadCachedData();
      }
    } catch (e) {
      print('Error fetching demo_products: $e');
      await loadCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStatusOfWorkItems({bool forceFetch = false}) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected && !forceFetch) {
      print('No connectivity, loading cached status of work');
      await loadCachedData();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _retry(() => http.get(Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllStatusOfWorks')));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _statusOfWorkItems = data.map((item) => DropdownMenuItem<String>(
                value: item['status_of_work_id']?.toString() ?? '',
                child: Text(item['status_of_work']?.toString() ?? 'Unknown'),
              )).toList();
          print('Fetched status_of_work from API: ${_statusOfWorkItems.length} items');
          await _database?.transaction((txn) async {
            await txn.delete('status_of_work');
            for (var item in data) {
              await txn.insert('status_of_work', {
                'id': int.parse(item['status_of_work_id'].toString()),
                'name': item['status_of_work']?.toString() ?? 'Unknown',
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
        } else {
          print('Empty or invalid status_of_work data from API: ${response.body}');
          await loadCachedData();
        }
      } else {
        print('Failed to fetch status_of_work: ${response.statusCode}, Body: ${response.body}');
        await loadCachedData();
      }
    } catch (e) {
      print('Error fetching status_of_work: $e');
      await loadCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchOfficeNatureOfId({bool forceFetch = false}) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected && !forceFetch) {
      print('No connectivity, loading cached office nature of work');
      await loadCachedData();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _retry(() => http.get(Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllOfficeNatureOfWorks')));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _officeNatureOfIdItems = data.map((item) => DropdownMenuItem<String>(
                value: item['office_nature_of_id']?.toString() ?? '',
                child: Text(item['office_nature_of_work']?.toString() ?? 'Unknown'),
              )).toList();
          print('Fetched office_nature_of_id from API: ${_officeNatureOfIdItems.length} items');
          await _database?.transaction((txn) async {
            await txn.delete('office_nature_of_id');
            for (var item in data) {
              await txn.insert('office_nature_of_id', {
                'id': int.parse(item['office_nature_of_id'].toString()),
                'name': item['office_nature_of_work']?.toString() ?? 'Unknown',
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
        } else {
          print('Empty or invalid office_nature_of_id data from API: ${response.body}');
          await loadCachedData();
        }
      } else {
        print('Failed to fetch office_nature_of_id: ${response.statusCode}, Body: ${response.body}');
        await loadCachedData();
      }
    } catch (e) {
      print('Error fetching office_nature_of_id: $e');
      await loadCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNatureOfWork({bool forceFetch = false}) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected && !forceFetch) {
      print('No connectivity, loading cached nature of work');
      await loadCachedData();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _retry(() => http.get(Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllNatureOfWorks')));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _natureOfWorkItems = data.map((item) => DropdownMenuItem<String>(
                value: item['nature_of_work_id']?.toString() ?? '',
                child: Text(item['nature_of_work']?.toString() ?? 'Unknown'),
              )).toList();
          print('Fetched nature_of_work from API: ${_natureOfWorkItems.length} items');
          await _database?.transaction((txn) async {
            await txn.delete('nature_of_work');
            for (var item in data) {
              await txn.insert('nature_of_work', {
                'id': int.parse(item['nature_of_work_id'].toString()),
                'name': item['nature_of_work']?.toString() ?? 'Unknown',
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
        } else {
          print('Empty or invalid nature_of_work data from API: ${response.body}');
          await loadCachedData();
        }
      } else {
        print('Failed to fetch nature_of_work: ${response.statusCode}, Body: ${response.body}');
        await loadCachedData();
      }
    } catch (e) {
      print('Error fetching nature_of_work: $e');
      await loadCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchActivityResults({bool forceFetch = false}) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected && !forceFetch) {
      print('No connectivity, loading cached activity results');
      await loadCachedData();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _retry(() => http.get(Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllActivityResults')));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _activityResults = data.map((item) {
            final id = item['result_id']?.toString();
            final name = item['result_name']?.toString();
            if (id == null || name == null || name.isEmpty || name == 'Unknown') {
              print('Invalid activity_results data from API: $item');
              return DropdownMenuItem<String>(
                value: '0',
                child: Text('Unknown Result'),
              );
            }
            return DropdownMenuItem<String>(
              value: id,
              child: Text(name),
            );
          }).toList();
          print('Fetched activity_results from API: ${_activityResults.length} items, data: $data');
          await _database?.transaction((txn) async {
            await txn.delete('activity_results');
            for (var item in data) {
              await txn.insert('activity_results', {
                'id': int.parse(item['result_id'].toString()),
                'name': item['result_name']?.toString() ?? 'Unknown',
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          });
        } else {
          print('Empty or invalid activity_results data from API: ${response.body}');
          await loadCachedData();
        }
      } else {
        print('Failed to fetch activity_results: ${response.statusCode}, Body: ${response.body}');
        await loadCachedData();
      }
    } catch (e) {
      print('Error fetching activity_results: $e');
      await loadCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitActivity({
    required Map<String, dynamic> data,
    File? image,
  }) async {
    if (_database == null) {
      await _initDatabase();
      if (_database == null) {
        print('Database initialization failed');
        return false;
      }
    }
    final isConnected = await _checkConnectivity();
    _isSubmitting = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getString('emp_id') ?? 'unknown';
      if (!isConnected) {
        final draftData = {
          'emp_id': empId,
          'data': jsonEncode(data),
          'image_path': image?.path,
          'created_at': DateTime.now().toIso8601String(),
        };
        await _database!.insert('drafts', draftData, conflictAlgorithm: ConflictAlgorithm.replace);
        print('Activity saved as draft for emp_id: $empId');
        return true;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/insertActivity.php'),
      );
      request.headers['Content-Type'] = 'multipart/form-data';
      request.fields['emp_id'] = empId;
      request.fields.addAll(data.map((key, value) => MapEntry(key, value.toString())));
      if (image != null && await image.exists()) {
        request.files.add(await http.MultipartFile.fromPath('spot_picture', image.path));
      }
      final response = await _retry(() => request.send());
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode == 201) {
        print('Activity submitted successfully: $responseBody');
        return true;
      } else {
        print('Failed to submit activity: ${response.statusCode}, Body: $responseBody');
        await _database!.insert('drafts', {
          'emp_id': empId,
          'data': jsonEncode(data),
          'image_path': image?.path,
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return true;
      }
    } catch (e) {
      print('Error submitting activity: $e');
      final prefs = await SharedPreferences.getInstance();
      await _database!.insert('drafts', {
        'emp_id': prefs.getString('emp_id') ?? 'unknown',
        'data': jsonEncode(data),
        'image_path': image?.path,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> syncDrafts() async {
    if (_database == null) {
      await _initDatabase();
      if (_database == null) {
        print('Database initialization failed, cannot sync drafts');
        return;
      }
    }
    if (_isSyncing) {
      print('Sync already in progress, skipping...');
      return;
    }
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      print('No internet connection, cannot sync drafts');
      return;
    }
    _isSyncing = true;
    notifyListeners();
    try {
      final drafts = await _database!.query('drafts');
      print('Starting sync for ${drafts.length} drafts');
      for (var draft in drafts) {
        final data = jsonDecode(draft['data'] as String) as Map<String, dynamic>;
        final imagePath = draft['image_path'] as String?;
        final imageFile = imagePath != null ? File(imagePath) : null;
        try {
          var request = http.MultipartRequest(
            'POST',
            Uri.parse(
                'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/insertActivity.php'),
          );
          request.headers['Content-Type'] = 'multipart/form-data';
          request.fields['emp_id'] = draft['emp_id'] as String;
          request.fields.addAll(data.map((key, value) => MapEntry(key, value.toString())));
          if (imageFile != null && await imageFile.exists()) {
            request.files.add(await http.MultipartFile.fromPath('spot_picture', imageFile.path));
          }
          final response = await _retry(() => request.send());
          final responseBody = await response.stream.bytesToString();
          if (response.statusCode == 201) {
            await _database!.delete('drafts', where: 'id = ?', whereArgs: [draft['id']]);
            if (imageFile != null && await imageFile.exists()) {
              await imageFile.delete();
              print('Image file deleted: $imagePath');
            }
            print('Draft ID ${draft['id']} synced and deleted successfully');
          } else {
            print('Failed to sync draft ID ${draft['id']}: ${response.statusCode}, Body: $responseBody');
          }
        } catch (e) {
          print('Error syncing draft ID ${draft['id']}: $e');
        }
      }
    } catch (e) {
      print('Error syncing drafts: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getDrafts() async {
    if (_database == null) {
      await _initDatabase();
      if (_database == null) {
        print('Database initialization failed');
        return [];
      }
    }
    try {
      return await _database!.query('drafts');
    } catch (e) {
      print('Error fetching drafts: $e');
      return [];
    }
  }

  Future<void> deleteDraft(int id) async {
    if (_database == null) {
      await _initDatabase();
      if (_database == null) {
        print('Database initialization failed');
        return;
      }
    }
    try {
      await _database!.delete('drafts', where: 'id = ?', whereArgs: [id]);
      print('Draft ID $id deleted successfully');
      notifyListeners();
    } catch (e) {
      print('Error deleting draft ID $id: $e');
    }
  }

  Future<Map<String, dynamic>> fetchActivityById(int activityId) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      print('No internet connection, cannot fetch activity');
      return {};
    }
    try {
      final response = await _retry(() => http.get(Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/ManagerActivitiesController/getActivity.php?id=$activityId')));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          throw Exception('Invalid activity data');
        }
      } else {
        throw Exception('Failed to fetch activity: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error fetching activity ID $activityId: $e');
      return {};
    }
  }

  Future<void> resetDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(directory.path, 'manager_activities.db');
      await deleteDatabase(dbPath);
      _database = null;
      await _initDatabase();
      await loadCachedData();
      print('Database reset successfully');
      await debugActivityResultsTable(); // Debug after reset
    } catch (e) {
      print('Error resetting database: $e');
    }
  }

  Future<List<Map<String, dynamic>>> debugActivityResultsTable() async {
    if (_database == null) {
      await _initDatabase();
      if (_database == null) {
        print('Database initialization failed');
        return [];
      }
    }
    try {
      final data = await _database!.query('activity_results');
      print('Debug activity_results table: $data');
      return data;
    } catch (e) {
      print('Error debugging activity_results table: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchProfilePicture(String empId) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      print('No internet connection, cannot fetch profile picture');
      return null;
    }
    try {
      final response = await _retry(() => http.get(Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/EmployeeController/getProfilePicture.php?emp_id=$empId')));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('Failed to fetch profile picture: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching profile picture for empId $empId: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkAttendanceStatus(String empId) async {
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      print('No internet connection, cannot check attendance');
      return null;
    }
    try {
      final response = await _retry(() => http.get(Uri.parse(
            'https://www.skcinfotech.net.in/nabeenkishan/api/routes/EmployeeController/checkAttendance.php?emp_id=$empId')));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('Failed to check attendance: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error checking attendance for empId $empId: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}