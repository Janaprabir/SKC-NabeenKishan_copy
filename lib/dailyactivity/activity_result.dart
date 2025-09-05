import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class ActivityResult {
  List<DropdownMenuItem<String>> activityResults = [];

  Future<void> fetchActivityResults(Function setState) async {
    final response = await http.get(Uri.parse(
        'https://www.nabeenkishan.net.in/newproject/api/routes/MasterController/masterRoutes.php?action=getAllActivityResults'));

    if (response.statusCode == 200) {
      List<dynamic> results = json.decode(response.body);
      setState(() {
        activityResults = results.map((result) {
          return DropdownMenuItem<String>(
            value: result['result_id'].toString(),
            child: Text(result['result']),
          );
        }).toList();
      });
    } else {
      throw Exception('Failed to load activity results');
    }
  }
}
