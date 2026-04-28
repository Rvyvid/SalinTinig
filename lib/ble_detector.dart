import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// For BLE button controls
final StreamController<int> salintinigButtonStream =
    StreamController<int>.broadcast();

// Salintinig BLE Service UUID to match
final String salintinigServiceUuid = "e5ada60b-8c3b-4417-a661-38a88671ca35";
// Salintinig Button Characteristic UUID for BLE button controls
final String salintinigButtonCharUuid = "e5ada60b-8c3b-4417-a661-38a88671ca36";

// Global variable to hold the connected device
BluetoothDevice? globalSalintinigDevice;

Future<bool> autoConnectToSalintinigDevice(BuildContext context) async {
  if (await FlutterBluePlus.isSupported == false) {
    debugPrint("Bluetooth not supported");
    return false;
  }

  bool isConnecting = false;
  bool connectionSuccessful = false;

  var subscription = FlutterBluePlus.onScanResults.listen((results) async {
    for (ScanResult r in results) {
      String deviceName = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : r.device.advName;

      bool hasUuid = r.advertisementData.serviceUuids.contains(
        Guid(salintinigServiceUuid),
      );

      if ((kIsWeb || hasUuid || deviceName == "Salintinig BLE Device") &&
          !isConnecting) {
        isConnecting = true;
        debugPrint("FOUND DEVICE: $deviceName. Connecting...");

        await FlutterBluePlus.stopScan();

        try {
          await r.device
              .connect(autoConnect: false)
              .timeout(
                const Duration(seconds: 10),
              ); // 10-second timeout for connecting

          debugPrint("CONNECTED TO BLE: $deviceName");
          // connectionSuccessful = true;
          globalSalintinigDevice = r.device;

          // CHANGES: Force clear GATT cache
          if (!kIsWeb) {
            try {
              await r.device.clearGattCache();
              debugPrint("Cleared GATT cache successfully.");
              await Future.delayed(const Duration(milliseconds: 500));
            } catch (e) {
              debugPrint("Failed to clear GATT cache: $e");
            }
          }

          // NEW: Discover services and subscribe to the button characteristic
          List<BluetoothService> services = await r.device.discoverServices();
          debugPrint("BLE: Found ${services.length} services.");
          // CHANGES: Case-insensitive matching (added .toLowerCase())
          for (var service in services) {
            if (service.uuid.toString().toLowerCase() ==
                salintinigServiceUuid.toLowerCase()) {
              debugPrint(
                "BLE: Matched Salintinig Service: ${service.uuid.toString()}",
              );
              for (var char in service.characteristics) {
                if (char.uuid.toString().toLowerCase() ==
                    salintinigButtonCharUuid.toLowerCase()) {
                  debugPrint(
                    "BLE: Matched Button Characteristic: ${char.uuid.toString()}",
                  );
                  await Future.delayed(const Duration(milliseconds: 500));
                  debugPrint("BLE: Enabling notifications...");

                  try {
                    await char.setNotifyValue(true);
                    debugPrint("BLE: Notifications enabled successfully!");
                  } catch (e) {
                    debugPrint("BLE Error: Failed to enable notifications: $e");
                  }
                  // CHANGES: Replaced lastValueStream with onValueReceived.
                  char.onValueReceived.listen((value) {
                    if (value.isNotEmpty && (value[0] == 1 || value[0] == 2)) {
                      debugPrint(
                        "BLE: Received button event code -> ${value[0]}",
                      );
                      salintinigButtonStream.add(value[0]);
                    }
                  });
                  debugPrint("Subscribed to Salintinig Button notifications!");
                }
              }
            }
          }

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
        break;
      }
    }
  });

  try {
    debugPrint(
      "BLE [WEB]: Requesting scan. Whitelisting service: $salintinigServiceUuid",
    );
    await FlutterBluePlus.startScan(
      withServices: [Guid(salintinigServiceUuid)],
      timeout: const Duration(seconds: 10),
    );
  } catch (e) {
    debugPrint("Scan error: $e");
  }

  for (int i = 0; i < 40; i++) {
    if (connectionSuccessful) {
      subscription.cancel();
      return true;
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }

  subscription.cancel();
  return false;
}

// ============================================================================
// BLE CONNECTION MONITORING
// ============================================================================

StreamSubscription<BluetoothConnectionState>? _bleSubscription;
Timer? _webHeartbeatTimer;
bool _isModalShowing = false;

void startBleListener(BuildContext context, {required VoidCallback onExitApp}) {
  _bleSubscription?.cancel();
  _webHeartbeatTimer?.cancel();

  if (globalSalintinigDevice != null) {
    // 1. Immediate check: Did it disconnect before the listener even attached?
    if (globalSalintinigDevice!.isDisconnected) {
      triggerDisconnectModal(context, onExitApp: onExitApp);
      return;
    }

    // 2. Stream listener for real-time drops
    _bleSubscription = globalSalintinigDevice!.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint("BLE Disconnected detected in stream!");
        triggerDisconnectModal(context, onExitApp: onExitApp);
      }
    });

    // 3. Web Fallback Active Ping
    if (kIsWeb) {
      _webHeartbeatTimer = Timer.periodic(const Duration(seconds: 5), (
        timer,
      ) async {
        if (globalSalintinigDevice != null &&
            !globalSalintinigDevice!.isDisconnected) {
          try {
            if (globalSalintinigDevice!.servicesList.isEmpty) {
              await globalSalintinigDevice!.discoverServices().timeout(
                const Duration(seconds: 5),
              );
            }
            BluetoothCharacteristic? pingChar;
            for (var service in globalSalintinigDevice!.servicesList) {
              for (var char in service.characteristics) {
                if (char.properties.read) {
                  pingChar = char;
                  break;
                }
              }
              if (pingChar != null) break;
            }
            if (pingChar != null) {
              await pingChar.read().timeout(const Duration(seconds: 3));
            }
          } catch (e) {
            String errorStr = e.toString().toLowerCase();
            if (errorStr.contains("timeout") ||
                errorStr.contains("disconnected") ||
                errorStr.contains("not connected")) {
              debugPrint("Web Ping properly timed out. Device is dead.");
              timer.cancel();
              triggerDisconnectModal(context, onExitApp: onExitApp);
            } else {
              debugPrint("Ignored harmless browser GATT warning: $e");
            }
          }
        }
      });
    }
  }
}

