import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class NatureOfWork {
  List<DropdownMenuItem<String>> natureOfWorkItems = [];

  Future<void> fetchNatureOfWorkItems(Function setState) async {
    const url =
        'https://www.nabeenkishan.net.in/appi/routes/MasterController/masterRoutes.php?action=getAllNatureOfWork';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          natureOfWorkItems = data.map((item) {
            return DropdownMenuItem<String>(
              value: item['nature_of_work_id'].toString(),
              child: Text(item['nature_of_work']),
            );
          }).toList();
        });
      } else {
        throw Exception('Failed to load nature of work');
      }
    } catch (e) {
      print(e);
    }
  }
}
