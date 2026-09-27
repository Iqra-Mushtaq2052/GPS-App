import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

class QiblaCompassPage extends StatefulWidget {
  const QiblaCompassPage({super.key});

  @override
  State<QiblaCompassPage> createState() => _QiblaCompassPageState();
}

class _QiblaCompassPageState extends State<QiblaCompassPage> {
  Position? _currentPosition;
  double? _qiblaBearing;
  bool _isLoading = true;
  String _error = '';

  // Sensor mode
  bool _hasMagnetometer = false;
  double _heading = 0.0;
  StreamSubscription? _magnetometerSubscription;

  static const double meccaLat = 21.4225;
  static const double meccaLng = 39.8262;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _checkMagnetometer();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled.';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permissions are denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permissions are permanently denied.';
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final bearing = _calcBearing(
        position.latitude,
        position.longitude,
        meccaLat,
        meccaLng,
      );

      setState(() {
        _currentPosition = position;
        _qiblaBearing = bearing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: $e';
        _isLoading = false;
      });
    }
  }

  void _checkMagnetometer() {
    // Try to listen for a short time to see if we get valid data
    bool dataReceived = false;
    _magnetometerSubscription = magnetometerEventStream().listen((event) {
      if (!dataReceived && (event.x != 0 || event.y != 0 || event.z != 0)) {
        dataReceived = true;
        setState(() {
          _hasMagnetometer = true;
        });
      }
      
      if (_hasMagnetometer) {
        // Calculate heading (simplistic)
        final heading = atan2(event.y, event.x) * 180 / pi;
        setState(() {
          _heading = (heading < 0) ? heading + 360 : heading;
        });
      }
    }, onError: (e) {
      _hasMagnetometer = false;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!dataReceived) {
        _magnetometerSubscription?.cancel();
        _magnetometerSubscription = null;
        if (mounted) {
          setState(() {
            _hasMagnetometer = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    super.dispose();
  }

  static double _calcBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final lat1r = lat1 * pi / 180;
    final lat2r = lat2 * pi / 180;
    final y = sin(dLon) * cos(lat2r);
    final x = cos(lat1r) * sin(lat2r) - sin(lat1r) * cos(lat2r) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  String _getDirectionLabel(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    int index = ((bearing + 22.5) % 360 / 45).floor();
    return directions[index % 8];
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Qibla Direction'),
          centerTitle: true,
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 16),
            Text('Getting location...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = '';
                  });
                  _initLocation();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: const Text('Retry', style: TextStyle(color: Colors.black87)),
              )
            ],
          ),
        ),
      );
    }

    final bearing = _qiblaBearing ?? 0.0;
    final dirLabel = _getDirectionLabel(bearing);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Location Card
            Card(
              color: const Color(0xFF1F1F1F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Location', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            _currentPosition != null
                                ? '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                                : 'Unknown',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Compass Rose
            SizedBox(
              width: 300,
              height: 300,
              child: CustomPaint(
                painter: StaticCompassPainter(bearing),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Degree Readout
            Text(
              '${bearing.round()}°',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            
            // Direction Label
            Text(
              '$dirLabel from your location',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Info Card
            Card(
              color: const Color(0xFF1F1F1F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Qibla bearing from your location to Mecca',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This is calculated from your GPS coordinates — no compass sensor needed.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      '💡 Tip: Face any known direction (e.g. using Google Maps or sunrise/sunset) and rotate until pointing at the shown bearing.',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Optional Magnetometer Card
            if (_hasMagnetometer)
              Card(
                color: const Color(0xFF1F1F1F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.explore, color: Colors.amber, size: 16),
                          SizedBox(width: 8),
                          Text('Live compass available', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Transform.rotate(
                          angle: -(_heading * pi / 180),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24, width: 2),
                                ),
                              ),
                              Transform.rotate(
                                angle: bearing * pi / 180,
                                child: const Icon(Icons.navigation, color: Colors.amber, size: 60),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class StaticCompassPainter extends CustomPainter {
  final double bearing;
  
  StaticCompassPainter(this.bearing);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    
    // Draw outer circle
    final paintCircle = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, paintCircle);
    
    // Draw tick marks
    final paintTick = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    final paintThickTick = Paint()
      ..color = Colors.white54
      ..strokeWidth = 2;
      
    for (int i = 0; i < 360; i += 15) {
      final isMajor = i % 90 == 0;
      final tickLength = isMajor ? 12.0 : 6.0;
      
      final angle = i * pi / 180 - pi / 2; // -90 so 0 is up
      final p1 = Offset(
        center.dx + (radius - tickLength) * cos(angle),
        center.dy + (radius - tickLength) * sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      
      canvas.drawLine(p1, p2, isMajor ? paintThickTick : paintTick);
    }
    
    // Draw N/E/S/W labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    void drawLabel(String text, double angle) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: text == 'N' ? Colors.redAccent : Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      );
      textPainter.layout();
      final offset = Offset(
        center.dx + (radius - 30) * cos(angle) - textPainter.width / 2,
        center.dy + (radius - 30) * sin(angle) - textPainter.height / 2,
      );
      textPainter.paint(canvas, offset);
    }
    
    drawLabel('N', -pi / 2);
    drawLabel('E', 0);
    drawLabel('S', pi / 2);
    drawLabel('W', pi);
    
    // Draw Arrow
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(bearing * pi / 180);
    
    final paintArrow = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
      
    final path = Path()
      ..moveTo(0, -(radius - 40)) // Tip
      ..lineTo(12, 10)
      ..lineTo(0, -5)
      ..lineTo(-12, 10)
      ..close();
      
    canvas.drawPath(path, paintArrow);
    
    // Draw Mecca dot at tip
    final paintDot = Paint()..color = Colors.greenAccent;
    canvas.drawCircle(Offset(0, -(radius - 40)), 4, paintDot);
    
    canvas.restore();
    
    // Draw Mecca label near tip
    textPainter.text = const TextSpan(
      text: 'Mecca',
      style: TextStyle(
        color: Colors.greenAccent,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
    textPainter.layout();
    final meccaAngle = bearing * pi / 180 - pi / 2;
    final meccaLabelOffset = Offset(
      center.dx + (radius + 15) * cos(meccaAngle) - textPainter.width / 2,
      center.dy + (radius + 15) * sin(meccaAngle) - textPainter.height / 2,
    );
    textPainter.paint(canvas, meccaLabelOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
