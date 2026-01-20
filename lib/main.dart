import 'dart:convert';
import 'dart:math';
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
  // Add dark mode variable
  bool isDarkMode = false;

  // Improved color combinations with better contrast
  Color get backgroundColor => isDarkMode
      ? CupertinoColors.black
      : CupertinoColors.extraLightBackgroundGray;

  Color get textColor => isDarkMode
      ? CupertinoColors.white
      : const Color(0xFF1A1A1A); // Darker gray for better readability

  Color get secondaryTextColor => isDarkMode
      ? CupertinoColors.systemGrey2
      : const Color(0xFF5A5A5A); // Medium gray for secondary text

  Color get cardColor => isDarkMode
      ? const Color(0xFF1C1C1E) // Darker card color for better contrast
      : CupertinoColors.white;

  Color get subtleBackgroundColor => isDarkMode
      ? const Color(0xFF2C2C2E) // For subtle backgrounds
      : const Color(0xFFF2F2F7); // Light gray background

  Color get accentColor => isDarkMode
      ? CupertinoColors.systemBlue
      : const Color(0xFF007AFF); // Slightly deeper blue for light mode

  // Background asset mapper
  String getBackgroundAsset(String weatherCondition, bool isNight) {
    if (isDarkMode) {
      // Dark mode backgrounds - using appropriate dark versions
      switch (weatherCondition) {
        case "Clear":
          return isNight ? 'assets/night.gif' : 'assets/clear.gif';
        case "Clouds":
          return 'assets/cloudy.gif';
        case "Rain":
        case "Drizzle":
          return 'assets/rain.gif';
        case "Thunderstorm":
          return 'assets/storm.gif';
        case "Snow":
          return 'assets/snow.gif';
        case "Fog":
        case "Mist":
        case "Haze":
          return 'assets/fog.gif';
        default:
          return isNight ? 'assets/night.gif' : 'assets/sunny.gif';
      }
    } else {
      // Light mode backgrounds - ensure good contrast
      switch (weatherCondition) {
        case "Clear":
          return isNight ? 'assets/night.gif' : 'assets/sunny.gif';
        case "Clouds":
          return 'assets/cloudy.gif';
        case "Rain":
        case "Drizzle":
          return 'assets/rain.gif';
        case "Thunderstorm":
          return 'assets/storm.gif';
        case "Snow":
          return 'assets/snow.gif';
        case "Fog":
        case "Mist":
        case "Haze":
          return 'assets/fog.gif';
        default:
          return isNight ? 'assets/night.gif' : 'assets/sunny.gif';
      }
    }
  }

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
      padding: const EdgeInsets.symmetric(vertical: 12),
      onPressed: () {
        setState(() {
          temperatureUnit = unit;
        });
        Navigator.pop(context);
        getWeatherData();
      },
      child: Row(
        children: [
          Icon(
            temperatureUnit == unit
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            color: temperatureUnit == unit
                ? accentColor
                : secondaryTextColor,
          ),
          const SizedBox(width: 16),
          Text(
            unit,
            style: TextStyle(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _colorOption(Color color, String name) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12),
      onPressed: () {
        setState(() {
          IconColor = color;
        });
        Navigator.pop(context);
      },
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: color.computeLuminance() > 0.5
                    ? CupertinoColors.black.withOpacity(0.2)
                    : CupertinoColors.white.withOpacity(0.2),
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            name,
            style: TextStyle(color: textColor),
          ),
        ],
      ),
    );
  }

  // -------------------- Weather Data --------------------
  List<Map<String, dynamic>> todayHourly = [];
  Map<String, List<dynamic>> dailyForecast = {};
  Map<String, dynamic>? _nearest;
  String backgroundAsset = 'assets/sunny.gif';

  // -------------------- Current Weather --------------------
  String city = "";
  String weatherCondition = "";
  String temperature = "";
  String feels_like = "";
  String humidity = "";
  String windSpeed = "";
  String pressure = "";
  String visibility = "";
  String currentLocation = "Arayat";

  final TextEditingController _location = TextEditingController();
  late final List<BottomNavigationBarItem> itemz = [
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.cloud_sun, color: accentColor),
      label: "Weather",
    ),
    BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.settings, color: accentColor),
      label: "Settings",
    ),
  ];
  final CupertinoTabController _tabController = CupertinoTabController(
    initialIndex: 0,
  );

  @override
  void initState() {
    super.initState();
    getWeatherData();
  }

  Future<void> getWeatherData() async {
    try {
      // Get CURRENT weather first for accuracy
      final currentUri = "https://api.openweathermap.org/data/2.5/weather?q=$currentLocation&appid=$api";
      final currentResponse = await http.get(Uri.parse(currentUri));

      if (currentResponse.statusCode != 200) {
        _showErrorDialog("Failed to fetch weather data");
        return;
      }

      final currentData = jsonDecode(currentResponse.body);

      if (currentData["cod"] != 200) {
        _showErrorDialog("Invalid City");
        return;
      }

      // Get FORECAST for hourly/daily data
      final forecastUri = "https://api.openweathermap.org/data/2.5/forecast?q=$currentLocation&appid=$api";
      final forecastResponse = await http.get(Uri.parse(forecastUri));

      if (forecastResponse.statusCode != 200) {
        _showErrorDialog("Failed to fetch forecast");
        return;
      }

      final forecastData = jsonDecode(forecastResponse.body);
      final timezoneOffset = forecastData["city"]["timezone"] as int;

      // Process HOURLY forecast (next 8 entries for better coverage)
      final hourly = forecastData["list"]
          .take(8)
          .map<Map<String, dynamic>>((item) {
        final utcTime = DateTime.fromMillisecondsSinceEpoch(
          item["dt"] * 1000,
          isUtc: true,
        );
        final localTime = utcTime.add(Duration(seconds: timezoneOffset));
        final hour = localTime.hour;
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final period = hour >= 12 ? 'PM' : 'AM';

        return {
          "time": "$displayHour $period",
          "temp": convertTemp((item["main"]["temp"] as num).toDouble()),
          "feels_like": convertTemp((item["main"]["feels_like"] as num).toDouble()),
          "weather": item["weather"][0]["main"],
          "icon": item["weather"][0]["icon"],
          "humidity": item["main"]["humidity"].toString(),
        };
      }).toList();

      // Process DAILY forecast
      final forecast = <String, List<dynamic>>{};
      for (var item in forecastData["list"]) {
        final utcTime = DateTime.fromMillisecondsSinceEpoch(item["dt"] * 1000);
        final localTime = utcTime.add(Duration(seconds: timezoneOffset));
        final key = "${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}";

        forecast.putIfAbsent(key, () => []);
        forecast[key]!.add(item);
      }

      // Use CURRENT weather data (most accurate)
      final currentIcon = currentData["weather"][0]["icon"] as String;
      final currentIconIsNight = currentIcon.endsWith("n");
      final currentWeather = currentData["weather"][0]["main"] as String;

      // Calculate visibility in kilometers
      final visibilityValue = currentData["visibility"] as num? ?? 10000;
      final visibilityInKm = (visibilityValue / 1000).toStringAsFixed(1);

      setState(() {
        _nearest = currentData;
        city = currentData["name"] ?? "Unknown";
        weatherCondition = currentWeather;
        temperature = convertTemp((currentData["main"]["temp"] as num).toDouble());
        feels_like = convertTemp((currentData["main"]["feels_like"] as num).toDouble());
        humidity = currentData["main"]["humidity"].toString();
        windSpeed = (currentData["wind"]["speed"] as num).toStringAsFixed(1);
        pressure = currentData["main"]["pressure"].toString();
        visibility = visibilityInKm;
        todayHourly = hourly;
        dailyForecast = forecast;
        backgroundAsset = getBackgroundAsset(currentWeather, currentIconIsNight);
      });

    } catch (e) {
      _showErrorDialog("Error: ${e.toString()}");
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text("Error"),
        content: Text(message),
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
  }

  IconData getWeatherIcon(String weather, {bool isNight = false}) {
    switch (weather) {
      case "Clear":
        return isNight ? CupertinoIcons.moon_stars_fill : CupertinoIcons.sun_max_fill;
      case "Clouds":
        return CupertinoIcons.cloud_fill;
      case "Rain":
      case "Drizzle":
        return CupertinoIcons.cloud_rain_fill;
      case "Thunderstorm":
        return CupertinoIcons.cloud_bolt_rain_fill;
      case "Snow":
        return CupertinoIcons.snow;
      case "Fog":
      case "Mist":
      case "Haze":
        return CupertinoIcons.cloud_fog_fill;
      default:
        return CupertinoIcons.sun_max_fill;
    }
  }

  Widget _buildWeatherCard(IconData icon, String label, String value, String? unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? CupertinoColors.black.withOpacity(0.4)
                : CupertinoColors.systemGrey.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF3A3A3C)
              : const Color(0xFFE5E5EA),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: IconColor, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: secondaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "$value${unit ?? ''}",
            style: TextStyle(
              fontSize: 18,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nearestIconIsNight =
        (_nearest?["weather"]?[0]?["icon"] as String?)?.endsWith("n") ?? false;

    return CupertinoTabScaffold(
      controller: _tabController,
      tabBar: CupertinoTabBar(
        items: itemz,
        backgroundColor: cardColor,
        activeColor: accentColor,
        inactiveColor: secondaryTextColor,
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? const Color(0xFF3A3A3C)
                : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      tabBuilder: (context, index) {
        if (index == 0) {
          return Stack(
            children: [
              // Animated Background
              Positioned.fill(
                child: Image.asset(
                  backgroundAsset,
                  fit: BoxFit.cover,
                ),
              ),

              // Gradient overlay based on dark mode
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDarkMode
                          ? [
                        CupertinoColors.black.withOpacity(0.5),
                        CupertinoColors.black.withOpacity(0.8),
                      ]
                          : [
                        CupertinoColors.white.withOpacity(0.3),
                        CupertinoColors.white.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),

              CupertinoPageScaffold(
                backgroundColor: CupertinoColors.transparent,
                navigationBar: CupertinoNavigationBar(
                  backgroundColor: CupertinoColors.transparent,
                  border: null,
                  middle: Text(
                    "Weather",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Refresh icon removed from here
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // City Name and Weather Condition
                      Column(
                        children: [
                          Text(
                            city,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 48,
                              color: textColor,
                              shadows: isDarkMode
                                  ? [
                                Shadow(
                                  blurRadius: 10,
                                  color: CupertinoColors.black.withOpacity(0.5),
                                ),
                              ]
                                  : [
                                Shadow(
                                  blurRadius: 6,
                                  color: CupertinoColors.white.withOpacity(0.8),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            weatherCondition,
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 24,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Temperature Display - NO CARD/BORDER/BOX
                      Column(
                        children: [
                          // Temperature
                          Text(
                            "$temperature${getTempSymbol()}",
                            style: TextStyle(
                              fontSize: 84,
                              fontWeight: FontWeight.w200,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Feels like $feels_like${getTempSymbol()}",
                            style: TextStyle(
                              fontSize: 16,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Weather Icon
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  IconColor.withOpacity(0.15),
                                  IconColor.withOpacity(0.35),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: IconColor.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              getWeatherIcon(
                                weatherCondition,
                                isNight: nearestIconIsNight,
                              ),
                              size: 120,
                              color: IconColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Weather Stats Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        mainAxisSpacing: 15,
                        crossAxisSpacing: 15,
                        childAspectRatio: 0.9,
                        children: [
                          _buildWeatherCard(
                            CupertinoIcons.drop_fill,
                            "Humidity",
                            humidity,
                            "%",
                          ),
                          _buildWeatherCard(
                            CupertinoIcons.wind,
                            "Wind",
                            windSpeed,
                            " m/s",
                          ),
                          _buildWeatherCard(
                            CupertinoIcons.chart_bar_fill,
                            "Pressure",
                            pressure,
                            " hPa",
                          ),
                          _buildWeatherCard(
                            CupertinoIcons.eye_fill,
                            "Visibility",
                            visibility,
                            " km",
                          ),
                          _buildWeatherCard(
                            CupertinoIcons.thermometer,
                            "Min/Max",
                            "${todayHourly.isNotEmpty ? todayHourly.map((h) => double.parse(h["temp"])).reduce(min).toStringAsFixed(0) : "--"}/${todayHourly.isNotEmpty ? todayHourly.map((h) => double.parse(h["temp"])).reduce(max).toStringAsFixed(0) : "--"}",
                            getTempSymbol(),
                          ),
                          _buildWeatherCard(
                            CupertinoIcons.clock,
                            "Updated",
                            "Now",
                            "",
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Hourly Forecast
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(isDarkMode ? 0.9 : 0.95),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode
                                  ? CupertinoColors.black.withOpacity(0.3)
                                  : CupertinoColors.systemGrey.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF3A3A3C)
                                : const Color(0xFFE5E5EA),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.clock,
                                  color: IconColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'HOURLY FORECAST',
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 160,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: todayHourly.length,
                                itemBuilder: (context, index) {
                                  final item = todayHourly[index];
                                  final weather = item["weather"] ?? "Clear";
                                  final temp = item["temp"] ?? "";
                                  final time = item["time"] ?? "";
                                  final night = (item["icon"] ?? "").endsWith("n");

                                  return Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 15),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: subtleBackgroundColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: IconColor.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          time,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                          ),
                                        ),
                                        Icon(
                                          getWeatherIcon(weather, isNight: night),
                                          size: 36,
                                          color: IconColor,
                                        ),
                                        Column(
                                          children: [
                                            Text(
                                              "$temp${getTempSymbol()}",
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              weather,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: secondaryTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 5-Day Forecast
                      Container(
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(isDarkMode ? 0.9 : 0.95),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode
                                  ? CupertinoColors.black.withOpacity(0.3)
                                  : CupertinoColors.systemGrey.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF3A3A3C)
                                : const Color(0xFFE5E5EA),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.calendar,
                                  color: IconColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '5-DAY FORECAST',
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            ...dailyForecast.entries
                                .where((entry) {
                              final dateParts = entry.key.split('-');
                              final year = int.parse(dateParts[0]);
                              final month = int.parse(dateParts[1]);
                              final day = int.parse(dateParts[2]);
                              final forecastDay = DateTime(year, month, day);

                              final now = DateTime.now();
                              final today = DateTime(now.year, now.month, now.day);

                              return forecastDay != today;
                            })
                                .take(5)
                                .map((entry) {
                              final dateParts = entry.key.split('-');
                              final year = int.parse(dateParts[0]);
                              final month = int.parse(dateParts[1]);
                              final day = int.parse(dateParts[2]);
                              final date = DateTime.utc(year, month, day).toLocal();

                              final blocks = entry.value;
                              final temps = blocks
                                  .map<double>((b) => (b["main"]["temp"] as num).toDouble())
                                  .toList();
                              final minTemp = convertTemp(temps.reduce((a, b) => a < b ? a : b));
                              final maxTemp = convertTemp(temps.reduce((a, b) => a > b ? a : b));

                              final weatherCounts = <String, int>{};
                              for (var b in blocks) {
                                final w = b["weather"][0]["main"] as String;
                                weatherCounts[w] = (weatherCounts[w] ?? 0) + 1;
                              }
                              final dominantWeather = weatherCounts.entries
                                  .reduce((a, b) => a.value > b.value ? a : b)
                                  .key;

                              final firstIcon = blocks[0]["weather"][0]["icon"] as String;
                              final night = firstIcon.endsWith("n");

                              final now = DateTime.now();
                              final tomorrow = DateTime(now.year, now.month, now.day)
                                  .add(const Duration(days: 1));
                              final forecastDay = DateTime(date.year, date.month, date.day);

                              String dayLabel;
                              if (forecastDay == tomorrow) {
                                dayLabel = "Tomorrow";
                              } else {
                                final weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                                dayLabel = weekdays[date.weekday % 7];
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: subtleBackgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? const Color(0xFF3A3A3C)
                                        : const Color(0xFFE5E5EA),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        dayLabel,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          getWeatherIcon(dominantWeather, isNight: night),
                                          color: IconColor,
                                          size: 24,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          dominantWeather,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: Text(
                                        "$maxTemp${getTempSymbol()}  /  $minTemp${getTempSymbol()}",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                                .toList(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        } else {
          // Settings page with improved colors
          return CupertinoPageScaffold(
            backgroundColor: backgroundColor,
            navigationBar: CupertinoNavigationBar(
              backgroundColor: cardColor,
              middle: Text(
                "Settings",
                style: TextStyle(color: textColor),
              ),
            ),
            child: ListView(
              children: [
                const SizedBox(height: 16),

                // APPEARANCE SECTION
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 8),
                  child: Text(
                    "APPEARANCE",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: cardColor,
                  children: [
                    // Dark Mode Toggle
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? CupertinoColors.systemYellow
                              : CupertinoColors.systemPurple,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDarkMode
                              ? CupertinoIcons.moon_fill
                              : CupertinoIcons.sun_max_fill,
                          color: CupertinoColors.white,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        "Dark Mode",
                        style: TextStyle(color: textColor),
                      ),
                      trailing: CupertinoSwitch(
                        value: isDarkMode,
                        onChanged: (value) {
                          setState(() {
                            isDarkMode = value;
                          });
                        },
                        activeColor: accentColor,
                      ),
                    ),

                    // Icon Color
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: IconColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.paintbrush_fill,
                          color: CupertinoColors.white,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        "Icon Color",
                        style: TextStyle(color: textColor),
                      ),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) {
                              return Container(
                                height: 400,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        "Choose Icon Color",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView(
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        children: [
                                          _colorOption(CupertinoColors.systemBlue, "Blue"),
                                          _colorOption(CupertinoColors.systemGreen, "Green"),
                                          _colorOption(CupertinoColors.systemOrange, "Orange"),
                                          _colorOption(CupertinoColors.systemPurple, "Purple"),
                                          _colorOption(CupertinoColors.systemRed, "Red"),
                                          _colorOption(CupertinoColors.systemYellow, "Yellow"),
                                          _colorOption(CupertinoColors.systemTeal, "Teal"),
                                          _colorOption(CupertinoColors.systemPink, "Pink"),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: IconColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: secondaryTextColor,
                                  width: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // TEMPERATURE SECTION
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
                  child: Text(
                    "TEMPERATURE",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: cardColor,
                  children: [
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.thermometer,
                          color: CupertinoColors.white,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        "Unit",
                        style: TextStyle(color: textColor),
                      ),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) {
                              return Container(
                                height: 300,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        "Temperature Unit",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView(
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        children: [
                                          _unitOption("Celsius"),
                                          _unitOption("Fahrenheit"),
                                          _unitOption("Kelvin"),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              temperatureUnit,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // LOCATION SECTION
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
                  child: Text(
                    "LOCATION",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                CupertinoListSection.insetGrouped(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: cardColor,
                  children: [
                    CupertinoListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.location_fill,
                          color: CupertinoColors.white,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        "City",
                        style: TextStyle(color: textColor),
                      ),
                      trailing: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoDialog(
                            context: context,
                            builder: (context) {
                              return CupertinoAlertDialog(
                                title: Text(
                                  "Change City",
                                  style: TextStyle(color: textColor),
                                ),
                                content: Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    CupertinoTextField(
                                      controller: _location,
                                      placeholder: "Enter city name",
                                      placeholderStyle: TextStyle(
                                        color: secondaryTextColor,
                                      ),
                                      style: TextStyle(color: textColor),
                                      decoration: BoxDecoration(
                                        color: subtleBackgroundColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                    ),
                                  ],
                                ),
                                actions: [
                                  // Save button on the left
                                  CupertinoButton(
                                    child: const Text('Save'),
                                    onPressed: () {
                                      setState(() {
                                        currentLocation = _location.text.isNotEmpty
                                            ? _location.text
                                            : defaultLocation;
                                      });
                                      getWeatherData();
                                      _tabController.index = 0;
                                      Navigator.pop(context);
                                    },
                                  ),
                                  // Cancel button on the right
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
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.chevron_forward,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        }
      },
    );
  }
}