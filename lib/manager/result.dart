import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class Result {
  List<DropdownMenuItem<String>> activityResults = [];

  Future<void> fetchResults(Function setState) async {
    final response = await http.get(Uri.parse(
        'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllActivityResults'));

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
