import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';
import 'password_reset_screen.dart';

// Initialize Firebase with your web configuration
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyC6ARAUH5AupQRQ5I1FKMmjW8D36PSvWFQ",
      authDomain: "intern-attendance-system.firebaseapp.com",
      projectId: "intern-attendance-system",
      storageBucket: "intern-attendance-system.appspot.com",
      messagingSenderId: "10008456431",
      appId: "1:10008456431:web:36961ea81cfc4550743f1a",
    ),
  );
  runApp(const AttendXApp());
}

class AttendXApp extends StatelessWidget {
  const AttendXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AttendX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ==================== 2. ATTENDANCE DASHBOARD ====================
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _statusMessage = 'Ready to verify and mark attendance';
  bool _isLoading = false;

  Future<void> _verifyAndProceed() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking device permissions...';
    });

    try {
      await [Permission.location, Permission.camera].request();

      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String deviceId = 'web_browser_client';
      if (!Uri.base.hasAuthority) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      }

      setState(() => _statusMessage = 'Verifying office Wi-Fi network...');

      final NetworkInfo networkInfo = NetworkInfo();
      String? bssid = await networkInfo.getWifiBSSID();
      bssid ??= 'mock_office_bssid';

      DocumentSnapshot configDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('attendance')
          .get();

      if (configDoc.exists) {
        List<dynamic> allowedBssids = configDoc.get('allowedBssids') ?? [];
        if (allowedBssids.isNotEmpty && !allowedBssids.contains(bssid)) {
          setState(() {
            _statusMessage =
                'Access Blocked: Not connected to authorized office Wi-Fi.';
            _isLoading = false;
          });
          return;
        }
      }

      setState(() => _isLoading = false);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              QRScannerScreen(currentBssid: bssid!, currentDeviceId: deviceId),
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error during validation: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const maroon = Color(0xFF800000);

    return Scaffold(
      backgroundColor: maroon,
      appBar: AppBar(
        backgroundColor: maroon,
        elevation: 0,
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Stack(
        children: [
          Container(color: maroon),
          const Center(
            child: Opacity(
              opacity: 0.08,
              child: Text(
                'CDGAI',
                style: TextStyle(
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ATTENDANCE PAGE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : ElevatedButton.icon(
                          onPressed: _verifyAndProceed,
                          icon:
                              const Icon(Icons.qr_code_scanner, color: maroon),
                          label: const Text(
                            'Start Check-In (Wi-Fi + QR)',
                            style: TextStyle(
                                color: maroon, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:network_info_plus/network_info_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'login_screen.dart';
// import 'qr_scanner_screen.dart';
// import 'password_reset_screen.dart';

// // Initialize Firebase with your web configuration
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: const FirebaseOptions(
//       apiKey: "AIzaSyC6ARAUH5AupQRQ5I1FKMmjW8D36PSvWFQ",
//       authDomain: "intern-attendance-system.firebaseapp.com",
//       projectId: "intern-attendance-system",
//       storageBucket: "intern-attendance-system.appspot.com",
//       messagingSenderId: "10008456431",
//       appId: "1:10008456431:web:36961ea81cfc4550743f1a",
//     ),
//   );
//   runApp(const InternAttendanceApp());
// }

// class InternAttendanceApp extends StatelessWidget {
//   const InternAttendanceApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'CDGAI Intern Attendance Portal',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         useMaterial3: true,
//       ),
//       home: const LoginScreen(),
//     );
//   }
// }

// // ==================== 2. ATTENDANCE DASHBOARD ====================
// class AttendanceScreen extends StatefulWidget {
//   const AttendanceScreen({super.key});

//   @override
//   State<AttendanceScreen> createState() => _AttendanceScreenState();
// }

// class _AttendanceScreenState extends State<AttendanceScreen> {
//   String _statusMessage = 'Ready to verify and mark attendance';
//   bool _isLoading = false;

//   Future<void> _verifyAndProceed() async {
//     setState(() {
//       _isLoading = true;
//       _statusMessage = 'Checking device permissions...';
//     });

//     try {
//       await [Permission.location, Permission.camera].request();

//       final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
//       String deviceId = 'web_browser_client';
//       if (!Uri.base.hasAuthority) {
//         AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//         deviceId = androidInfo.id;
//       }

//       setState(() => _statusMessage = 'Verifying office Wi-Fi network...');

//       final NetworkInfo networkInfo = NetworkInfo();
//       String? bssid = await networkInfo.getWifiBSSID();
//       bssid ??= 'mock_office_bssid';

//       DocumentSnapshot configDoc = await FirebaseFirestore.instance
//           .collection('config')
//           .doc('attendance')
//           .get();

//       if (configDoc.exists) {
//         List<dynamic> allowedBssids = configDoc.get('allowedBssids') ?? [];
//         if (allowedBssids.isNotEmpty && !allowedBssids.contains(bssid)) {
//           setState(() {
//             _statusMessage =
//                 'Access Blocked: Not connected to authorized office Wi-Fi.';
//             _isLoading = false;
//           });
//           return;
//         }
//       }

//       setState(() => _isLoading = false);

//       if (!mounted) return;
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) =>
//               QRScannerScreen(currentBssid: bssid!, currentDeviceId: deviceId),
//         ),
//       );
//     } catch (e) {
//       setState(() {
//         _statusMessage = 'Error during validation: $e';
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     const maroon = Color(0xFF800000);

//     return Scaffold(
//       backgroundColor: maroon,
//       appBar: AppBar(
//         backgroundColor: maroon,
//         elevation: 0,
//         title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout, color: Colors.white),
//             onPressed: () => FirebaseAuth.instance.signOut(),
//           )
//         ],
//       ),
//       body: Stack(
//         children: [
//           Container(color: maroon),
//           const Center(
//             child: Opacity(
//               opacity: 0.08,
//               child: Text(
//                 'CDGAI',
//                 style: TextStyle(
//                   fontSize: 100,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//           Center(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const Text(
//                     'Dashboard',
//                     style: TextStyle(
//                       fontSize: 32,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   const Text(
//                     'ATTENDANCE PAGE',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(height: 24),
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 18, vertical: 14),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.16),
//                       borderRadius: BorderRadius.circular(14),
//                       border: Border.all(color: Colors.white24),
//                     ),
//                     child: Text(
//                       _statusMessage,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         color: Colors.white,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 30),
//                   _isLoading
//                       ? const CircularProgressIndicator(color: Colors.white)
//                       : ElevatedButton.icon(
//                           onPressed: _verifyAndProceed,
//                           icon:
//                               const Icon(Icons.qr_code_scanner, color: maroon),
//                           label: const Text(
//                             'Start Check-In (Wi-Fi + QR)',
//                             style: TextStyle(
//                                 color: maroon, fontWeight: FontWeight.bold),
//                           ),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.white,
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 24, vertical: 14),
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12)),
//                           ),
//                         ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
