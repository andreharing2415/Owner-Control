import "package:geolocator/geolocator.dart";

class EvidenceMetadata {
  EvidenceMetadata({
    required this.capturedAt,
    this.latitude,
    this.longitude,
  });

  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
}

class EvidenceMetadataService {
  Future<EvidenceMetadata> collect() async {
    final now = DateTime.now().toUtc();

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return EvidenceMetadata(capturedAt: now);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      return EvidenceMetadata(
        capturedAt: now,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      return EvidenceMetadata(capturedAt: now);
    }
  }
}
