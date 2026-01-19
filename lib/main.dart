// dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'variables.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(const CupertinoApp(debugShowCheckedModeBanner: false, home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String convertTemp(double kelvin) {
    switch (temperatureUnit) {
      case "Celsius":
        return (kelvin - 273.15).toStringAsFixed(0);
      case "Fahrenheit":
        return ((kelvin - 273.15) * 9/5 + 32).toStringAsFixed(0);
      case "Kelvin":
        return kelvin.toStringAsFixed(0);
      default:
        return (kelvin - 273.15).toStringAsFixed(0);
    }
  }

  String getTempSymbol() {
    switch (temperatureUnit) {
      case "Celsius":
        return "°C";
      case "Fahrenheit":
        return "°F";
      case "Kelvin":
        return "K";
      default:
        return "°C";
    }
  }

  Widget _unitOption(String unit) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      onPressed: () {
        setState(() {
          temperatureUnit = unit;
        });
        Navigator.pop(context);
        getWeatherData(); // Refresh to apply new unit
      },
      child: Row(
        children: [
          Icon(
            temperatureUnit == unit
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            color: temperatureUnit == unit
                ? CupertinoColors.systemBlue
                : CupertinoColors.systemGrey,
          ),
          const SizedBox(width: 12),
          Text(unit),
        ],
      ),
    );
  }



  Widget _colorOption(Color color, String name) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      onPressed: () {
        setState(() {
          IconColor = color;
        });
        Navigator.pop(context);
        getWeatherData(); // Refresh to apply new color
      },
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(name),
        ],
      ),
    );
  }

  // -------------------- Weather Data --------------------
  List<Map<String, dynamic>> todayHourly = [];
  Map<String, List<dynamic>> dailyForecast = {}; // 5-day grouped forecast
  Map<String, dynamic>? _nearest; // nearest forecast for current display

  // -------------------- Current Weather --------------------
  String city = "";
  String weatherCondition = "";
  String temperature = "";
  String feels_like = "";
  String humidity = "";

  String currentLocation = "Arayat";

  final TextEditingController _location = TextEditingController();

  final List<BottomNavigationBarItem> itemz = const [
    BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: "Home"),
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.settings),
      label: "Settings",
    ),
  ];
  final CupertinoTabController _tabController = CupertinoTabController(
    initialIndex: 0,
  );

  // -------------------- Init --------------------
  @override
  void initState() {
    super.initState();
    getWeatherData();
  }

  // -------------------- Fetch Data --------------------
  Future<void> getWeatherData() async {
    final uri =
        "https://api.openweathermap.org/data/2.5/forecast?q=$currentLocation&appid=$api";
    final response = await http.get(Uri.parse(uri));

    final weatherData = jsonDecode(response.body);
    print(weatherData["cod"]);

    if (weatherData["cod"] != "200") {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text("Error"),
          content: const Text("Invalid City"),
          actions: [
            CupertinoButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
      return;
    }

    // -------------------- Nearest Forecast --------------------
    final timezoneOffset =
        weatherData["city"]["timezone"] as int; // Timezone offset in seconds

    dynamic nearest = weatherData["list"][0];
    Duration smallestDiff =
        DateTime.fromMillisecondsSinceEpoch(weatherData["list"][0]["dt"] * 1000)
            .add(Duration(seconds: timezoneOffset)) // Convert UTC to local time
            .difference(DateTime.now())
            .abs();

    for (var item in weatherData["list"]) {
      final itemTime = DateTime.fromMillisecondsSinceEpoch(
        item["dt"] * 1000,
      ).add(Duration(seconds: timezoneOffset)); // Convert UTC to local time
      final diff = itemTime.difference(DateTime.now()).abs();

      if (diff < smallestDiff) {
        smallestDiff = diff;
        nearest = item;
      }
    }
// -------------------- Today's 3-Hour Forecast (Max 6 entries) --------------------
    final hourly = weatherData["list"]
        .take(6) // Take maximum of 6 forecast entries
        .map<Map<String, dynamic>>((item) {
      final utcTime = DateTime.fromMillisecondsSinceEpoch(
        item["dt"] * 1000,
        isUtc: true,
      );
      final localTime = utcTime.add(Duration(seconds: timezoneOffset));
      final hour = localTime.hour;

      print("UTC: $utcTime | Local: $localTime | Hour: $hour");

      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final period = hour >= 12 ? 'PM' : 'AM';

      print("Display: $displayHour $period");

      return {
        "time": "$displayHour $period",
        "temp": convertTemp(item["main"]["temp"]),
        "feels_like": convertTemp(item["main"]["feels_like"]),
        "weather": item["weather"][0]["main"],
        "icon": item["weather"][0]["icon"],
      };
    })
        .toList();




    // -------------------- 5-Day Forecast --------------------
    final forecast = <String, List<dynamic>>{};
    for (var item in weatherData["list"]) {
      final utcTime = DateTime.fromMillisecondsSinceEpoch(item["dt"] * 1000);
      final localTime = utcTime.add(Duration(seconds: timezoneOffset));
      final key =
          "${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}";

      forecast.putIfAbsent(key, () => []);
      forecast[key]!.add(item);
    }

    // -------------------- Update State --------------------
    setState(() {
      _nearest = nearest;
      city = weatherData["city"]["name"];
      weatherCondition = nearest["weather"][0]["main"];
      temperature = convertTemp(nearest["main"]["temp"]);
      feels_like = convertTemp(nearest["main"]["feels_like"]);
      humidity = nearest["main"]["humidity"].toString();
      todayHourly = hourly;
      dailyForecast = forecast;
    });
  }

  // -------------------- Weather Icon Mapper --------------------
  IconData getWeatherIcon(String weather, {bool isNight = false}) {
    switch (weather) {
      case "Clear":
        return isNight ? CupertinoIcons.moon_stars : CupertinoIcons.sun_max;
      case "Clouds":
        return CupertinoIcons.cloud;
      case "Rain":
      case "Drizzle":
        return CupertinoIcons.cloud_rain;
      case "Thunderstorm":
        return CupertinoIcons.cloud_bolt;
      case "Snow":
        return CupertinoIcons.snow;
      case "Fog":
      case "Mist":
      case "Haze":
        return CupertinoIcons.cloud_fog;
      default:
        return CupertinoIcons.sun_max;
    }
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    final nearestIconIsNight =
        (_nearest?["weather"]?[0]?["icon"] as String?)?.endsWith("n") ?? false;

    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(items: itemz),
      tabBuilder: (context, index) {
        if (index == 0) {
          return CupertinoPageScaffold(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // -------------------- Current Weather --------------------
                  Text(
                    city,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 45,
                    ),
                  ),
                  Text(
                    weatherCondition,
                    style: const TextStyle(
                      fontWeight: FontWeight.w100,
                      fontSize: 35,
                    ),
                  ),
                  Icon(
                    getWeatherIcon(
                      weatherCondition,
                      isNight: nearestIconIsNight,
                    ),
                    size: 100,
                    color: IconColor,
                  ),
                  Text("$temperature${getTempSymbol()}", style: const TextStyle(fontSize: 35)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Feels like: $feels_like°'),
                      Text('Humidity: $humidity%'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // -------------------- Today's 3-Hour Forecast --------------------
                  // -------------------- Today's 3-Hour Forecast --------------------
                  SizedBox(
                    height: 140, // Increased height to accommodate feels like
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: todayHourly.length,
                      itemBuilder: (context, index) {
                        final item = todayHourly[index];
                        final weather = item["weather"] ?? "Clear";
                        final temp = item["temp"] ?? "";
                        final feelsLike = item["feels_like"] ?? "";
                        final time = item["time"] ?? "";
                        final night = (item["icon"] ?? "").endsWith("n");

                        return Container(
                          width: 90, // Increased width
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.black,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(time, style: const TextStyle(fontSize: 14)),
                              Icon(
                                getWeatherIcon(weather, isNight: night),
                                size: 35,
                                color: IconColor,
                              ),
                              Text("$temp${getTempSymbol()}", style: const TextStyle(fontSize: 16)),
                              Text(
                                "Feels $feelsLike${getTempSymbol()}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),


                  const SizedBox(height: 20),

                  // -------------------- 5-Day Forecast --------------------
                  Column(
                    children: dailyForecast.entries
                        .where((entry) {
                      // Filter out "Today"
                      final dateParts = entry.key.split('-');
                      final year = int.parse(dateParts[0]);
                      final month = int.parse(dateParts[1]);
                      final day = int.parse(dateParts[2]);
                      final forecastDay = DateTime(year, month, day);

                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);

                      return forecastDay != today; // Exclude today
                    })
                        .map((entry) {
                      final dateParts = entry.key.split('-');
                      final year = int.parse(dateParts[0]);
                      final month = int.parse(dateParts[1]);
                      final day = int.parse(dateParts[2]);
                      final date = DateTime.utc(year, month, day).toLocal();

                      final blocks = entry.value;

                      // Calculate min/max temps for the day
                      final temps = blocks
                          .map<double>((b) => (b["main"]["temp"] as num).toDouble())
                          .toList();
                      final minTemp = temperatureUnit == "Kelvin"
                          ? temps.reduce((a, b) => a < b ? a : b).toStringAsFixed(0)
                          : convertTemp(temps.reduce((a, b) => a < b ? a : b));
                      final maxTemp = temperatureUnit == "Kelvin"
                          ? temps.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)
                          : convertTemp(temps.reduce((a, b) => a > b ? a : b));


                      // Determine the dominant weather for the day
                      final weatherCounts = <String, int>{};
                      for (var b in blocks) {
                        final w = b["weather"][0]["main"] as String;
                        weatherCounts[w] = (weatherCounts[w] ?? 0) + 1;
                      }
                      final dominantWeather = weatherCounts.entries
                          .reduce((a, b) => a.value > b.value ? a : b)
                          .key;

                      // Determine if the icon should be night or day
                      final firstIcon =
                      blocks[0]["weather"][0]["icon"] as String;
                      final night = firstIcon.endsWith("n");

                      // Get day label (Tomorrow or weekday)
                      final now = DateTime.now();
                      final tomorrow = DateTime(now.year, now.month, now.day)
                          .add(const Duration(days: 1));
                      final forecastDay = DateTime(
                        date.year,
                        date.month,
                        date.day,
                      );

                      String dayLabel;
                      if (forecastDay == tomorrow) {
                        dayLabel = "Tom";
                      } else {
                        final weekdays = [
                          "Sun",
                          "Mon",
                          "Tue",
                          "Wed",
                          "Thu",
                          "Fri",
                          "Sat",
                        ];
                        dayLabel = weekdays[date.weekday % 7];
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dayLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  getWeatherIcon(
                                    dominantWeather,
                                    isNight: night,
                                  ),
                                  color: IconColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dominantWeather,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            Text(
                              "$maxTemp${getTempSymbol()}",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    })
                        .toList(),
                  ),

                ],
              ),
            ),
          );
        } else {
          // -------------------- Tab 1 Settings --------------------
// -------------------- Tab 1 Settings --------------------
          return CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text("Settings"),
            ),
            child: ListView(
              children: [
                // -------------------- Appearance Section --------------------
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                  child: Text(
                    "APPEARANCE",
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: IconColor,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          CupertinoIcons.paintbrush,
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                      ),
                      title: const Text("Icon Color"),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoDialog(
                            context: context,
                            builder: (context) {
                              return CupertinoAlertDialog(
                                title: const Text("Choose Icon Color"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _colorOption(CupertinoColors.systemBlue, "Blue"),
                                    _colorOption(CupertinoColors.systemGreen, "Green"),
                                    _colorOption(CupertinoColors.systemOrange, "Orange"),
                                    _colorOption(CupertinoColors.systemPurple, "Purple"),
                                    _colorOption(CupertinoColors.systemRed, "Red"),
                                    _colorOption(CupertinoColors.systemYellow, "Yellow"),
                                  ],
                                ),
                                actions: [
                                  CupertinoButton(
                                    child: const Text("Done"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: IconColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

// -------------------- Temperature Unit Section --------------------
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                  child: Text(
                    "TEMPERATURE",
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          CupertinoIcons.thermometer,
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                      ),
                      title: const Text("Unit"),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoDialog(
                            context: context,
                            builder: (context) {
                              return CupertinoAlertDialog(
                                title: const Text("Choose Temperature Unit"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _unitOption("Celsius"),
                                    _unitOption("Fahrenheit"),
                                    _unitOption("Kelvin"),
                                  ],
                                ),
                                actions: [
                                  CupertinoButton(
                                    child: const Text("Done"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              temperatureUnit,
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),


                // -------------------- Location Section --------------------
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                  child: Text(
                    "LOCATION",
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          CupertinoIcons.location,
                          color: CupertinoColors.white,
                          size: 20,
                        ),
                      ),
                      title: const Text("City"),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoDialog(
                            context: context,
                            builder: (context) {
                              return CupertinoAlertDialog(
                                title: const Text("Change City"),
                                content: Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    CupertinoTextField(
                                      controller: _location,
                                      placeholder: "Enter city name",
                                    ),
                                  ],
                                ),
                                actions: [
                                  CupertinoButton(
                                    child: const Text('Save'),
                                    onPressed: () {
                                      setState(() {
                                        currentLocation = _location.text;
                                      });
                                      getWeatherData();
                                      _tabController.index = 0;
                                      Navigator.pop(context);
                                    },
                                  ),
                                  CupertinoButton(
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: CupertinoColors.destructiveRed,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentLocation,
                              style: const TextStyle(
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: CupertinoColors.systemGrey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

        }
      },
    );
  }
}