void triggerDisconnectModal(
  BuildContext context, {
  required VoidCallback onExitApp,
}) {
  if (context.mounted && !_isModalShowing) {
    _isModalShowing = true; // Lock it

    showDisconnectModal(
      context,
      onReconnectSuccess: () {
        _isModalShowing = false; // Unlock it on success
        startBleListener(context, onExitApp: onExitApp); // Restart the listener
      },
      onExitApp: () async {
        // Clean up states
        _isModalShowing = false;
        stopBleListener();

        // Ensure the BLE connection is actually dropped
        if (globalSalintinigDevice != null) {
          try {
            await globalSalintinigDevice!.disconnect();
          } catch (e) {
            debugPrint("Disconnect error: $e");
          }
        }

        // Trigger the callback to handle navigation back in main.dart
        onExitApp();
      },
    );
  }
}

void stopBleListener() {
  _webHeartbeatTimer?.cancel();
  _bleSubscription?.cancel();
}

void showDisconnectModal(
  BuildContext context, {
  required VoidCallback onReconnectSuccess,
  required VoidCallback onExitApp,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      // Using StatefulBuilder to manage the loading state inside the dialog without popping it
      bool isReconnecting = false;

      return PopScope(
        canPop:
            false, // Prevents closing the modal via the physical back button on Android
        child: StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: const Color(0xFF1A1A1A),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bluetooth_disabled_rounded,
                      color: Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Device Disconnected",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "The Salintinig earphones have been disconnected. Please power them on and reconnect.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height:
                          50, // Fixed height to prevent resizing when showing the loading circle
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          disabledBackgroundColor: Colors.redAccent.withOpacity(
                            0.6,
                          ), // Dim when loading
                        ),
                        // Disable button while reconnecting
                        onPressed: isReconnecting
                            ? null
                            : () async {
                                // 1. Update UI to show loading state
                                setState(() {
                                  isReconnecting = true;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Searching for earphones... (10s timeout)",
                                    ),
                                    duration: Duration(seconds: 3),
                                  ),
                                );

                                // Let the UI breathe and BT stack clear
                                await Future.delayed(
                                  const Duration(milliseconds: 500),
                                );

                                // 2. Attempt connection
                                bool success =
                                    await autoConnectToSalintinigDevice(
                                      context,
                                    );

                                // 3. Handle result
                                if (context.mounted) {
                                  if (success) {
                                    // Pop the dialog ONLY on success
                                    Navigator.of(dialogContext).pop();
                                    onReconnectSuccess();
                                  } else {
                                    // On failure, revert the button back to text so they can try again
                                    setState(() {
                                      isReconnecting = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Failed to reconnect. Please try again.",
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isReconnecting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                "Reconnect",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        // Disable Exit App button while trying to reconnect to prevent parallel actions
                        onPressed: isReconnecting
                            ? null
                            : () {
                                if (kIsWeb) {
                                  onExitApp();
                                  return;
                                }
                                if (Platform.isAndroid) {
                                  SystemNavigator.pop();
                                } else if (Platform.isIOS) {
                                  exit(0);
                                }
                              },
                        child: const Text(
                          "Exit App",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
