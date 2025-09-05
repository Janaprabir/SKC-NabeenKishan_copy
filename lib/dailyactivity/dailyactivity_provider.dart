import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ActivityProvider with ChangeNotifier {
  List<Map<String, dynamic>> _natureOfWork = [];
  List<Map<String, dynamic>> _demoProducts = [];
  List<Map<String, dynamic>>  _activityResults = [];
    List<Map<String, dynamic>> get natureOfWork => _natureOfWork;
  List<Map<String, dynamic>> get demoProducts => _demoProducts;
  List<Map<String, dynamic>> get activityResults => _activityResults;
  
Future<void> fetchNatureOfWork() async {
  final response = await http.get(Uri.parse(
      'https://www.nabeenkishan.net.in/newproject/api/routes/MasterController/masterRoutes.php?action=getAllNatureOfWork'));
  if (response.statusCode == 200) {
    List data = jsonDecode(response.body);
    _natureOfWork = data
        .where((item) => item['nature_of_work_id'] != 5) // Filter out item with nature_of_work_id == 5
        .map((item) => {"id": item['nature_of_work_id'], "name": item['nature_of_work']})
        .toList();
    notifyListeners();
  }
}
  Future<void> fetchDemoProducts() async {
    final response = await http.get(Uri.parse(
        'https://www.nabeenkishan.net.in/newproject/api/routes/MasterController/masterRoutes.php?action=getAllProducts'));

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      _demoProducts =
          data.map((item) => {"id": item['product_id'], "name": item['product_name']}).toList();
      notifyListeners();
    }
  }

  Future<void> fetchActivityResults() async {
    final response = await http.get(Uri.parse(
        'https://www.nabeenkishan.net.in/newproject/api/routes/MasterController/masterRoutes.php?action=getAllActivityResults'));

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      _activityResults =
          data.map((item) => {"id": item['result_id'], "name": item['result']}).toList();
      notifyListeners();
    }
  }
  Future<bool> insertActivity(Map<String, dynamic> data, File? imageFile) async {
  try {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("https://www.nabeenkishan.net.in/newproject/api/routes/ActivityController/insertActivity.php"),
    );

    // Add form fields
    data.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // Add image file if available
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath("spot_picture", imageFile.path),
      );
    }

    // Send request
    var response = await request.send();

    // Read response
    var responseBody = await response.stream.bytesToString();
    print("Response: $responseBody");

    if (response.statusCode == 201) {
      var jsonResponse = jsonDecode(responseBody);
     
        notifyListeners();
        return true;
    } else {
      print("Failed to insert. Status: ${response.statusCode}");
    }
  } catch (error) {
    print("Error inserting activity: $error");
  }
  return false;
}


  Future<bool> deleteActivity(String empId, String activityId) async {
    try {
      final response = await http.delete(
        Uri.parse(
            "https://www.nabeenkishan.net.in/newproject/api/routes/ActivityController/deleteActivity.php?emp_id=$empId&activity_id=$activityId"),
      );
      if (response.statusCode == 200) {
        notifyListeners();
        return true;
      }
    } catch (error) {
      print("Error deleting activity: $error");
    }
    return false;
  }
}
