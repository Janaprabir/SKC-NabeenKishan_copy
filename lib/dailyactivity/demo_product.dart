import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class DemoProduct {
  List<DropdownMenuItem<String>> demoProductItems = [];
  String? selectedDemoProduct;

  Future<void> fetchDemoProducts(Function setState) async {
    final response = await http.get(Uri.parse(
        'https://www.nabeenkishan.net.in/appi/routes/MasterController/masterRoutes.php?action=getAllProducts'));

    if (response.statusCode == 200) {
      List<dynamic> products = json.decode(response.body);
      setState(() {
        demoProductItems = products
            .map((product) => DropdownMenuItem<String>(
                  value: product['product_id'].toString(),
                  child: Text(product['product_name']),
                ))
            .toList();
      });
    } else {
      throw Exception('Failed to load products');
    }
  }
}
