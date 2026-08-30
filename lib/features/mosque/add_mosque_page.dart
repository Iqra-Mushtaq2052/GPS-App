import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app_scope.dart';

class AddMosquePage extends StatefulWidget {
  const AddMosquePage({super.key});

  @override
  State<AddMosquePage> createState() => _AddMosquePageState();
}

class _AddMosquePageState extends State<AddMosquePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  double _radius = 40;
  Position? _capturedPosition;
  bool _isCapturing = false;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isCapturing = true;
      _error = null;
    });
    final scope = AppScope.of(context);
    try {
      if (!await scope.location.isLocationServiceEnabled()) {
        setState(() => _error = 'Location service band hai — pehle GPS on karein.');
        return;
      }
      var permission = await scope.location.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await scope.location.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission zaroori hai.');
        return;
      }
      final position = await scope.location.getCurrentPosition();
      setState(() => _capturedPosition = position);
    } catch (e) {
      setState(() => _error = 'Location capture nahi ho saki: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_capturedPosition == null) {
      setState(() => _error = 'Pehle masjid ki location capture karein.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final scope = AppScope.of(context);
    try {
      await scope.mosqueRepository.add(
        name: _nameController.text.trim(),
        latitude: _capturedPosition!.latitude,
        longitude: _capturedPosition!.longitude,
        radiusMeters: _radius.round(),
      );
      await scope.proximity.refreshMosques();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Save nahi ho saka: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masjid Add Karein')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Masjid ke andar ya gate ke paas khade ho kar "Location Capture Karein" dabayein.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Masjid ka naam',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Naam likhein' : null,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isCapturing ? null : _captureLocation,
                icon: _isCapturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _capturedPosition == null
                      ? 'Location Capture Karein'
                      : 'Location Capture Ho Gayi (dobara dabayein)',
                ),
              ),
              if (_capturedPosition != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Lat: ${_capturedPosition!.latitude.toStringAsFixed(6)}, '
                  'Lng: ${_capturedPosition!.longitude.toStringAsFixed(6)}\n'
                  'GPS accuracy: ~${_capturedPosition!.accuracy.toStringAsFixed(0)}m',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              Text('Geofence Radius: ${_radius.round()} meter'),
              Slider(
                value: _radius,
                min: 20,
                max: 60,
                divisions: 40,
                label: '${_radius.round()}m',
                onChanged: (value) => setState(() => _radius = value),
              ),
              const Text(
                'Chhoti radius GPS ke noise ki wajah se kabhi-kabhi der se '
                'trigger ho sakti hai — is liye entry par turant nahi, thodi '
                'der (dwell) ruk kar confirm hone par silent hota hai.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Karein'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
