import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final String salintinigServiceUuid = "e5ada60b-8c3b-4417-a661-38a88671ca35";

Future<bool> autoConnectToSalintinigDevice(BuildContext context) async {
  if (await FlutterBluePlus.isSupported == false) {
    debugPrint("Bluetooth not supported");
    return false;
  }

  bool isConnecting = false;
  bool connectionSuccessful = false;

  var subscription = FlutterBluePlus.onScanResults.listen((results) async {
    for (ScanResult r in results) {
      // Safely grab the broadcasted name
      String deviceName = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : r.device.advName;

      bool hasUuid = r.advertisementData.serviceUuids.contains(
        Guid(salintinigServiceUuid),
      );

      // Match by Web, UUID, OR the Device Name
      // Note: If your ESP32 name is different, change "Salintinig" below!
      if ((kIsWeb || hasUuid || deviceName == "Salintinig BLE Device") &&
          !isConnecting) {
        isConnecting = true;
        debugPrint("✅ FOUND DEVICE: $deviceName. Connecting...");

        // 1. Stop scanning IMMEDIATELY to free up Android's Bluetooth hardware
        await FlutterBluePlus.stopScan();

        try {
          // 2. autoConnect MUST be false for a fast, active connection.
          // 3. Add a timeout so the UI doesn't freeze and crash the buffer queue.
          await r.device
              .connect(autoConnect: false)
              .timeout(const Duration(seconds: 10));
          debugPrint("✅ CONNECTED TO BLE: $deviceName");
          connectionSuccessful = true;

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Hardware Verified & Connected!")),
            );
          }
        } catch (e) {
          debugPrint("Failed to connect: $e");
          connectionSuccessful = false;
          isConnecting = false;
        }
        break; // Exit loop since we found our target
      }
    }
  });

  try {
    // 4. REMOVE the `withServices` filter.
    // This forces Android to see all devices, even those with truncated UUIDs.
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  } catch (e) {
    debugPrint("Scan error: $e");
  }

  // Brief polling loop to wait for connection success before navigating
  for (int i = 0; i < 20; i++) {
    if (connectionSuccessful) break;
    await Future.delayed(const Duration(milliseconds: 500));
  }

  subscription.cancel();
  return connectionSuccessful;
}
