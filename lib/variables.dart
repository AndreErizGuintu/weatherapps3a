// variables.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String api = dotenv.env['OPENWEATHER_API_KEY'] ?? "";

// App Settings
String defaultLocation = "Arayat";
Color IconColor = CupertinoColors.systemGreen;
String temperatureUnit = "Celsius"; // "Celsius", "Fahrenheit", or "Kelvin"