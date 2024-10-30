import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payment App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PaymentPage(),
    );
  }
}

class PaymentPage extends StatefulWidget {
  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  Map<String, dynamic> futureResponse = {};
  String merchantID = "0E0B20D2Z77A1";
  String accesstoken = "33318c39-3a5e-001b-b72f-943e4f3978ea";
  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Enter Amount',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState?.validate() ?? false) {
                    setState(() {
                      isLoading = true;
                    });
                    await getAllCustomers().then((customers) async {
                      print(customers.first["id"]);
                      await createOrder(customers.first["id"],_amountController.text)
                          .then((value) async {
                        if (!value.contains("Failure")) {
                          print("Order ID $value");
                          await getTenders().then((val) async {
                            if (val.isNotEmpty) {
                              await _makePayment(_amountController.text,
                                  val.first['id'], value);
                            }
                          });
                        } else {
                          // setState(() {
                          //   isLoading = false;
                          // });
                          print(value);
                        }
                      });
                    });

                    setState(() {
                      isLoading = false;
                    });
                  }
                },
                child: Text('Pay'),
              ),
              isLoading
                  ? CircularProgressIndicator()
                  : Text("Payemnts results ${futureResponse}")
            ],
          ),
        ),
      ),
    );
  }

  Future<String> createOrder(
    var id,
    String amount,
  ) async {
    final url =
        Uri.parse('https://api.clover.com/v3/merchants/$merchantID/orders');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accesstoken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'state': 'open',
        'total': amount,
        'currency': 'USD',
        'note': 'Sample order',
        'title': 'New Order',
        'customer': {
          // added staticialy customer id to add payemnts
          'id': "YS8MAGGAXNJ8W",
        },
        'items': [
          // Array of items (optional)
          {
            'name': 'Item 1',
            'price': 500, // Price in cents
            'quantity': 1,
          },
          {
            'name': 'Item 2',
            'price': 500, // Price in cents
            'quantity': 1,
          },
        ]
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final orderData = jsonDecode(response.body);
      print('Order created successfully: ${response.body}');

      return orderData['id'];
    } else {
      print('Order creation failed: ${response.statusCode} - ${response.body}');
      return "Failure";
    }
  }

  Future<Map<String, dynamic>> _makePayment(
      String amount, var tenderId, String orderID) async {
    // Replace with your actual API endpoint
    String url = 'https://api.clover.com/v3/merchants/$merchantID/payments';

    final response = await http.post(Uri.parse(url),
        headers: <String, String>{
          'accept': 'application/json',
          'authorization': 'Bearer $accesstoken',
          'content-type': 'application/json'
        },
        body: jsonEncode({
          'order': {
            'id': orderID,
          },
          'amount': amount, // Amount in cents
          'currency': 'USD',
          'tender': {
            'id': "1TA5FHCMW5A5P", // The tender ID retrieved earlier
          },
        }));

    // print("${response.body} .. response body");

    if (response.statusCode == 200) {
      print("${response.body} .. response body payments");
      futureResponse = jsonDecode(response.body);
      return jsonDecode(response.body);
    } else {
      print("${response.statusCode} .. response body payments");

      throw Exception();
    }
  }

  Future<List<dynamic>> getTenders() async {
    final url =
        Uri.parse('https://api.clover.com/v3/merchants/$merchantID/tenders');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accesstoken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final tenders = jsonDecode(response.body);
      print('Available tenders: ${tenders['elements']}');
      return tenders['elements'];
    } else {
      print(
          'Failed to retrieve tenders: ${response.statusCode} - ${response.body}');
      return [];
    }
  }

  Future<List> getAllCustomers() async {
    String baseUrl =
        'https://api.clover.com/v3/merchants/$merchantID/customers';
    String url = baseUrl;
    bool hasMore = true;

    while (hasMore) {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accesstoken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customers = data['elements'] as List;

        // for (var customer in customers) {
        //   print('Customer ID: ${customer['id']}');
        //   print('First Name: ${customer['firstName']}');
        //   print('Last Name: ${customer['lastName']}');
        //   print('---');
        // }

        // Check if there's a next page
        if (data['next'] != null) {
          url = baseUrl + data['next'];
        } else {
          hasMore = false;
        }
        return customers;
      } else {
        print(
            'Failed to retrieve customers: ${response.statusCode} - ${response.body}');
        hasMore = false;
      }
    }
    return [];
  }
}
