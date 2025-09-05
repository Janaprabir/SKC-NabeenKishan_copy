import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ActivityProvider with ChangeNotifier {
  List<Map<String, dynamic>> _natureOfWork = [];
  List<Map<String, dynamic>> _demoProducts = [];
  List<Map<String, dynamic>> _activityResults = [];
  Database? _database;
  final Connectivity _connectivity = Connectivity();
  bool _isSyncing = false; // Lock to prevent concurrent syncs

  List<Map<String, dynamic>> get natureOfWork => _natureOfWork;
  List<Map<String, dynamic>> get demoProducts => _demoProducts;
  List<Map<String, dynamic>> get activityResults => _activityResults;

  ActivityProvider() {
    _initDatabase();
    _listenForConnectivityChanges();
  }

  Future<void> _initDatabase() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = join(directory.path, 'activities.db');
      _database = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE drafts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              data TEXT,
              image_path TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE nature_of_work (
              id INTEGER PRIMARY KEY,
              name TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE demo_products (
              id INTEGER PRIMARY KEY,
              name TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE activity_results (
              id INTEGER PRIMARY KEY,
              name TEXT
            )
          ''');
          await _prePopulateDefaultData(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE nature_of_work (
                id INTEGER PRIMARY KEY,
                name TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE demo_products (
                id INTEGER PRIMARY KEY,
                name TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE activity_results (
                id INTEGER PRIMARY KEY,
                name TEXT
              )
            ''');
            await _prePopulateDefaultData(db);
          }
        },
      );
      await _loadCachedData();
      notifyListeners();
    } catch (e) {
      print("Error initializing database: $e");
    }
  }

  Future<void> _prePopulateDefaultData(Database db) async {
    await db.transaction((txn) async {
      await txn.insert('nature_of_work', {'id': 1, 'name': 'DEMO'});
      await txn.insert('nature_of_work', {'id': 2, 'name': 'DELIVERY & COLLECTION'});
      await txn.insert('nature_of_work', {'id': 3, 'name': 'SUBMISSION'});
      await txn.insert('nature_of_work', {'id': 4, 'name': 'MEETING'});
      await txn.insert('nature_of_work', {'id': 5, 'name': 'LEAVE'});
      await txn.insert('nature_of_work', {'id': 7, 'name': 'OTHERS'});
      await txn.insert('demo_products', {'id': 1, 'name': 'N GROWTH 40KG'});
      await txn.insert('demo_products', {'id': 2, 'name': 'N STAR 1 LTR'});
      await txn.insert('demo_products', {'id': 3, 'name': 'N STAR 500 ML'});
      await txn.insert('demo_products', {'id': 4, 'name': 'N ZYMEL 1 LTR'});
      await txn.insert('demo_products', {'id': 5, 'name': 'N ZYME G PLUS 30 KG'});
      await txn.insert('demo_products', {'id': 6, 'name': 'N KILLER 500 GMS'});
      await txn.insert('demo_products', {'id': 7, 'name': 'N GUARD 4 KG'});
      await txn.insert('demo_products', {'id': 8, 'name': 'N POWER PLUS 500 ML'});
      await txn.insert('demo_products', {'id': 9, 'name': 'N POWER PLUS 250ML'});
      await txn.insert('demo_products', {'id': 10, 'name': 'NIMCO FIT 5 KG'});
      await txn.insert('demo_products', {'id': 11, 'name': 'NSPA-80 500ML'});
      await txn.insert('demo_products', {'id': 12, 'name': 'NIMCO FIT 10 KG'});
      await txn.insert('demo_products', {'id': 13, 'name': 'TEAK (Tectona-111)'});
      await txn.insert('demo_products', {'id': 14, 'name': 'Allhabadi Guava'});
      await txn.insert('demo_products', {'id': 15, 'name': 'Eureka Lemons'});
      await txn.insert('demo_products', {'id': 16, 'name': 'Thailand Jackfruit'});
      await txn.insert('demo_products', {'id': 17, 'name': 'Thailand Mango'});
      await txn.insert('activity_results', {'id': 1, 'name': 'NEXT TIME VISIT'});
      await txn.insert('activity_results', {'id': 2, 'name': 'BOOKED'});
      await txn.insert('activity_results', {'id': 3, 'name': 'COME NEXT MONTH'});
      await txn.insert('activity_results', {'id': 4, 'name': 'DON’T WANT PRODUCT'});
      await txn.insert('activity_results', {'id': 5, 'name': 'MONEY PROBLEM'});
      await txn.insert('activity_results', {'id': 6, 'name': 'OTHERS'});
    });
  }

  void _listenForConnectivityChanges() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      final isConnected = results.any((result) => result != ConnectivityResult.none);
      if (isConnected && !_isSyncing) {
        print("Network restored, refreshing data...");
        await Future.wait([
          fetchNatureOfWork(forceFetch: true),
          fetchDemoProducts(forceFetch: true),
          fetchActivityResults(forceFetch: true),
          syncDrafts(),
        ]);
      }
    });
  }

  Future<void> _loadCachedData() async {
    if (_database == null) await _initDatabase();
    try {
      final natureOfWorkData = await _database!.query('nature_of_work');
      _natureOfWork = natureOfWorkData.map((item) => {
            'id': item['id'].toString(),
            'name': item['name'].toString(),
          }).toList();
      print("Loaded nature_of_work: $_natureOfWork");

      final demoProductsData = await _database!.query('demo_products');
      _demoProducts = demoProductsData.map((item) => {
            'id': item['id'].toString(),
            'name': item['name'].toString(),
          }).toList();
      print("Loaded demo_products: $_demoProducts");

      final activityResultsData = await _database!.query('activity_results');
      _activityResults = activityResultsData.map((item) => {
            'id': item['id'].toString(),
            'name': item['name'].toString(),
          }).toList();
      print("Loaded activity_results: $_activityResults");

      notifyListeners();
    } catch (e) {
      print("Error loading cached data: $e");
      _natureOfWork = [];
      _demoProducts = [];
      _activityResults = [];
      notifyListeners();
    }
  }

  Future<void> fetchNatureOfWork({bool forceFetch = false}) async {
    final isConnected = await _checkConnectivity();
    if (isConnected || forceFetch) {
      try {
        final response = await http.get(Uri.parse(
            'https://www.nabeenkishan.net.in/newproject/api/routes/MasterController/masterRoutes.php?action=getAllNatureOfWork'));

        if (response.statusCode == 200) {
          List data = jsonDecode(response.body);
          _natureOfWork = data.map((item) => {
                'id': item['nature_of_work_id'].toString(),
                'name': item['nature_of_work'].toString(),
              }).toList();
          print("Fetched nature_of_work from API: $_natureOfWork");

          await _database!.transaction((txn) async {
            await txn.delete('nature_of_work');
            for (var item in _natureOfWork) {
              await txn.insert('nature_of_work', {
                'id': int.parse(item['id']),
                'name': item['name'],
              });
            }
          });

          notifyListeners();
        } else {
          print("Failed to fetch nature_of_work: ${response.statusCode}");
          await _loadCachedData();
        }
      } catch (e) {
        print("Error fetching nature_of_work: $e");
        await _loadCachedData();
      }
    } else {
      await _loadCachedData();
    }
  }

  Future<void> fetchDemoProducts({bool forceFetch = false}) async {
    final isConnected = await _checkConnectivity();
    if (isConnected || forceFetch) {
      try {
        final response = await http.get(Uri.parse(
            'https://www.nabeenkishan.net.in/newproject/api/routes/MasterController/masterRoutes.php?action=getAllProducts'));

        if (response.statusCode == 200) {
          List data = jsonDecode(response.body);
          _demoProducts = data.map((item) => {
                'id': item['product_id'].toString(),
                'name': item['product_name'].toString(),
              }).toList();
          print("Fetched demo_products from API: $_demoProducts");

          await _database!.transaction((txn) async {
            await txn.delete('demo_products');
            for (var item in _demoProducts) {
              await txn.insert('demo_products', {
                'id': int.parse(item['id']),
                'name': item['name'],
              });
            }
          });

          notifyListeners();
        } else {
          print("Failed to fetch demo_products: ${response.statusCode}");
          await _loadCachedData();
        }
      } catch (e) {
        print("Error fetching demo_products: $e");
        await _loadCachedData();
      }
    } else {
      await _loadCachedData();
    }
  }

  Future<void> fetchActivityResults({bool forceFetch = false}) async {
    final isConnected = await _checkConnectivity();
    if (isConnected || forceFetch) {
      try {
        final response = await http.get(Uri.parse(
            'https://www.nabeenkishan.net.in/newproject/api/routes/MasterController/masterRoutes.php?action=getAllActivityResults'));

        if (response.statusCode == 200) {
          List data = jsonDecode(response.body);
          _activityResults = data.map((item) => {
                'id': item['result_id'].toString(),
                'name': item['result'].toString(),
              }).toList();
          print("Fetched activity_results from API: $_activityResults");

          await _database!.transaction((txn) async {
            await txn.delete('activity_results');
            for (var item in _activityResults) {
              await txn.insert('activity_results', {
                'id': int.parse(item['id']),
                'name': item['name'],
              });
            }
          });

          notifyListeners();
        } else {
          print("Failed to fetch activity_results: ${response.statusCode}");
          await _loadCachedData();
        }
      } catch (e) {
        print("Error fetching activity_results: $e");
        await _loadCachedData();
      }
    } else {
      await _loadCachedData();
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<bool> insertActivity(Map<String, dynamic> data, File? imageFile) async {
    try {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse(
            "https://www.nabeenkishan.net.in/newproject/api/routes/ActivityController/insertActivity.php"),
      );

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      if (imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath("spot_picture", imageFile.path),
        );
      }

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      print("Insert activity response for draft ${data['emp_id']}: $responseBody, Status: ${response.statusCode}");

      if (response.statusCode == 201) {
        print("Activity submitted successfully for draft ${data['emp_id']}");
        notifyListeners();
        return true;
      } else {
        print("Failed to insert activity: ${response.statusCode}, Response: $responseBody");
        return false;
      }
    } catch (error) {
      print("Error inserting activity for draft ${data['emp_id']}: $error");
      return false;
    }
  }

  Future<void> saveDraft(Map<String, dynamic> data, File? imageFile) async {
    if (_database == null) await _initDatabase();
    try {
      await _database!.insert(
        'drafts',
        {
          'data': jsonEncode(data),
          'image_path': imageFile?.path,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print("Saved draft for emp_id ${data['emp_id']}");
      notifyListeners();
    } catch (e) {
      print("Error saving draft: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getDrafts() async {
    if (_database == null) await _initDatabase();
    try {
      final drafts = await _database!.query('drafts');
      print("Retrieved drafts: ${drafts.length} items");
      return drafts;
    } catch (e) {
      print("Error retrieving drafts: $e");
      return [];
    }
  }

  Future<void> syncDrafts() async {
    if (_isSyncing) {
      print("Sync already in progress, skipping...");
      return;
    }

    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      print("No internet connection, cannot sync drafts");
      return;
    }

    setSyncing(true);
    try {
      final drafts = await getDrafts();
      print("Starting sync for ${drafts.length} drafts");

      // Process drafts sequentially to avoid concurrency issues
      for (var draft in drafts) {
        final data = jsonDecode(draft['data'] as String) as Map<String, dynamic>;
        final imageFile = draft['image_path'] != null ? File(draft['image_path'] as String) : null;
        print("Attempting to submit draft ID ${draft['id']} for emp_id ${data['emp_id']}");

        bool success = await insertActivity(data, imageFile);
        if (success) {
          await deleteDraft(draft['id']);
          print("Draft ID ${draft['id']} submitted and deleted successfully");
        } else {
          print("Failed to submit draft ID ${draft['id']}, keeping in database");
        }
      }
    } catch (e) {
      print("Error syncing drafts: $e");
    } finally {
      setSyncing(false);
    }
  }

  Future<bool> deleteActivity(String empId, String activityId) async {
    try {
      final response = await http.delete(
        Uri.parse(
            "https://www.nabeenkishan.net.in/newproject/api/routes/ActivityController/deleteActivity.php?emp_id=$empId&activity_id=$activityId"),//https://www.nabeenkishan.net.in/newproject/api
      );
      if (response.statusCode == 200) {
        print("Activity deleted successfully: emp_id=$empId, activity_id=$activityId");
        notifyListeners();
        return true;
      } else {
        print("Failed to delete activity: ${response.statusCode}");
        return false;
      }
    } catch (error) {
      print("Error deleting activity: $error");
      return false;
    }
  }

  Future<void> deleteDraft(int id) async {
    if (_database == null) await _initDatabase();
    try {
      await _database!.delete('drafts', where: 'id = ?', whereArgs: [id]);
      print("Draft ID $id deleted successfully");
      notifyListeners();
    } catch (e) {
      print("Error deleting draft ID $id: $e");
    }
  }

  void setSyncing(bool value) {
    _isSyncing = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}