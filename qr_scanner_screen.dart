// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:intl/intl.dart';

// class QRScannerScreen extends StatefulWidget {
//   final String currentBssid;
//   final String currentDeviceId;

//   const QRScannerScreen({
//     super.key,
//     required this.currentBssid,
//     required this.currentDeviceId,
//   });

//   @override
//   State<QRScannerScreen> createState() => _QRScannerScreenState();
// }

// class _QRScannerScreenState extends State<QRScannerScreen> {
//   static const Color maroon = Color(0xFF800000);
//   bool _isProcessing = false;
//   bool _hasScanned = false;
//   final MobileScannerController _controller = MobileScannerController();

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   Future<void> _handleScannedCode(String scannedValue) async {
//     if (_hasScanned || _isProcessing) return;
//     setState(() {
//       _hasScanned = true;
//       _isProcessing = true;
//     });

//     // Stop camera immediately
//     await _controller.stop();

//     debugPrint("=== QR SCAN DEBUG ===");
//     debugPrint("Scanned value: $scannedValue");
//     debugPrint("Scanned length: ${scannedValue.length}");

//     try {
//       // Clean the scanned token
//       final cleanToken = scannedValue.trim();

//       // Read QR config from Firestore (this is what web app writes to)
//       final doc = await FirebaseFirestore.instance
//           .collection('config')
//           .doc('qr')
//           .get();

//       debugPrint("Firestore config/qr exists: ${doc.exists}");

//       if (!doc.exists) {
//         _showError('QR system not configured. Contact admin.');
//         return;
//       }

//       final data = doc.data()!;
//       final storedToken = data['token']?.toString().trim() ?? '';
//       final expiresAtRaw = data['expiresAtMillis'];

//       // Handle both int and double types
//       final expiresAt = (expiresAtRaw is int)
//           ? expiresAtRaw
//           : (expiresAtRaw as num).toInt();

//       final now = DateTime.now().millisecondsSinceEpoch;

//       debugPrint("Stored token: $storedToken");
//       debugPrint("Tokens match: ${cleanToken == storedToken}");
//       debugPrint("Now: $now");
//       debugPrint("Expires: $expiresAt");
//       debugPrint("Not expired: ${now < expiresAt}");

//       // Verify token matches
//       if (cleanToken != storedToken) {
//         _showError(
//             'Invalid QR code. Please scan the current QR shown on office screen.');
//         return;
//       }

//       // Verify not expired
//       if (now >= expiresAt) {
//         _showError('QR code expired. Please scan the new one.');
//         return;
//       }

//       // ✅ ALL CHECKS PASSED - Mark Attendance
//       await _finalizeAttendanceRecord();
//     } catch (e) {
//       debugPrint("QR verification error: $e");
//       _showError('Error verifying QR: $e');
//     }
//   }

//   Future<void> _finalizeAttendanceRecord() async {
//     try {
//       User? user = FirebaseAuth.instance.currentUser;
//       String uid = user?.uid ?? 'anonymous_user';
//       String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

//       // Save to users/{uid}/attendance/{date}
//       // (This matches what dashboard.dart reads from)
//       final docRef = FirebaseFirestore.instance
//           .collection('users')
//           .doc(uid)
//           .collection('attendance')
//           .doc(todayDate);

//       await docRef.set({
//         'uid': uid,
//         'date': todayDate,
//         'checkInTime': FieldValue.serverTimestamp(),
//         'checkOutTime': null,
//         'checkinBssid': widget.currentBssid,
//         'deviceId': widget.currentDeviceId,
//         'status': 'Present',
//         'verifiedByQR': true,
//       }, SetOptions(merge: true));

//       if (!mounted) return;

//       // Show success dialog
//       showDialog(
//         context: context,
//         barrierDismissible: false,
//         builder: (ctx) => AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           title: const Row(
//             children: [
//               Icon(Icons.check_circle, color: Colors.green, size: 28),
//               SizedBox(width: 10),
//               Text('Success!'),
//             ],
//           ),
//           content: const Text(
//             'Your attendance has been successfully marked!\n\n'
//             '✅ Device verified\n'
//             '✅ Office WiFi verified\n'
//             '✅ QR code verified',
//             style: TextStyle(height: 1.5),
//           ),
//           actions: [
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: maroon,
//                 foregroundColor: Colors.white,
//               ),
//               onPressed: () {
//                 Navigator.pop(ctx); // Close dialog
//                 Navigator.pop(context); // Back to dashboard
//               },
//               child: const Text('OK'),
//             ),
//           ],
//         ),
//       );
//     } catch (e) {
//       debugPrint("Attendance save error: $e");
//       _showError('Error recording attendance: $e');
//     }
//   }

//   void _showError(String message) {
//     if (!mounted) return;

//     setState(() {
//       _isProcessing = false;
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//         duration: const Duration(seconds: 4),
//       ),
//     );

//     // Allow retry after 2 seconds
//     Future.delayed(const Duration(seconds: 2), () {
//       if (mounted) {
//         setState(() {
//           _hasScanned = false;
//         });
//         _controller.start();
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: maroon,
//         title: const Text(
//           'Scan Attendance QR',
//           style: TextStyle(color: Colors.white),
//         ),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: Column(
//         children: [
//           // Info banner
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             color: maroon.withOpacity(0.9),
//             child: const Column(
//               children: [
//                 Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
//                 SizedBox(height: 8),
//                 Text(
//                   'Point your camera at the QR code shown on office screen',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: Colors.white, fontSize: 14),
//                 ),
//               ],
//             ),
//           ),

//           // Scanner view
//           Expanded(
//             child: Stack(
//               alignment: Alignment.center,
//               children: [
//                 MobileScanner(
//                   controller: _controller,
//                   onDetect: (capture) {
//                     final barcodes = capture.barcodes;
//                     for (final barcode in barcodes) {
//                       final value = barcode.rawValue;
//                       if (value != null && value.isNotEmpty) {
//                         _handleScannedCode(value);
//                         break;
//                       }
//                     }
//                   },
//                 ),

//                 // Scan frame
//                 Container(
//                   width: 250,
//                   height: 250,
//                   decoration: BoxDecoration(
//                     border: Border.all(
//                       color: _isProcessing ? Colors.orange : Colors.green,
//                       width: 3,
//                     ),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                 ),

//                 // Processing overlay
//                 if (_isProcessing)
//                   Container(
//                     color: Colors.black87,
//                     child: const Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           CircularProgressIndicator(color: Colors.white),
//                           SizedBox(height: 16),
//                           Text(
//                             'Verifying attendance...',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 16,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),

//           // Device info at bottom
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             color: Colors.black87,
//             child: Column(
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(Icons.smartphone,
//                         color: Colors.white70, size: 14),
//                     const SizedBox(width: 6),
//                     Text(
//                       'Device: ${widget.currentDeviceId.length > 10 ? "${widget.currentDeviceId.substring(0, 10)}..." : widget.currentDeviceId}',
//                       style: const TextStyle(
//                           color: Colors.white70, fontSize: 12),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 4),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(Icons.wifi, color: Colors.white70, size: 14),
//                     const SizedBox(width: 6),
//                     Text(
//                       'WiFi: ${widget.currentBssid}',
//                       style: const TextStyle(
//                           color: Colors.white70, fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
// // import 'package:flutter/material.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:mobile_scanner/mobile_scanner.dart';

// // class QRScannerScreen extends StatelessWidget {
// //   final String currentBssid;
// //   final String currentDeviceId;

// //   const QRScannerScreen({super.key, required this.currentBssid, required this.currentDeviceId});

// //   @override
// //   Widget build(BuildContext context) {
// //     bool hasScanned = false;

// //     return Scaffold(
// //       appBar: AppBar(title: const Text('Scan Attendance QR Code')),
// //       body: MobileScanner(
// //         onDetect: (capture) {
// //           if (hasScanned) return;
// //           for (final barcode in capture.barcodes) {
// //             if (barcode.rawValue != null) {
// //               hasScanned = true;
// //               String scannedValue = barcode.rawValue!;

// //               if (scannedValue.startsWith('CDGAI-ATTENDANCE-')) {
// //                 _finalizeAttendanceRecord(context);
// //               } else {
// //                 ScaffoldMessenger.of(context).showSnackBar(
// //                   const SnackBar(content: Text('Invalid QR code scanned.')),
// //                 );
// //                 Navigator.pop(context);
// //               }
// //               break;
// //             }
// //           }
// //         },
// //       ),
// //     );
// //   }

// //   Future<void> _finalizeAttendanceRecord(BuildContext context) async {
// //     try {
// //       User? user = FirebaseAuth.instance.currentUser;
// //       String uid = user?.uid ?? 'anonymous_user';
// //       String todayDate = DateTime.now().toIso8601String().split('T')[0];

// //       // Strict ID construction format: attendance/{uid}_{yyyy-MM-dd}
// //       String docId = '${uid}_$todayDate';

// //       await FirebaseFirestore.instance.collection('attendance').doc(docId).set({
// //         'uid': uid,
// //         'date': todayDate,
// //         'checkinAt': FieldValue.serverTimestamp(), // Server timestamp security validation
// //         'checkinBssid': currentBssid,
// //         'deviceId': currentDeviceId,
// //         'status': 'present',
// //       }, SetOptions(merge: true));

// //       if (!context.mounted) return;
// //       showDialog(
// //         context: context,
// //         builder: (ctx) => AlertDialog(
// //           title: const Text('Attendance Recorded'),
// //           content: const Text('Your attendance was successfully marked through Wi-Fi and QR validation.'),
// //           actions: [
// //             TextButton(
// //               onPressed: () {
// //                 Navigator.pop(ctx);
// //                 Navigator.pop(context);
// //               },
// //               child: const Text('OK'),
// //             ),
// //           ],
// //         ),
// //       );
// //     } catch (e) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text('Error recording entry: $e')),
// //       );
// //     }
// //   }
// // }

// qr_scanner_screen.dart
// qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';

class QRScannerScreen extends StatefulWidget {
  final String currentBssid;
  final String currentDeviceId;

  const QRScannerScreen({
    super.key,
    required this.currentBssid,
    required this.currentDeviceId,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

enum ScanState { idle, processing, success, error }

class _QRScannerScreenState extends State<QRScannerScreen> {
  static const Color maroon = Color(0xFF800000);

  ScanState _scanState = ScanState.idle;
  String _statusMessage = '';
  bool _scanLock = false;

  final MobileScannerController _controller = MobileScannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _attendanceDocId(String uid) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${uid}_$today';
  }

  String _nameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'Intern';
    final localPart = email.split('@').first;
    return localPart
        .split(RegExp(r'[._\-]'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
        .join(' ');
  }

  /// Ensures /interns/{uid} exists AND has a valid email.
  ///
  /// CRITICAL FIX: Previously this only wrote to Firestore when the doc
  /// was missing entirely. Now it also updates existing docs whose email
  /// or name fields are empty, so old orphan profiles get self-healed
  /// on the next check-in.
  ///
  /// Additionally, it force-refreshes Firebase Auth before reading the
  /// email — sometimes user.email is null right after login until the
  /// token refreshes.
  Future<void> _ensureInternProfile(User user) async {
    try {
      // Force-refresh the user token so email/displayName are fresh
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser ?? user;

      final email = refreshedUser.email ?? '';
      final displayName = refreshedUser.displayName ?? '';
      final fallbackName =
          displayName.isNotEmpty ? displayName : _nameFromEmail(email);

      debugPrint('=== ENSURE PROFILE ===');
      debugPrint('UID: ${refreshedUser.uid}');
      debugPrint('Email from Auth: "$email"');
      debugPrint('DisplayName from Auth: "$displayName"');
      debugPrint('Computed name: "$fallbackName"');

      final profileRef = FirebaseFirestore.instance
          .collection('interns')
          .doc(refreshedUser.uid);

      final snap = await profileRef.get();

      if (!snap.exists) {
        // First time — create fresh profile
        await profileRef.set({
          'uid': refreshedUser.uid,
          'email': email,
          'name': fallbackName,
          'role': 'Intern',
          'team': 'General',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
          'lastCheckIn': FieldValue.serverTimestamp(),
        });
        debugPrint('=== CREATED profile for $fallbackName ($email) ===');
        return;
      }

      // Profile exists — patch any missing fields
      final data = snap.data() ?? {};
      final Map<String, dynamic> updates = {};

      final existingEmail = (data['email'] as String?) ?? '';
      final existingName = (data['name'] as String?) ?? '';

      // Update email if we have one from Auth and Firestore doesn't
      if (email.isNotEmpty && existingEmail.isEmpty) {
        updates['email'] = email;
        debugPrint('Patching email: "$email"');
      }

      // Update name if it's missing or is a generic UID-based placeholder
      if (fallbackName.isNotEmpty &&
          fallbackName != 'Intern' &&
          (existingName.isEmpty ||
              existingName.startsWith('Intern ') ||
              existingName == 'Unknown Intern' ||
              existingName == 'Intern')) {
        updates['name'] = fallbackName;
        debugPrint('Patching name: "$fallbackName"');
      }

      // Always update lastCheckIn
      updates['lastCheckIn'] = FieldValue.serverTimestamp();

      if (updates.isNotEmpty) {
        await profileRef.update(updates);
        debugPrint('=== UPDATED profile with ${updates.keys.toList()} ===');
      } else {
        debugPrint('Profile already complete, no updates needed.');
      }
    } catch (e, stack) {
      // Never block attendance if profile write fails
      debugPrint('Profile ensure error (non-fatal): $e\n$stack');
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_scanLock) return;
    _scanLock = true;

    final rawValue =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;

    if (rawValue == null || rawValue.trim().isEmpty) {
      _scanLock = false;
      return;
    }

    _handleScannedCode(rawValue.trim());
  }

  Future<void> _handleScannedCode(String scannedToken) async {
    _updateState(ScanState.processing, 'Verifying QR code...');
    await _controller.stop();

    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('=== AUTH CHECK ===');
      debugPrint('UID: ${user?.uid}');
      debugPrint('Email: ${user?.email}');
      debugPrint('DisplayName: ${user?.displayName}');

      if (user == null) {
        throw const QrVerificationException(
          'You are not logged in. Please login again.',
        );
      }

      // Self-heal /interns profile
      await _ensureInternProfile(user);

      // Verify QR token
      await _verifyQrToken(scannedToken);

      // Record attendance
      await _recordAttendance(user.uid);

      _updateState(ScanState.success, 'Attendance marked!');
      _showSuccessDialog();
    } on QrVerificationException catch (e) {
      _handleError(e.message);
    } on FirebaseException catch (e) {
      debugPrint('Firebase error: ${e.code} - ${e.message}');
      _handleError(_friendlyFirebaseError(e));
    } catch (e, stack) {
      debugPrint('Unexpected: ${e.runtimeType} - $e\n$stack');
      _handleError('Error: ${e.runtimeType} - $e');
    }
  }

  Future<void> _verifyQrToken(String scannedToken) async {
    final doc =
        await FirebaseFirestore.instance.collection('config').doc('qr').get();

    if (!doc.exists || doc.data() == null) {
      throw const QrVerificationException(
        'QR system not configured. Contact admin.',
      );
    }

    final data = doc.data()!;
    final storedToken = (data['token'] as String?)?.trim() ?? '';
    final expiresAtRaw = data['expiresAtMillis'];

    if (storedToken.isEmpty) {
      throw const QrVerificationException(
        'No active QR code found. Ask admin to generate one.',
      );
    }
    if (expiresAtRaw == null) {
      throw const QrVerificationException('QR expiry not configured.');
    }

    final int expiresAtMs;
    if (expiresAtRaw is num) {
      expiresAtMs = expiresAtRaw.toInt();
    } else if (expiresAtRaw is String) {
      expiresAtMs = int.tryParse(expiresAtRaw) ?? 0;
    } else if (expiresAtRaw is Timestamp) {
      expiresAtMs = expiresAtRaw.millisecondsSinceEpoch;
    } else {
      throw QrVerificationException(
        'Invalid expiry type: ${expiresAtRaw.runtimeType}',
      );
    }

    if (scannedToken != storedToken) {
      throw const QrVerificationException(
        'Invalid QR code. Please scan the current QR on the office screen.',
      );
    }
    if (DateTime.now().millisecondsSinceEpoch >= expiresAtMs) {
      throw const QrVerificationException(
        'QR code has expired. Please wait for the next one.',
      );
    }
  }

  Future<void> _recordAttendance(String uid) async {
    final docId = _attendanceDocId(uid);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final docRef =
        FirebaseFirestore.instance.collection('attendance').doc(docId);

    final existing = await docRef.get();
    if (existing.exists) {
      final data = existing.data();
      if (data != null && data['checkInAt'] != null) {
        throw const QrVerificationException(
          'Attendance already marked for today.',
        );
      }
    }

    await docRef.set({
      'uid': uid,
      'date': today,
      'checkInAt': FieldValue.serverTimestamp(),
      'checkinBssid': widget.currentBssid,
      'deviceId': widget.currentDeviceId,
      'verifiedByQR': true,
    });

    debugPrint('=== ATTENDANCE WRITE SUCCESS ===');
  }

  String _friendlyFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Permission denied by Firestore rules.';
      case 'unauthenticated':
        return 'Session expired. Please login again.';
      case 'unavailable':
        return 'Firebase unavailable. Check your internet.';
      case 'not-found':
        return 'Required document not found: ${e.message}';
      default:
        return 'Firebase error (${e.code}): ${e.message ?? 'Unknown'}';
    }
  }

  void _updateState(ScanState state, [String message = '']) {
    if (!mounted) return;
    setState(() {
      _scanState = state;
      _statusMessage = message;
    });
  }

  void _handleError(String message) {
    _updateState(ScanState.error, message);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _scanLock = false;
      _updateState(ScanState.idle);
      _controller.start();
    });
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Attendance Marked'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your attendance has been recorded.'),
            SizedBox(height: 12),
            _CheckItem(label: 'Device verified'),
            _CheckItem(label: 'Office WiFi verified'),
            _CheckItem(label: 'QR code verified'),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: maroon,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _scanState == ScanState.processing;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: maroon,
        title: const Text('Scan Attendance QR',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: maroon.withOpacity(0.9),
            child: Column(
              children: [
                Icon(
                  isProcessing ? Icons.hourglass_top : Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  isProcessing
                      ? 'Processing your attendance...'
                      : 'Point your camera at the QR code shown on the office screen',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onBarcodeDetected,
                ),
                IgnorePointer(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isProcessing ? Colors.orange : Colors.green,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: Colors.white),
                            const SizedBox(height: 16),
                            Text(
                              _statusMessage,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.smartphone,
                  label: 'Device: '
                      '${widget.currentDeviceId.length > 10 ? "${widget.currentDeviceId.substring(0, 10)}..." : widget.currentDeviceId}',
                ),
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.wifi,
                  label: 'WiFi: ${widget.currentBssid}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QrVerificationException implements Exception {
  final String message;
  const QrVerificationException(this.message);
  @override
  String toString() => message;
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String label;
  const _CheckItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
