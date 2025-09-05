import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class StatusOfWork {
  List<DropdownMenuItem<String>> statusOfWorkItems = [];

  Future<void> fetchStatusOfWorkItems(Function setState) async {
    const url =
        'https://www.skcinfotech.net.in/nabeenkishan/api/routes/MasterController/masterRoutes.php?action=getAllStatusOfWorks';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          statusOfWorkItems = data.map((item) {
            return DropdownMenuItem<String>(
              value: item['status_of_work_id'].toString(),
              child: Text(item['status_of_work']),
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
