import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AadhaarExtractorPage extends StatefulWidget {
  const AadhaarExtractorPage({super.key});

  @override
  State<AadhaarExtractorPage> createState() => _AadhaarExtractorPageState();
}

class _AadhaarExtractorPageState extends State<AadhaarExtractorPage> {
  String extractedText = '';
  bool isLoading = false;
  String name = 'Name';
  String dob1 = 'Dob';
  String gender1 = 'Gender';
  String aadhaarNumber1 = 'xxxx xxxx xxxx 1234';
  String address1 = 'Address';

  Future<void> _pickImageAndExtractText() async {
    bool permissionGranted = await _requestPermission();
    if (!permissionGranted) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        isLoading = true;
      });

      final inputImage = InputImage.fromFile(File(pickedFile.path));
      final textRecognizer = GoogleMlKit.vision.textRecognizer();
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      await textRecognizer.close();

      String rawText = recognizedText.text;
      final Map<String, String?> aadhaarData = _extractAadhaarData(rawText);
      await _saveToCsv(aadhaarData);

      setState(() {
        extractedText = aadhaarData.entries
            .map((e) => '${e.key}: ${e.value ?? "Not Found"}')
            .join('\n');
        isLoading = false;
      });
    }
  }

  Map<String, String?> _extractAadhaarData(String text) {
    debugPrint('Extracted Text: $text');

    // Name matchers
    final initialNameRegex = RegExp(
      r'^(?:[A-Za-z]\.? ?){1,2}[A-Z][a-z]+$', // K Bhuvaneshwaran, K. B. Bhuvaneshwaran
      multiLine: true,
    );
    final mixedCaseNameRegex = RegExp(
      r'^[A-Z][a-z]+(?: [A-Z][a-z]+)+$', // Bhuvaneshwaran K
      multiLine: true,
    );
    final allCapsNameRegex = RegExp(
      r'^[A-Z ]{3,}$', // BHUVANESHWARAN K
      multiLine: true,
    );

    final dobRegex = RegExp(
      r'(DOB|Birth)\s*[:\-]?\s*(\d{2}[\/\-]\d{2}[\/\-]\d{4})',
      caseSensitive: false,
    );
    final genderRegex = RegExp(
      r'\b(Male|Female|ஆண்|பெண்)\b',
      caseSensitive: false,
    );
    final aadhaarRegex = RegExp(
      r'(?:(?:\d{4}|[*xX]{4})[ \-]?){3}',
      caseSensitive: false,
    );

    final addressRegex = RegExp(
      r'(Address:|S/O:).*?(\d{6})',
      caseSensitive: false,
      dotAll: true,
    );
    final issueDateRegex = RegExp(
      r'Issue Date\s*[:\-]?\s*(\d{2}[\/\-]\d{2}[\/\-]\d{4})',
      caseSensitive: false,
    );

    // Try all name matchers in order
    String? englishName;

    final initialMatch = initialNameRegex.firstMatch(text);
    final mixedMatch = mixedCaseNameRegex.firstMatch(text);
    final capsMatch = allCapsNameRegex.firstMatch(text);

    if (initialMatch != null) {
      englishName = initialMatch.group(0)?.trim();
    } else if (mixedMatch != null) {
      englishName = mixedMatch.group(0)?.trim();
    } else if (capsMatch != null) {
      englishName = capsMatch.group(0)?.trim();
    }

    final dob = dobRegex.firstMatch(text)?.group(2)?.trim();
    final gender = genderRegex.firstMatch(text)?.group(0)?.trim();
    final aadhaarNumber = aadhaarRegex.firstMatch(text)?.group(0)?.trim();
    final issueDate = issueDateRegex.firstMatch(text)?.group(1)?.trim();

    final addressMatch = addressRegex.firstMatch(text);
    final address =
        addressMatch
            ?.group(0)
            ?.replaceAll(RegExp(r'(Address:|S/O:)'), '')
            .trim();

    setState(() {
      name = englishName ?? 'Name';
      dob1 = dob ?? 'Dob';
      gender1 = gender ?? 'Gender';
      aadhaarNumber1 = aadhaarNumber ?? 'xxxx xxxx xxxx 1234';
      address1 = address ?? 'Address';
    });

    return {
      'English Name': englishName,
      'DOB': dob,
      'Gender': gender,
      'Aadhaar Number': aadhaarNumber,
      'Address': address ?? 'Address Not available',
      'Issue Date': issueDate,
    };
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Storage permission denied")),
          );
          return false;
        }
      } else {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Storage permission denied")),
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _saveToCsv(Map<String, String?> data) async {
    sendToGoogleSheet(data);
    final directory = await getExternalStorageDirectory();
    final path = '${directory!.path}/aadhaar_data.csv';
    final file = File(path);

    if (!await file.exists()) {
      await file.writeAsString(
        const ListToCsvConverter().convert([data.keys.toList()]) + '\n',
        mode: FileMode.write,
      );
    }

    await file.writeAsString(
      const ListToCsvConverter().convert([data.values.toList()]) + '\n',
      mode: FileMode.append,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aadhaar Text Extractor'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Google Sheet Link',
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 56),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black12, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(children: [topBar(), SizedBox(height: 10), body()]),
                  Column(
                    children: [
                      aadharNumber(),
                      Divider(color: Colors.deepOrange, thickness: 5),
                      Text(
                        "எனது ஆதார் எனது அடையாளம்",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImageAndExtractText,
        label: const Text('Pick Aadhaar Image'),
        icon: const Icon(Icons.image_search),
      ),
    );
  }

  Row aadharNumber() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          aadhaarNumber1,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Row body() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              height: 90,
              width: 70,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(Icons.person, size: 70)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(dob1),
                Text(gender1),
                Text(address1, style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        QrImageView(
          data: 'This QR code has an embedded image as well',
          version: QrVersions.auto,
          size: 80,
          gapless: false,
          embeddedImage: AssetImage('assets/images/my_embedded_image.png'),
          embeddedImageStyle: QrEmbeddedImageStyle(size: Size(80, 80)),
        ),
      ],
    );
  }

  Row topBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Image.asset('assets/indian_emblom.png', height: 50, width: 50),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 10,
              width: 150,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 230, 131, 2),
              ),
            ),
            SizedBox(height: 10),
            Container(
              height: 10,
              width: 230,
              decoration: BoxDecoration(color: Colors.green),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Image.asset(
          'assets/aadharcolor.png',
          height: 40,
          width: 80,
          scale: 300,
          fit: BoxFit.fitWidth,
        ),
      ],
    );
  }
}

Future<void> sendToGoogleSheet(Map<String, String?> data) async {
  const String url =
      'https://script.google.com/macros/s/AKfycbz9zHfsES8eL1Ex7pxLrGDynNZND5B17aEJ4Rhtv56Ou9h-bcjOoHw87yPQQHEWN9Gl/exec';

  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': data['English Name'],
      'dob': data['DOB'],
      'gender': data['Gender'],
      'aadhaar': data['Aadhaar Number'],
      'address': data['Address'],
      'issue_date': data['Issue Date'],
    }),
  );

  if (response.statusCode == 200) {
    debugPrint('✅ Data sent to Google Sheet');
  } else {
    debugPrint(
      '❌ Failed to send data: ${response.statusCode} ${response.body}',
    );
  }
}

//deployment url
//AKfycbySUkTNSt46CtoCiwFCgpVbAzVTYYS4KawOjPCjGOKti_ifELFF5dYGTB-_OnFpoDP_

//! web app url 
//https://script.google.com/macros/s/AKfycbySUkTNSt46CtoCiwFCgpVbAzVTYYS4KawOjPCjGOKti_ifELFF5dYGTB-_OnFpoDP_/exec