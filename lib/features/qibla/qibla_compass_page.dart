import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../app_scope.dart';
import '../../core/qibla/qibla_service.dart';

class QiblaCompassPage extends StatefulWidget {
  const QiblaCompassPage({super.key});

  @override
  State<QiblaCompassPage> createState() => _QiblaCompassPageState();
}

class _QiblaCompassPageState extends State<QiblaCompassPage>
    with SingleTickerProviderStateMixin {
  double _qiblaBearing = 261.0;
  
  // Continuous heading for smooth AnimatedRotation without wrapping spins
  double _heading = 0.0;
  double _smoothHeading = 0.0;

  // Sensor availability
  bool _hasMagnetometer = false;
  bool _hasAccelerometer = false;
  bool _sensorsChecked = false;

  // Accelerometer + Magnetometer raw values
  double _ax = 0, _ay = 0, _az = 0;
  double _mx = 0, _my = 0, _mz = 0;

  // Manual calibration mode (for phones without magnetometer)
  bool _isCalibrated = false;
  double _calibrationOffset = 0.0; // user-set North offset

  // Gyroscope tracking (fallback for no-magnetometer phones)
  double _gyroHeading = 0.0;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  // Pulse animation for calibration hint
  late AnimationController _pulseController;

  // Theme Colors
  static const Color _bgColor = Color(0xFF0D1117);
  static const Color _surfaceColor = Color(0xFF161B22);
  static const Color _primaryColor = Color(0xFF10B981);
  static const Color _secondaryColor = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fetchQiblaBearing();
    _initSensors();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _accelSub?.cancel();
    _magSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchQiblaBearing() async {
    final scope = AppScope.of(context);
    try {
      final pos = await scope.location.getQuickPosition();
      if (pos != null) {
        final bearing =
            QiblaService.calculateQiblaBearing(pos.latitude, pos.longitude);
        if (mounted) setState(() => _qiblaBearing = bearing);
      }
    } catch (_) {}
  }

  void _initSensors() {
    // Try accelerometer
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 60),
    ).listen(
      (event) {
        _ax = event.x;
        _ay = event.y;
        _az = event.z;
        if (!_hasAccelerometer && mounted) {
          setState(() => _hasAccelerometer = true);
        }
        _computeHeading();
      },
      onError: (_) {},
    );

    // Try magnetometer
    _magSub = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 60),
    ).listen(
      (event) {
        _mx = event.x;
        _my = event.y;
        _mz = event.z;
        if (!_hasMagnetometer && mounted) {
          setState(() {
            _hasMagnetometer = true;
            _sensorsChecked = true;
          });
        }
        _computeHeading();
      },
      onError: (_) {
        // NO MAGNETOMETER — switch to gyroscope fallback
        if (mounted) {
          setState(() {
            _hasMagnetometer = false;
            _sensorsChecked = true;
          });
        }
        _initGyroscopeFallback();
      },
    );

    // Mark sensors as checked after a short delay (fallback)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_sensorsChecked) {
        setState(() => _sensorsChecked = true);
        if (!_hasMagnetometer) _initGyroscopeFallback();
      }
    });
  }

  void _initGyroscopeFallback() {
    if (_gyroSub != null) return;
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 60),
    ).listen(
      (GyroscopeEvent event) {
        if (!_isCalibrated) return;
        // event.z = rotation around Z axis (yaw) in rad/s
        // Integrate to get angle change (~60ms interval)
        double deltaAngle = -event.z * (180 / pi) * 0.06;
        _gyroHeading = _gyroHeading + deltaAngle;
        
        if (mounted) {
          setState(() {
            _heading = _calibrationOffset + _gyroHeading;
          });
        }
      },
      onError: (_) {},
    );
  }

  void _computeHeading() {
    if (!_hasAccelerometer || !_hasMagnetometer) return;

    // ── Android SensorManager.getRotationMatrix equivalent ──
    // H = cross(Geomagnetic, Gravity) → points EAST
    double hx = _my * _az - _mz * _ay;
    double hy = _mz * _ax - _mx * _az;
    double hz = _mx * _ay - _my * _ax;

    double hNorm = sqrt(hx * hx + hy * hy + hz * hz);
    if (hNorm < 0.001) return; // Vectors parallel — can't determine heading
    hx /= hNorm;
    hy /= hNorm;
    hz /= hNorm;

    // Normalize gravity vector
    double aNorm = sqrt(_ax * _ax + _ay * _ay + _az * _az);
    if (aNorm < 0.001) return;
    double ax = _ax / aNorm;
    double az = _az / aNorm;

    // M = cross(Gravity, H) → points NORTH (in horizontal plane)
    // Only My component needed for azimuth = atan2(Hy, My)
    double my = az * hx - ax * hz;

    // ── Android SensorManager.getOrientation equivalent ──
    // Azimuth = atan2(R[1], R[4]) = atan2(Hy, My)
    double rawHeading = atan2(hy, my) * (180 / pi);
    if (rawHeading < 0) rawHeading += 360;

    // Smooth using shortest angular distance for continuous rotation
    const double alpha = 0.15;
    double diff = rawHeading - ((_smoothHeading % 360 + 360) % 360);
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    _smoothHeading = _smoothHeading + alpha * diff;

    if (mounted) {
      setState(() => _heading = _smoothHeading);
    }
  }

  void _calibrateNorth() {
    // User is pointing phone towards North — set current gyro position as 0°
    setState(() {
      _isCalibrated = true;
      _gyroHeading = 0.0;
      _calibrationOffset = 0.0;
      _heading = 0.0;
      _smoothHeading = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ North calibrated! Now rotate slowly to find Qibla.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final Color bgColor = isDark ? _bgColor : theme.colorScheme.surface;
    final Color surfaceColor = isDark ? _surfaceColor : theme.colorScheme.surfaceContainerHighest;
    final Color primaryColor = isDark ? _primaryColor : theme.colorScheme.primary;
    final Color secondaryColor = isDark ? _secondaryColor : theme.colorScheme.secondary;

    final bool showCompass = _hasMagnetometer || _isCalibrated;
    final double displayHeading = (_heading % 360 + 360) % 360; // Normalize 0-360 for text

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor.withValues(alpha: 0.15), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: const Text('Qibla Compass', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: isDark
            ? BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [surfaceColor, bgColor],
                ),
              )
            : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Text(
                'Qibla Direction',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_qiblaBearing.toStringAsFixed(1)}° from True North',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),

              // No magnetometer warning + calibration button
              if (_sensorsChecked && !_hasMagnetometer) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No Compass Sensor Found\nUse Manual Calibration:',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '1. Open Google Maps to find North\n'
                        '2. Point the TOP of your phone towards North\n'
                        '3. Tap the button below to calibrate',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isCalibrated ? 1.0 : 1.0 + _pulseController.value * 0.03,
                            child: child,
                          );
                        },
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isCalibrated
                                  ? _primaryColor
                                  : _secondaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: _isCalibrated ? 0 : 4,
                            ),
                            onPressed: _calibrateNorth,
                            icon: Icon(_isCalibrated
                                ? Icons.check_circle
                                : Icons.explore),
                            label: Text(
                              _isCalibrated
                                  ? 'Re-calibrate North'
                                  : 'Calibrate Now',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ==================== COMPASS DIAL ====================
              SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring with ticks and compass rose
                    AnimatedRotation(
                      turns: showCompass ? -_heading / 360 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: surfaceColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.05),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _CompassRingPainter(
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                          ),
                        ),
                      ),
                    ),

                    // Qibla needle
                    AnimatedRotation(
                      turns: showCompass ? (_qiblaBearing - _heading) / 360 : _qiblaBearing / 360,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow under needle
                          Positioned(
                            top: 20,
                            child: Container(
                              width: 8,
                              height: 120,
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: secondaryColor.withValues(alpha: 0.6),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Needle icon
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.navigation,
                                size: 80,
                                color: secondaryColor,
                              ),
                              const SizedBox(height: 60), // Offset from center
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Center Kaaba icon
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.mosque, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Large Degree Readout
              Column(
                children: [
                  Text(
                    showCompass ? '${displayHeading.toStringAsFixed(0)}°' : '--°',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'CURRENT HEADING',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Sensor Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: showCompass
                        ? primaryColor.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showCompass ? Icons.sensors : Icons.sensors_off,
                      size: 18,
                      color: showCompass ? primaryColor : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      showCompass
                          ? (_hasMagnetometer ? 'Magnetic Sensor Active' : 'Gyroscope Active')
                          : 'Awaiting calibration...',
                      style: TextStyle(
                        color: showCompass ? primaryColor : Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassRingPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  
  _CompassRingPainter({required this.primaryColor, required this.secondaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Draw outer gradient ring
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: 0.1),
          primaryColor.withValues(alpha: 0.5),
          primaryColor.withValues(alpha: 0.1),
          primaryColor.withValues(alpha: 0.5),
          primaryColor.withValues(alpha: 0.1),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius - 3, ringPaint);

    // Draw tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final boldTickPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 360; i += 10) {
      final isBold = i % 30 == 0;
      final angle = i * pi / 180;
      final innerRadius = radius - (isBold ? 16 : 10);
      final outerRadius = radius - 6;
      
      final p1 = Offset(
        center.dx + innerRadius * cos(angle - pi / 2),
        center.dy + innerRadius * sin(angle - pi / 2),
      );
      final p2 = Offset(
        center.dx + outerRadius * cos(angle - pi / 2),
        center.dy + outerRadius * sin(angle - pi / 2),
      );
      canvas.drawLine(p1, p2, isBold ? boldTickPaint : tickPaint);
    }

    // Draw Compass Rose Text
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final List<String> directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    for (int i = 0; i < directions.length; i++) {
      final angle = i * 45 * pi / 180;
      final isCardinal = i % 2 == 0;
      
      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: isCardinal 
              ? (directions[i] == 'N' ? Colors.redAccent : Colors.white.withValues(alpha: 0.9))
              : Colors.white.withValues(alpha: 0.5),
          fontWeight: isCardinal ? FontWeight.bold : FontWeight.w500,
          fontSize: isCardinal ? 18 : 14,
        ),
      );
      textPainter.layout();
      
      final textRadius = radius - 35;
      final offset = Offset(
        center.dx + textRadius * cos(angle - pi / 2),
        center.dy + textRadius * sin(angle - pi / 2),
      );
      
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
