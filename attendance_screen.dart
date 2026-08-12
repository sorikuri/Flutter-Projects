// // dashboard_screen.dart
// import 'dart:io' show Platform;
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:network_info_plus/network_info_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:intl/intl.dart';
// import 'login_screen.dart';
// import 'qr_scanner_screen.dart';

// class DashboardScreen extends StatefulWidget {
//   final String userName;

//   const DashboardScreen({super.key, required this.userName});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   int _selectedIndex = 0;
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

//   // Colors
//   static const Color maroon = Color(0xFF800000);
//   static const Color lightBg = Color(0xFFFAFAFA);
//   static const Color darkText = Color(0xFF2C2C2C);

//   // Attendance Terminal State
//   String _statusMessage = 'Ready to verify and mark attendance';
//   bool _isLoading = false;

//   // Month Tracking for History
//   final List<String> _monthNames = const [
//     'January',
//     'February',
//     'March',
//     'April',
//     'May',
//     'June',
//     'July',
//     'August',
//     'September',
//     'October',
//     'November',
//     'December'
//   ];
//   late List<String> _monthsList;
//   late String _selectedMonth;

//   @override
//   void initState() {
//     super.initState();
//     final now = DateTime.now();
//     final currentMonthName = _monthNames[now.month - 1];
//     final currentFormattedMonth = '$currentMonthName ${now.year}';

//     _monthsList = _monthNames.map((m) => '$m ${now.year}').toList();

//     if (_monthsList.contains(currentFormattedMonth)) {
//       _selectedMonth = currentFormattedMonth;
//     } else {
//       _monthsList.insert(0, currentFormattedMonth);
//       _selectedMonth = currentFormattedMonth;
//     }
//   }

//   // --- LOGOUT ---
//   Future<void> _handleLogout() async {
//     await FirebaseAuth.instance.signOut();
//     if (!mounted) return;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => const LoginScreen()),
//     );
//   }

//   // --- CHECK-IN LOGIC (FIXED) ---
//   Future<void> _verifyAndProceed() async {
//     // 1. Check leave status first
//     try {
//       final leaveApproved = await _isTodayApprovedLeave();
//       if (leaveApproved) {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//                 'Leave is already approved for today. Attendance is not required.'),
//             backgroundColor: Colors.green,
//           ),
//         );
//         return;
//       }
//     } catch (e) {
//       debugPrint('Error checking leave status: $e');
//     }

//     setState(() {
//       _isLoading = true;
//       _statusMessage = 'Checking device permissions...';
//     });

//     try {
//       // 2. Request permissions safely
//       try {
//         await [Permission.location, Permission.camera].request();
//       } catch (e) {
//         debugPrint('Permission request error: $e');
//       }

//       // 3. Get Device ID (FIXED - now works on real Android)
//       String deviceId = 'unknown_device';
//       try {
//         final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

//         if (Platform.isAndroid) {
//           AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
//           deviceId = androidInfo.id; // Real Android ID
//           debugPrint('=== Android Device ID: $deviceId ===');
//         } else if (Platform.isIOS) {
//           IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
//           deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
//           debugPrint('=== iOS Device ID: $deviceId ===');
//         } else {
//           deviceId = 'unsupported_platform';
//         }
//       } catch (e) {
//         debugPrint('Error getting Device ID: $e');
//         deviceId = 'unknown_device_error';
//       }

//       // Validate device ID exists
//       if (deviceId == 'unknown_device' ||
//           deviceId == 'unknown_device_error' ||
//           deviceId.isEmpty) {
//         setState(() {
//           _statusMessage =
//               'Access Blocked: Unable to identify device. Please check permissions.';
//           _isLoading = false;
//         });

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text(
//                   'Cannot identify device. Please grant required permissions.'),
//               backgroundColor: Colors.red,
//               duration: Duration(seconds: 5),
//             ),
//           );
//         }
//         return;
//       }

//       setState(() => _statusMessage = 'Verifying office Wi-Fi network...');

//       // 4. Get Wi-Fi BSSID safely
//       String? bssid;
//       try {
//         final NetworkInfo networkInfo = NetworkInfo();
//         bssid = await networkInfo.getWifiBSSID();
//         debugPrint('=== DETECTED BSSID: $bssid ===');
//       } catch (e) {
//         debugPrint('Error fetching Wi-Fi BSSID: $e');
//       }

//       // Do not allow fallback - require real Wi-Fi BSSID
//       if (bssid == null || bssid.isEmpty) {
//         setState(() {
//           _statusMessage =
//               'Access Blocked: Unable to detect office Wi-Fi. Please connect to the office network.';
//           _isLoading = false;
//         });

//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text(
//                   'Unable to detect Wi-Fi BSSID. Connect to office Wi-Fi to mark attendance.'),
//               backgroundColor: Colors.red,
//               duration: Duration(seconds: 6),
//             ),
//           );
//         }
//         return;
//       }

//       // 5. Show detected BSSID popup
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Detected BSSID: $bssid'),
//             backgroundColor: Colors.blue,
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }

//       // 6. Check Firestore configuration
//       DocumentSnapshot configDoc = await FirebaseFirestore.instance
//           .collection('config')
//           .doc('attendance')
//           .get();

//       if (configDoc.exists) {
//         final data = configDoc.data() as Map<String, dynamic>? ?? {};
//         final List<dynamic> allowedBssids =
//             data['allowedBssids'] as List<dynamic>? ?? [];

//         debugPrint('=== Allowed BSSIDs: $allowedBssids ===');

//         // Case-insensitive BSSID check
//         final normalizedBssid = bssid.toUpperCase();
//         final normalizedAllowed =
//             allowedBssids.map((b) => b.toString().toUpperCase()).toList();

//         // Check if list is restricted and current BSSID is not inside
//         if (normalizedAllowed.isNotEmpty &&
//             !normalizedAllowed.contains(normalizedBssid)) {
//           setState(() {
//             _statusMessage =
//                 'Access Blocked: Not connected to authorized office Wi-Fi.';
//             _isLoading = false;
//           });

//           if (mounted) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text(
//                     'Blocked: BSSID "$bssid" is not authorized in Firebase.'),
//                 backgroundColor: Colors.red,
//                 duration: const Duration(seconds: 6),
//               ),
//             );
//           }
//           return;
//         }
//       }

//       setState(() => _isLoading = false);

//       // 7. Proceed to Scanner
//       if (!mounted) return;
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => QRScannerScreen(
//             currentBssid: bssid!,
//             currentDeviceId: deviceId,
//           ),
//         ),
//       );
//     } catch (e) {
//       debugPrint('Global error during validation: $e');
//       setState(() {
//         _statusMessage = 'Error during validation: $e';
//         _isLoading = false;
//       });

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Validation Error: $e'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 5),
//           ),
//         );
//       }
//     }
//   }

//   // --- CHECK-OUT LOGIC ---
//   Future<void> _handleCheckOut() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     final now = DateTime.now();
//     final todayId = DateFormat('yyyy-MM-dd').format(now);

//     final docRef = FirebaseFirestore.instance
//         .collection('users')
//         .doc(user.uid)
//         .collection('attendance')
//         .doc(todayId);

//     final docSnap = await docRef.get();

//     if (!docSnap.exists || docSnap.data()?['checkInTime'] == null) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Cannot check out: You have not checked in today!'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     if (docSnap.data()?['checkOutTime'] != null) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('You have already checked out for today.'),
//           backgroundColor: Colors.blue,
//         ),
//       );
//       return;
//     }

//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Confirm Check-Out',
//             style: TextStyle(color: darkText, fontWeight: FontWeight.bold)),
//         content: Text(
//             'Timestamp: ${DateFormat('hh:mm a - MMM dd, yyyy').format(now)}\n\nDo you want to proceed?',
//             style: const TextStyle(color: darkText)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: maroon,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//             child:
//                 const Text('Check-Out', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );

//     if (confirm != true) return;

//     setState(() => _isLoading = true);

//     try {
//       await docRef.update({
//         'checkOutTime': FieldValue.serverTimestamp(),
//         'status': 'Completed',
//       });

//       if (!mounted) return;

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Successfully checked-out'),
//           backgroundColor: Colors.green,
//         ),
//       );

//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//           _statusMessage = 'You have checked out successfully.';
//           _selectedIndex = 0;
//         });
//       }
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Error recording check-out: $e'),
//             backgroundColor: Colors.red),
//       );
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   // Active View Generator
//   Widget _buildBodyContent() {
//     switch (_selectedIndex) {
//       case 0:
//         return _buildHomePage();
//       case 1:
//         return _buildCheckInTab();
//       case 2:
//         return _buildAttendanceHistoryTab();
//       case 3:
//         return _buildNotificationsTab();
//       case 4:
//         return _buildSettingsTab();
//       default:
//         return _buildHomePage();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final List<String> pageTitles = [
//       'Portal Home',
//       'Attendance Terminal',
//       'Attendance History',
//       'Notifications',
//       'Settings'
//     ];

//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: lightBg,
//       drawer: _buildSlideDrawer(),
//       body: Stack(
//         children: [
//           // Background Header Design Wave
//           ClipPath(
//             clipper: WavyHeaderClipper(),
//             child: Container(
//               height: 250,
//               width: double.infinity,
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [maroon, Color(0xFFA01A1A)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Column(
//               children: [
//                 // Top Custom Navigation Bar
//                 Padding(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 16.0, vertical: 8.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.menu,
//                             color: Colors.white, size: 28),
//                         onPressed: () =>
//                             _scaffoldKey.currentState?.openDrawer(),
//                       ),
//                       Text(
//                         pageTitles[_selectedIndex],
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.logout,
//                             color: Colors.white, size: 24),
//                         onPressed: _handleLogout,
//                       ),
//                     ],
//                   ),
//                 ),
//                 // Dynamic View Section
//                 Expanded(
//                   child: _buildBodyContent(),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // --- DRAWER NAVIGATION ---
//   Widget _buildSlideDrawer() {
//     final user = FirebaseAuth.instance.currentUser;

//     return Drawer(
//       child: Container(
//         color: lightBg,
//         child: ListView(
//           padding: EdgeInsets.zero,
//           children: [
//             StreamBuilder<DocumentSnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('users')
//                   .doc(user?.uid)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 String name =
//                     widget.userName.isNotEmpty ? widget.userName : 'User';
//                 String role = 'Intern';
//                 if (snapshot.hasData && snapshot.data!.exists) {
//                   final data = snapshot.data!.data() as Map<String, dynamic>?;
//                   if (data?['fullName'] != null &&
//                       (data!['fullName'] as String).isNotEmpty) {
//                     name = data['fullName'];
//                   } else if (data?['name'] != null &&
//                       (data!['name'] as String).isNotEmpty) {
//                     name = data['name'];
//                   }
//                   role = data?['role'] ?? 'Intern';
//                 }
//                 return DrawerHeader(
//                   decoration: const BoxDecoration(
//                     color: maroon,
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       CircleAvatar(
//                         radius: 30,
//                         backgroundColor: Colors.white,
//                         child: Text(
//                           name.isNotEmpty ? name[0].toUpperCase() : 'U',
//                           style: const TextStyle(
//                               fontSize: 26,
//                               color: maroon,
//                               fontWeight: FontWeight.bold),
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       Text(name,
//                           style: const TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.bold,
//                               fontSize: 18)),
//                       Text('$role | ${user?.email ?? ''}',
//                           style: const TextStyle(
//                               color: Colors.white70, fontSize: 12)),
//                     ],
//                   ),
//                 );
//               },
//             ),
//             _buildDrawerTile(0, 'Home', Icons.home_rounded),
//             _buildDrawerTile(1, 'Mark Attendance', Icons.fingerprint),
//             _buildDrawerTile(2, 'Attendance History', Icons.history_rounded),
//             _buildDrawerTile(3, 'Notifications', Icons.notifications_rounded),
//             _buildDrawerTile(4, 'Settings', Icons.settings_rounded),
//             const Divider(color: Colors.black12),
//             ListTile(
//               leading: const Icon(Icons.logout, color: maroon),
//               title: const Text('Logout',
//                   style:
//                       TextStyle(color: darkText, fontWeight: FontWeight.w600)),
//               onTap: _handleLogout,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDrawerTile(int index, String title, IconData icon) {
//     final isSelected = _selectedIndex == index;
//     return ListTile(
//       selected: isSelected,
//       selectedTileColor: maroon.withOpacity(0.1),
//       leading: Icon(icon, color: isSelected ? maroon : Colors.grey.shade700),
//       title: Text(
//         title,
//         style: TextStyle(
//           color: isSelected ? maroon : darkText,
//           fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
//         ),
//       ),
//       onTap: () {
//         setState(() => _selectedIndex = index);
//         Navigator.pop(context);
//       },
//     );
//   }

//   // --- PAGE 1: HOME PAGE ---
//   Widget _buildHomePage() {
//     final user = FirebaseAuth.instance.currentUser;

//     return StreamBuilder<DocumentSnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('users')
//           .doc(user?.uid)
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator(color: maroon));
//         }

//         final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

//         // Priority: Firestore fullName -> name -> widget.userName -> Default
//         String name = data['fullName'] ?? data['name'] ?? '';
//         if (name.isEmpty) {
//           name = widget.userName.isNotEmpty ? widget.userName : 'Intern Name';
//         }

//         final role = data['role'] ?? 'Intern';
//         final department = data['department'] ?? 'Flutter Frontend Development';

//         return SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 10),
//               // Profile Header Card
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(20),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.06),
//                       blurRadius: 15,
//                       offset: const Offset(0, 5),
//                     )
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     CircleAvatar(
//                       radius: 32,
//                       backgroundColor: maroon.withOpacity(0.1),
//                       child: const Icon(Icons.person, size: 38, color: maroon),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Welcome back,',
//                             style: TextStyle(
//                                 color: Colors.grey.shade600, fontSize: 13),
//                           ),
//                           Text(
//                             name,
//                             style: const TextStyle(
//                               color: darkText,
//                               fontSize: 20,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 6),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 10, vertical: 4),
//                             decoration: BoxDecoration(
//                               color: maroon,
//                               borderRadius: BorderRadius.circular(20),
//                             ),
//                             child: Text(
//                               role,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 11,
//                               ),
//                             ),
//                           )
//                         ],
//                       ),
//                     )
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 24),
//               const Text(
//                 'Quick Overview',
//                 style: TextStyle(
//                     color: darkText, fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 12),
//               Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(20),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.04),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     )
//                   ],
//                 ),
//                 child: Column(
//                   children: [
//                     _buildProfileDetailRow(
//                         Icons.business_rounded, 'Department', department),
//                     const Divider(color: Colors.black12, height: 24),
//                     _buildProfileDetailRow(Icons.email_rounded, 'Email Address',
//                         user?.email ?? 'N/A'),
//                     const Divider(color: Colors.black12, height: 24),
//                     _buildProfileDetailRow(
//                         Icons.calendar_today_rounded,
//                         'Today',
//                         DateFormat('EEEE, MMM dd, yyyy')
//                             .format(DateTime.now())),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 22),
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(20),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.04),
//                       blurRadius: 10,
//                       offset: const Offset(0, 4),
//                     )
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.beach_access_rounded,
//                             color: maroon, size: 26),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Text(
//                             'Leave Application',
//                             style: TextStyle(
//                               color: darkText,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       'Submit an e-application for leave. Once approved by admin, that day will be marked as Leave Approved instead of regular attendance.',
//                       style:
//                           TextStyle(color: Colors.grey.shade700, fontSize: 14),
//                     ),
//                     const SizedBox(height: 18),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 48,
//                       child: ElevatedButton.icon(
//                         icon:
//                             const Icon(Icons.send_rounded, color: Colors.white),
//                         label: const Text('Apply for Leave',
//                             style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold)),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: maroon,
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(14)),
//                         ),
//                         onPressed: () => _showLeaveApplicationModal(context),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 22),
//               StreamBuilder<QuerySnapshot>(
//                 stream: user == null
//                     ? const Stream<QuerySnapshot>.empty()
//                     : FirebaseFirestore.instance
//                         .collection('leaves')
//                         .where('userId', isEqualTo: user.uid)
//                         .orderBy('createdAt', descending: true)
//                         .limit(4)
//                         .snapshots(),
//                 builder: (context, leaveSnapshot) {
//                   if (leaveSnapshot.connectionState ==
//                       ConnectionState.waiting) {
//                     return Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.04),
//                             blurRadius: 12,
//                             offset: const Offset(0, 4),
//                           ),
//                         ],
//                       ),
//                       child: const Center(
//                         child: CircularProgressIndicator(color: maroon),
//                       ),
//                     );
//                   }

//                   final leaveDocs = leaveSnapshot.data?.docs ?? [];
//                   final today = DateTime.now();
//                   final todayApproved = leaveDocs.any((doc) {
//                     final data = doc.data() as Map<String, dynamic>;
//                     final Timestamp? startDate =
//                         data['startDate'] as Timestamp?;
//                     if (startDate == null) return false;
//                     final date = startDate.toDate();
//                     return date.year == today.year &&
//                         date.month == today.month &&
//                         date.day == today.day &&
//                         data['status'] == 'Approved';
//                   });
//                   final todayPending = leaveDocs.any((doc) {
//                     final data = doc.data() as Map<String, dynamic>;
//                     final Timestamp? startDate =
//                         data['startDate'] as Timestamp?;
//                     if (startDate == null) return false;
//                     final date = startDate.toDate();
//                     return date.year == today.year &&
//                         date.month == today.month &&
//                         date.day == today.day &&
//                         data['status'] == 'Pending';
//                   });

//                   return Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(20),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.04),
//                           blurRadius: 10,
//                           offset: const Offset(0, 4),
//                         ),
//                       ],
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Leave Status',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                             color: darkText,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           todayApproved
//                               ? 'Today\'s leave has been approved. Attendance won\'t be required.'
//                               : todayPending
//                                   ? 'Your leave application for today is pending approval.'
//                                   : 'No leave application exists for today.',
//                           style: TextStyle(
//                               color: Colors.grey.shade700, fontSize: 14),
//                         ),
//                         const SizedBox(height: 16),
//                         if (leaveDocs.isEmpty)
//                           Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               color: Colors.grey.shade50,
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                             child: const Text(
//                               'You currently have no recent leave applications. Use the button above to submit one.',
//                               style: TextStyle(color: Colors.black87),
//                             ),
//                           )
//                         else
//                           Column(
//                             children: leaveDocs.map((doc) {
//                               final data = doc.data() as Map<String, dynamic>;
//                               final Timestamp? startDate =
//                                   data['startDate'] as Timestamp?;
//                               final dateText = startDate != null
//                                   ? DateFormat('EEE, MMM dd, yyyy')
//                                       .format(startDate.toDate())
//                                   : 'Unknown Date';
//                               final status = data['status'] ?? 'Pending';

//                               return Container(
//                                 margin: const EdgeInsets.only(bottom: 12),
//                                 padding: const EdgeInsets.all(14),
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey.shade50,
//                                   borderRadius: BorderRadius.circular(16),
//                                   border:
//                                       Border.all(color: Colors.grey.shade200),
//                                 ),
//                                 child: Row(
//                                   children: [
//                                     CircleAvatar(
//                                       radius: 20,
//                                       backgroundColor: status == 'Approved'
//                                           ? Colors.green.shade100
//                                           : Colors.orange.shade100,
//                                       child: Icon(
//                                         status == 'Approved'
//                                             ? Icons.check_circle
//                                             : Icons.hourglass_bottom,
//                                         color: status == 'Approved'
//                                             ? Colors.green.shade800
//                                             : Colors.orange.shade800,
//                                       ),
//                                     ),
//                                     const SizedBox(width: 12),
//                                     Expanded(
//                                       child: Column(
//                                         crossAxisAlignment:
//                                             CrossAxisAlignment.start,
//                                         children: [
//                                           Text(
//                                             data['subject'] ??
//                                                 'Leave Application',
//                                             style: const TextStyle(
//                                               fontWeight: FontWeight.bold,
//                                               color: darkText,
//                                             ),
//                                           ),
//                                           const SizedBox(height: 4),
//                                           Text(
//                                             dateText,
//                                             style: TextStyle(
//                                                 color: Colors.grey.shade600,
//                                                 fontSize: 13),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     Container(
//                                       padding: const EdgeInsets.symmetric(
//                                           horizontal: 10, vertical: 6),
//                                       decoration: BoxDecoration(
//                                         color: status == 'Approved'
//                                             ? Colors.green.shade50
//                                             : Colors.orange.shade50,
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       child: Text(
//                                         status.toString().toUpperCase(),
//                                         style: TextStyle(
//                                           color: status == 'Approved'
//                                               ? Colors.green.shade800
//                                               : Colors.orange.shade800,
//                                           fontWeight: FontWeight.bold,
//                                           fontSize: 11,
//                                         ),
//                                       ),
//                                     )
//                                   ],
//                                 ),
//                               );
//                             }).toList(),
//                           ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildProfileDetailRow(IconData icon, String label, String value) {
//     return Row(
//       children: [
//         Icon(icon, color: maroon, size: 20),
//         const SizedBox(width: 12),
//         Text(label,
//             style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
//         const Spacer(),
//         Expanded(
//           child: Text(
//             value,
//             textAlign: TextAlign.end,
//             style: const TextStyle(
//                 color: darkText, fontWeight: FontWeight.bold, fontSize: 14),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     );
//   }

//   // --- PAGE 2: CHECK-IN / CHECK-OUT ---
//   Widget _buildCheckInTab() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           const SizedBox(height: 10),
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(20),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.05),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 )
//               ],
//             ),
//             child: Column(
//               children: [
//                 const Icon(Icons.verified_user_rounded,
//                     color: maroon, size: 36),
//                 const SizedBox(height: 8),
//                 Text(
//                   _statusMessage,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     color: darkText,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 30),
//           if (_isLoading)
//             const Padding(
//               padding: EdgeInsets.all(30.0),
//               child: CircularProgressIndicator(color: maroon),
//             )
//           else
//             GridView.count(
//               crossAxisCount: 2,
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               crossAxisSpacing: 16,
//               mainAxisSpacing: 16,
//               childAspectRatio: 1.0,
//               children: [
//                 _buildActionCard(
//                   title: 'Check-In',
//                   icon: Icons.fingerprint,
//                   iconColor: const Color(0xFF2E7D32),
//                   onTap: _verifyAndProceed,
//                 ),
//                 _buildActionCard(
//                   title: 'Check-Out',
//                   icon: Icons.exit_to_app_rounded,
//                   iconColor: maroon,
//                   onTap: _handleCheckOut,
//                 ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionCard({
//     required String title,
//     required IconData icon,
//     required Color iconColor,
//     required VoidCallback onTap,
//   }) {
//     return Material(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(20),
//       elevation: 2,
//       shadowColor: Colors.black12,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(20),
//         child: Container(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircleAvatar(
//                 radius: 28,
//                 backgroundColor: iconColor.withOpacity(0.1),
//                 child: Icon(icon, size: 32, color: iconColor),
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: iconColor,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Approval of the leave aftermath
//   Future<bool> _isTodayApprovedLeave() async {
//     final user = FirebaseAuth.instance.currentUser;
//     final now = DateTime.now();
//     final startOfDay = DateTime(now.year, now.month, now.day);
//     final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

//     final query = await FirebaseFirestore.instance
//         .collection('leaves')
//         .where('userId', isEqualTo: user?.uid)
//         .where('status', isEqualTo: 'Approved')
//         .where('startDate',
//             isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
//         .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
//         .get();

//     return query.docs.isNotEmpty;
//   }

//   // --- PAGE 3: HISTORY TAB ---
//   Widget _buildAttendanceHistoryTab() {
//     final user = FirebaseAuth.instance.currentUser;

//     if (user == null) {
//       return const Center(
//         child: Text('Please log in to view history.',
//             style: TextStyle(color: darkText)),
//       );
//     }

//     return SingleChildScrollView(
//       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Monthly Summary',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(color: Colors.grey.shade300),
//                 ),
//                 child: DropdownButtonHideUnderline(
//                   child: DropdownButton<String>(
//                     value: _selectedMonth,
//                     dropdownColor: Colors.white,
//                     icon: const Icon(Icons.arrow_drop_down, color: maroon),
//                     style: const TextStyle(
//                         color: darkText, fontWeight: FontWeight.bold),
//                     onChanged: (String? newValue) {
//                       if (newValue != null) {
//                         setState(() => _selectedMonth = newValue);
//                       }
//                     },
//                     items: _monthsList
//                         .map<DropdownMenuItem<String>>((String value) {
//                       return DropdownMenuItem<String>(
//                         value: value,
//                         child: Text(value),
//                       );
//                     }).toList(),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           StreamBuilder<QuerySnapshot>(
//             stream: FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .collection('attendance')
//                 .orderBy('checkInTime', descending: true)
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(
//                     child: CircularProgressIndicator(color: maroon));
//               }

//               final docs = snapshot.data?.docs ?? [];

//               final filteredDocs = docs.where((doc) {
//                 final data = doc.data() as Map<String, dynamic>;
//                 final Timestamp? timestamp = data['checkInTime'] as Timestamp?;
//                 if (timestamp == null) return false;

//                 final date = timestamp.toDate();
//                 final monthYearStr =
//                     '${_monthNames[date.month - 1]} ${date.year}';
//                 return monthYearStr == _selectedMonth;
//               }).toList();

//               int presentCount = filteredDocs.length;

//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   GridView.count(
//                     crossAxisCount: 2,
//                     crossAxisSpacing: 12,
//                     mainAxisSpacing: 12,
//                     childAspectRatio: 1.5,
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     children: [
//                       _buildColoredStatCard(
//                         'Total Attended',
//                         '$presentCount Days',
//                         Icons.check_circle_outline,
//                         Colors.green.shade50,
//                         Colors.green.shade800,
//                       ),
//                       _buildColoredStatCard(
//                         'Absents',
//                         '0 Days',
//                         Icons.cancel_outlined,
//                         Colors.red.shade50,
//                         Colors.red.shade800,
//                       ),
//                       StreamBuilder<QuerySnapshot>(
//                         stream: FirebaseFirestore.instance
//                             .collection('leaves')
//                             .where('userId', isEqualTo: user.uid)
//                             .where('status', isEqualTo: 'Approved')
//                             .where('startDate',
//                                 isGreaterThanOrEqualTo: Timestamp.fromDate(
//                                   DateTime(
//                                     int.parse(_selectedMonth.split(' ')[1]),
//                                     _monthNames.indexOf(
//                                             _selectedMonth.split(' ')[0]) +
//                                         1,
//                                     1,
//                                   ),
//                                 ))
//                             .where('startDate',
//                                 isLessThanOrEqualTo: Timestamp.fromDate(
//                                   DateTime(
//                                     int.parse(_selectedMonth.split(' ')[1]),
//                                     _monthNames.indexOf(
//                                             _selectedMonth.split(' ')[0]) +
//                                         2,
//                                     0,
//                                     23,
//                                     59,
//                                     59,
//                                   ),
//                                 ))
//                             .snapshots(),
//                         builder: (context, leaveCountSnapshot) {
//                           final approvedLeaveCount = leaveCountSnapshot.hasData
//                               ? leaveCountSnapshot.data!.docs.length
//                               : 0;
//                           return _buildColoredStatCard(
//                             'Approved Leaves',
//                             '$approvedLeaveCount Days',
//                             Icons.event_note,
//                             Colors.amber.shade50,
//                             Colors.amber.shade900,
//                           );
//                         },
//                       ),
//                       _buildColoredStatCard(
//                         'Holidays',
//                         '0 Days',
//                         Icons.beach_access,
//                         Colors.blue.shade50,
//                         Colors.blue.shade800,
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 24),
//                   Text(
//                     'Detailed Logs for $_selectedMonth',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: darkText,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   if (filteredDocs.isEmpty)
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       child: const Text(
//                         'No attendance records found for this month.',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(color: Colors.grey),
//                       ),
//                     )
//                   else
//                     ListView.builder(
//                       shrinkWrap: true,
//                       physics: const NeverScrollableScrollPhysics(),
//                       itemCount: filteredDocs.length,
//                       itemBuilder: (context, index) {
//                         final data =
//                             filteredDocs[index].data() as Map<String, dynamic>;

//                         final Timestamp? checkInTs =
//                             data['checkInTime'] as Timestamp?;
//                         final Timestamp? checkOutTs =
//                             data['checkOutTime'] as Timestamp?;

//                         final String formattedDate = checkInTs != null
//                             ? DateFormat('MMM dd, yyyy')
//                                 .format(checkInTs.toDate())
//                             : 'Unknown Date';

//                         final String checkInStr = checkInTs != null
//                             ? DateFormat('hh:mm a').format(checkInTs.toDate())
//                             : '--:--';

//                         final String checkOutStr = checkOutTs != null
//                             ? DateFormat('hh:mm a').format(checkOutTs.toDate())
//                             : 'Not Checked Out';

//                         return _buildLogTile(
//                           date: formattedDate,
//                           title: 'Present',
//                           subtitle: 'In: $checkInStr | Out: $checkOutStr',
//                           color: checkOutTs != null
//                               ? Colors.green.shade700
//                               : Colors.amber.shade800,
//                           icon: checkOutTs != null
//                               ? Icons.check_circle_outline
//                               : Icons.access_time,
//                         );
//                       },
//                     ),
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   // --- MINI EMAIL LEAVE APPLICATION MODAL ---
//   void _showLeaveApplicationModal(BuildContext context) {
//     final formKey = GlobalKey<FormState>();
//     final subjectController = TextEditingController();
//     final reasonController = TextEditingController();
//     DateTime? selectedLeaveDate;
//     bool isSubmitting = false;

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (BuildContext context, StateSetter setModalState) {
//             return Padding(
//               padding: EdgeInsets.only(
//                 bottom: MediaQuery.of(context).viewInsets.bottom,
//               ),
//               child: Container(
//                 padding: const EdgeInsets.all(24.0),
//                 decoration: const BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(28),
//                     topRight: Radius.circular(28),
//                   ),
//                 ),
//                 child: Form(
//                   key: formKey,
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           const Icon(Icons.mark_email_unread_outlined,
//                               color: maroon, size: 28),
//                           const SizedBox(width: 10),
//                           const Text(
//                             'Apply for Leave',
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.bold,
//                               color: darkText,
//                             ),
//                           ),
//                           const Spacer(),
//                           IconButton(
//                             icon: const Icon(Icons.close, color: Colors.grey),
//                             onPressed: () => Navigator.pop(context),
//                           )
//                         ],
//                       ),
//                       const Divider(height: 24),
//                       TextFormField(
//                         controller: subjectController,
//                         decoration: InputDecoration(
//                           labelText: 'Subject',
//                           hintText: 'e.g., Sick Leave / Personal Matter',
//                           prefixIcon: const Icon(Icons.subject, color: maroon),
//                           border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12)),
//                           filled: true,
//                           fillColor: Colors.grey.shade50,
//                         ),
//                         validator: (val) => val == null || val.isEmpty
//                             ? 'Please enter a subject'
//                             : null,
//                       ),
//                       const SizedBox(height: 14),
//                       InkWell(
//                         onTap: () async {
//                           final pickedDate = await showDatePicker(
//                             context: context,
//                             initialDate: DateTime.now(),
//                             firstDate: DateTime.now(),
//                             lastDate:
//                                 DateTime.now().add(const Duration(days: 90)),
//                           );
//                           if (pickedDate != null) {
//                             setModalState(() {
//                               selectedLeaveDate = pickedDate;
//                             });
//                           }
//                         },
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 14, vertical: 16),
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.grey.shade400),
//                             borderRadius: BorderRadius.circular(12),
//                             color: Colors.grey.shade50,
//                           ),
//                           child: Row(
//                             children: [
//                               const Icon(Icons.calendar_today_outlined,
//                                   color: maroon),
//                               const SizedBox(width: 12),
//                               Text(
//                                 selectedLeaveDate == null
//                                     ? 'Select Leave Date'
//                                     : DateFormat('EEEE, MMM dd, yyyy')
//                                         .format(selectedLeaveDate!),
//                                 style: TextStyle(
//                                   color: selectedLeaveDate == null
//                                       ? Colors.grey.shade600
//                                       : darkText,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 14),
//                       TextFormField(
//                         controller: reasonController,
//                         maxLines: 3,
//                         decoration: InputDecoration(
//                           labelText: 'Reason / Message',
//                           hintText:
//                               'Write a brief reason for your leave application...',
//                           alignLabelWithHint: true,
//                           prefixIcon: const Padding(
//                             padding: EdgeInsets.only(bottom: 40),
//                             child: Icon(Icons.notes, color: maroon),
//                           ),
//                           border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(12)),
//                           filled: true,
//                           fillColor: Colors.grey.shade50,
//                         ),
//                         validator: (val) => val == null || val.isEmpty
//                             ? 'Please write your reason'
//                             : null,
//                       ),
//                       const SizedBox(height: 20),
//                       SizedBox(
//                         width: double.infinity,
//                         height: 50,
//                         child: ElevatedButton.icon(
//                           icon: isSubmitting
//                               ? const SizedBox.shrink()
//                               : const Icon(Icons.send_rounded,
//                                   color: Colors.white),
//                           label: isSubmitting
//                               ? const CircularProgressIndicator(
//                                   color: Colors.white)
//                               : const Text('Send Application',
//                                   style: TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.bold)),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: maroon,
//                             shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(12)),
//                           ),
//                           onPressed: isSubmitting
//                               ? null
//                               : () async {
//                                   if (!formKey.currentState!.validate()) return;
//                                   if (selectedLeaveDate == null) {
//                                     ScaffoldMessenger.of(context).showSnackBar(
//                                       const SnackBar(
//                                           content: Text(
//                                               'Please select a leave date.')),
//                                     );
//                                     return;
//                                   }

//                                   setModalState(() => isSubmitting = true);

//                                   try {
//                                     final user =
//                                         FirebaseAuth.instance.currentUser;

//                                     await FirebaseFirestore.instance
//                                         .collection('leaves')
//                                         .add({
//                                       'userId': user?.uid,
//                                       'userEmail': user?.email,
//                                       'subject': subjectController.text.trim(),
//                                       'reason': reasonController.text.trim(),
//                                       'startDate': Timestamp.fromDate(
//                                         DateTime(
//                                             selectedLeaveDate!.year,
//                                             selectedLeaveDate!.month,
//                                             selectedLeaveDate!.day),
//                                       ),
//                                       'status': 'Pending',
//                                       'createdAt': FieldValue.serverTimestamp(),
//                                     });

//                                     if (context.mounted) {
//                                       Navigator.pop(context);
//                                       ScaffoldMessenger.of(context)
//                                           .showSnackBar(
//                                         const SnackBar(
//                                           content: Text(
//                                               'Leave application sent to Admin!'),
//                                           backgroundColor: Colors.green,
//                                         ),
//                                       );
//                                     }
//                                   } catch (e) {
//                                     if (context.mounted) {
//                                       ScaffoldMessenger.of(context)
//                                           .showSnackBar(
//                                         SnackBar(
//                                             content: Text('Error: $e'),
//                                             backgroundColor: Colors.red),
//                                       );
//                                     }
//                                   } finally {
//                                     setModalState(() => isSubmitting = false);
//                                   }
//                                 },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   // --- PAGE 4: NOTIFICATIONS TAB ---
//   Widget _buildNotificationsTab() {
//     final user = FirebaseAuth.instance.currentUser;

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Announcements & Leave Approvals',
//             style: TextStyle(
//                 fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
//           ),
//           const SizedBox(height: 12),
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('notifications')
//                   .where('recipientId',
//                       whereIn: ['all', user?.uid ?? '']).snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(
//                       child: CircularProgressIndicator(color: maroon));
//                 }

//                 final docs = snapshot.data?.docs ?? [];

//                 if (docs.isEmpty) {
//                   return Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: const [
//                         Icon(Icons.notifications_off_outlined,
//                             size: 50, color: Colors.grey),
//                         SizedBox(height: 12),
//                         Text('No notifications found',
//                             style: TextStyle(color: Colors.grey)),
//                       ],
//                     ),
//                   );
//                 }

//                 return ListView.builder(
//                   itemCount: docs.length,
//                   itemBuilder: (context, index) {
//                     final data = docs[index].data() as Map<String, dynamic>;
//                     final title = data['title'] ?? 'Notice';
//                     final body = data['body'] ?? '';
//                     final type = data['type'] ?? 'general';
//                     final Timestamp? timestamp =
//                         data['createdAt'] as Timestamp?;

//                     IconData typeIcon = Icons.info_outline;
//                     Color iconColor = Colors.blue;

//                     if (type == 'holiday') {
//                       typeIcon = Icons.beach_access;
//                       iconColor = Colors.orange;
//                     } else if (type == 'leave') {
//                       typeIcon = Icons.event_available;
//                       iconColor = Colors.green;
//                     } else if (type == 'success') {
//                       typeIcon = Icons.check_circle_outline;
//                       iconColor = Colors.green;
//                     }

//                     return Container(
//                       margin: const EdgeInsets.only(bottom: 12),
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.03),
//                             blurRadius: 8,
//                             offset: const Offset(0, 3),
//                           )
//                         ],
//                       ),
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           CircleAvatar(
//                             backgroundColor: iconColor.withOpacity(0.12),
//                             child: Icon(typeIcon, color: iconColor),
//                           ),
//                           const SizedBox(width: 14),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   title,
//                                   style: const TextStyle(
//                                       color: darkText,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 15),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   body,
//                                   style: TextStyle(
//                                       color: Colors.grey.shade700,
//                                       fontSize: 13),
//                                 ),
//                                 if (timestamp != null) ...[
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     DateFormat('hh:mm a - MMM dd, yyyy')
//                                         .format(timestamp.toDate()),
//                                     style: const TextStyle(
//                                         color: Colors.grey, fontSize: 11),
//                                   ),
//                                 ]
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // --- PAGE 5: SETTINGS PAGE ---
//   Widget _buildSettingsTab() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Account Settings',
//             style: TextStyle(
//                 fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
//           ),
//           const SizedBox(height: 16),
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.04),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 )
//               ],
//             ),
//             child: ListTile(
//               leading: const Icon(Icons.lock_outline, color: maroon),
//               title: const Text('Security & Password',
//                   style:
//                       TextStyle(color: darkText, fontWeight: FontWeight.bold)),
//               subtitle: const Text('Update your current password',
//                   style: TextStyle(color: Colors.grey, fontSize: 12)),
//               trailing: const Icon(Icons.arrow_forward_ios,
//                   color: Colors.grey, size: 16),
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                       builder: (context) =>
//                           const SecuritySettingsScreen(maroon: maroon)),
//                 );
//               },
//             ),
//           )
//         ],
//       ),
//     );
//   }

//   // --- HELPER COMPONENTS ---
//   Widget _buildColoredStatCard(String label, String value, IconData icon,
//       Color bgFillColor, Color textColor) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: bgFillColor,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: textColor, size: 18),
//               const SizedBox(width: 6),
//               Expanded(
//                 child: Text(
//                   label,
//                   style: TextStyle(
//                       color: textColor,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             value,
//             style: TextStyle(
//                 color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLogTile({
//     required String date,
//     required String title,
//     required String subtitle,
//     required Color color,
//     required IconData icon,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.03),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           )
//         ],
//       ),
//       child: ListTile(
//         leading: CircleAvatar(
//           backgroundColor: color.withOpacity(0.12),
//           child: Icon(icon, color: color),
//         ),
//         title: Text(
//           '$title - $date',
//           style: const TextStyle(
//               color: darkText, fontWeight: FontWeight.bold, fontSize: 14),
//         ),
//         subtitle: Text(
//           subtitle,
//           style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
//         ),
//         trailing: const Icon(
//           Icons.access_time_filled,
//           color: Colors.grey,
//           size: 18,
//         ),
//       ),
//     );
//   }
// }

// // --- SUB-PAGE: SECURITY SETTINGS ---
// class SecuritySettingsScreen extends StatefulWidget {
//   final Color maroon;
//   const SecuritySettingsScreen({super.key, required this.maroon});

//   @override
//   State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
// }

// class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
//   final _securityFormKey = GlobalKey<FormState>();
//   final TextEditingController _currentPasswordController =
//       TextEditingController();
//   final TextEditingController _newPasswordController = TextEditingController();
//   final TextEditingController _confirmPasswordController =
//       TextEditingController();
//   bool _isChangingPassword = false;
//   bool _obscureCurrent = true;
//   bool _obscureNew = true;
//   bool _obscureConfirm = true;

//   @override
//   void dispose() {
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _updatePassword() async {
//     if (!_securityFormKey.currentState!.validate()) return;

//     setState(() => _isChangingPassword = true);

//     try {
//       User? user = FirebaseAuth.instance.currentUser;

//       if (user != null && user.email != null) {
//         AuthCredential credential = EmailAuthProvider.credential(
//           email: user.email!,
//           password: _currentPasswordController.text,
//         );

//         await user.reauthenticateWithCredential(credential);
//         await user.updatePassword(_newPasswordController.text);

//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Password updated successfully!'),
//             backgroundColor: Colors.green,
//           ),
//         );

//         Navigator.pop(context);
//       }
//     } on FirebaseAuthException catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(e.message ?? 'Failed to update password.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isChangingPassword = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFFAFAFA),
//       body: Stack(
//         children: [
//           ClipPath(
//             clipper: WavyHeaderClipper(),
//             child: Container(
//               height: 220,
//               width: double.infinity,
//               color: widget.maroon,
//             ),
//           ),
//           SafeArea(
//             child: SingleChildScrollView(
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
//               child: Form(
//                 key: _securityFormKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         IconButton(
//                           icon:
//                               const Icon(Icons.arrow_back, color: Colors.white),
//                           onPressed: () => Navigator.pop(context),
//                         ),
//                         const SizedBox(width: 8),
//                         const Text(
//                           'Security & Password',
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 50),
//                     Container(
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.06),
//                             blurRadius: 15,
//                             offset: const Offset(0, 5),
//                           )
//                         ],
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Update Password',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color: Color(0xFF2C2C2C),
//                             ),
//                           ),
//                           const SizedBox(height: 6),
//                           Text(
//                             'Update your account password below to ensure your profile stays secure.',
//                             style: TextStyle(
//                                 color: Colors.grey.shade600, fontSize: 13),
//                           ),
//                           const SizedBox(height: 24),
//                           _buildPasswordField(
//                             controller: _currentPasswordController,
//                             labelText: 'Current Password',
//                             obscureText: _obscureCurrent,
//                             onToggleVisibility: () => setState(
//                                 () => _obscureCurrent = !_obscureCurrent),
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Please enter your current password';
//                               }
//                               return null;
//                             },
//                           ),
//                           const SizedBox(height: 16),
//                           _buildPasswordField(
//                             controller: _newPasswordController,
//                             labelText: 'New Password',
//                             obscureText: _obscureNew,
//                             onToggleVisibility: () =>
//                                 setState(() => _obscureNew = !_obscureNew),
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Please enter a new password';
//                               }
//                               if (value.length < 6) {
//                                 return 'Password must be at least 6 characters long';
//                               }
//                               return null;
//                             },
//                           ),
//                           const SizedBox(height: 16),
//                           _buildPasswordField(
//                             controller: _confirmPasswordController,
//                             labelText: 'Confirm New Password',
//                             obscureText: _obscureConfirm,
//                             onToggleVisibility: () => setState(
//                                 () => _obscureConfirm = !_obscureConfirm),
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Please confirm your new password';
//                               }
//                               if (value != _newPasswordController.text) {
//                                 return 'Passwords do not match';
//                               }
//                               return null;
//                             },
//                           ),
//                           const SizedBox(height: 28),
//                           SizedBox(
//                             width: double.infinity,
//                             height: 50,
//                             child: ElevatedButton(
//                               onPressed:
//                                   _isChangingPassword ? null : _updatePassword,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: widget.maroon,
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(14),
//                                 ),
//                                 elevation: 2,
//                               ),
//                               child: _isChangingPassword
//                                   ? const SizedBox(
//                                       height: 22,
//                                       width: 22,
//                                       child: CircularProgressIndicator(
//                                         color: Colors.white,
//                                         strokeWidth: 2.5,
//                                       ),
//                                     )
//                                   : const Text(
//                                       'Update Password',
//                                       style: TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPasswordField({
//     required TextEditingController controller,
//     required String labelText,
//     required bool obscureText,
//     required VoidCallback onToggleVisibility,
//     required String? Function(String?) validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       obscureText: obscureText,
//       style: const TextStyle(color: Color(0xFF2C2C2C)),
//       validator: validator,
//       decoration: InputDecoration(
//         labelText: labelText,
//         labelStyle: TextStyle(color: Colors.grey.shade600),
//         prefixIcon: Icon(Icons.lock_outline, color: widget.maroon),
//         suffixIcon: IconButton(
//           icon: Icon(
//             obscureText ? Icons.visibility_off : Icons.visibility,
//             color: Colors.grey,
//           ),
//           onPressed: onToggleVisibility,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: Colors.grey.shade300),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: widget.maroon, width: 2),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: Colors.red),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: Colors.red, width: 2),
//         ),
//         filled: true,
//         fillColor: Colors.grey.shade50,
//       ),
//     );
//   }
// }

// // Custom Wave Clipper Header
// class WavyHeaderClipper extends CustomClipper<Path> {
//   @override
//   Path getClip(Size size) {
//     Path path = Path();
//     path.lineTo(0, size.height - 60);

//     var firstControlPoint = Offset(size.width * 0.25, size.height);
//     var firstEndPoint = Offset(size.width * 0.55, size.height - 40);
//     path.quadraticBezierTo(
//       firstControlPoint.dx,
//       firstControlPoint.dy,
//       firstEndPoint.dx,
//       firstEndPoint.dy,
//     );

//     var secondControlPoint = Offset(size.width * 0.8, size.height - 80);
//     var secondEndPoint = Offset(size.width, size.height - 20);
//     path.quadraticBezierTo(
//       secondControlPoint.dx,
//       secondControlPoint.dy,
//       secondEndPoint.dx,
//       secondEndPoint.dy,
//     );

//     path.lineTo(size.width, 0);
//     path.close();
//     return path;
//   }

//   @override
//   bool shouldReclip(CustomClipper<Path> oldClipper) => false;
// }

// // import 'package:flutter/material.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:device_info_plus/device_info_plus.dart';
// // import 'package:network_info_plus/network_info_plus.dart';
// // import 'package:permission_handler/permission_handler.dart';
// // import 'package:intl/intl.dart';
// // import 'login_screen.dart';
// // import 'qr_scanner_screen.dart';

// // class DashboardScreen extends StatefulWidget {
// //   final String userName;

// //   const DashboardScreen({super.key, required this.userName});

// //   @override
// //   State<DashboardScreen> createState() => _DashboardScreenState();
// // }

// // class _DashboardScreenState extends State<DashboardScreen> {
// //   int _selectedIndex = 0;
// //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

// //   // Colors
// //   static const Color maroon = Color(0xFF800000);
// //   static const Color lightBg = Color(0xFFFAFAFA);
// //   static const Color darkText = Color(0xFF2C2C2C);

// //   // Attendance Terminal State
// //   String _statusMessage = 'Ready to verify and mark attendance';
// //   bool _isLoading = false;

// //   // Month Tracking for History
// //   final List<String> _monthNames = const [
// //     'January',
// //     'February',
// //     'March',
// //     'April',
// //     'May',
// //     'June',
// //     'July',
// //     'August',
// //     'September',
// //     'October',
// //     'November',
// //     'December'
// //   ];
// //   late List<String> _monthsList;
// //   late String _selectedMonth;

// //   @override
// //   void initState() {
// //     super.initState();
// //     final now = DateTime.now();
// //     final currentMonthName = _monthNames[now.month - 1];
// //     final currentFormattedMonth = '$currentMonthName ${now.year}';

// //     _monthsList = _monthNames.map((m) => '$m ${now.year}').toList();

// //     if (_monthsList.contains(currentFormattedMonth)) {
// //       _selectedMonth = currentFormattedMonth;
// //     } else {
// //       _monthsList.insert(0, currentFormattedMonth);
// //       _selectedMonth = currentFormattedMonth;
// //     }
// //   }

// //   // --- LOGOUT ---
// //   Future<void> _handleLogout() async {
// //     await FirebaseAuth.instance.signOut();
// //     if (!mounted) return;
// //     Navigator.pushReplacement(
// //       context,
// //       MaterialPageRoute(builder: (context) => const LoginScreen()),
// //     );
// //   }

// // // --- CHECK-IN LOGIC ---
// //   Future<void> _verifyAndProceed() async {
// //     // 1. Check leave status first
// //     try {
// //       final leaveApproved = await _isTodayApprovedLeave();
// //       if (leaveApproved) {
// //         if (!mounted) return;
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(
// //             content: Text(
// //                 'Leave is already approved for today. Attendance is not required.'),
// //             backgroundColor: Colors.green,
// //           ),
// //         );
// //         return;
// //       }
// //     } catch (e) {
// //       debugPrint('Error checking leave status: $e');
// //     }

// //     setState(() {
// //       _isLoading = true;
// //       _statusMessage = 'Checking device permissions...';
// //     });

// //     try {
// //       // 2. Request permissions safely
// //       try {
// //         await [Permission.location, Permission.camera].request();
// //       } catch (e) {
// //         debugPrint('Permission request error: $e');
// //       }

// //       // 3. Get Device ID safely
// //       String deviceId = 'web_browser_client';
// //       try {
// //         if (!Uri.base.hasAuthority) {
// //           final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
// //           AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
// //           deviceId = androidInfo.id;
// //         }
// //       } catch (e) {
// //         debugPrint('Error getting Device ID: $e');
// //         deviceId = 'unknown_android_device';
// //       }

// //       setState(() => _statusMessage = 'Verifying office Wi-Fi network...');

// //       // 4. Get Wi-Fi BSSID safely
// //       String? bssid;
// //       try {
// //         final NetworkInfo networkInfo = NetworkInfo();
// //         bssid = await networkInfo.getWifiBSSID();
// //       } catch (e) {
// //         debugPrint('Error fetching Wi-Fi BSSID: $e');
// //       }

// //       // Do not allow fallback for attendance validation; require a real Wi-Fi BSSID.
// //       if (bssid == null || bssid.isEmpty) {
// //         setState(() {
// //           _statusMessage =
// //               'Access Blocked: Unable to detect office Wi-Fi. Please connect to the office network.';
// //           _isLoading = false;
// //         });

// //         if (mounted) {
// //           ScaffoldMessenger.of(context).showSnackBar(
// //             const SnackBar(
// //               content: Text(
// //                   'Unable to detect Wi-Fi BSSID. Connect to office Wi-Fi to mark attendance.'),
// //               backgroundColor: Colors.red,
// //               duration: Duration(seconds: 6),
// //             ),
// //           );
// //         }
// //         return;
// //       }

// //       debugPrint('=== DETECTED BSSID: $bssid ===');

// //       // 5. Show detected BSSID popup
// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: Text('Detected BSSID: $bssid'),
// //             backgroundColor: Colors.blue,
// //             duration: const Duration(seconds: 4),
// //           ),
// //         );
// //       }

// //       // 6. Check Firestore configuration
// //       DocumentSnapshot configDoc = await FirebaseFirestore.instance
// //           .collection('config')
// //           .doc('attendance')
// //           .get();

// //       if (configDoc.exists) {
// //         final data = configDoc.data() as Map<String, dynamic>? ?? {};
// //         final List<dynamic> allowedBssids =
// //             data['allowedBssids'] as List<dynamic>? ?? [];

// //         // Check if list is restricted and current BSSID is not inside
// //         if (allowedBssids.isNotEmpty && !allowedBssids.contains(bssid)) {
// //           setState(() {
// //             _statusMessage =
// //                 'Access Blocked: Not connected to authorized office Wi-Fi.';
// //             _isLoading = false;
// //           });

// //           if (mounted) {
// //             ScaffoldMessenger.of(context).showSnackBar(
// //               SnackBar(
// //                 content: Text(
// //                     'Blocked: BSSID "$bssid" is not authorized in Firebase.'),
// //                 backgroundColor: Colors.red,
// //                 duration: const Duration(seconds: 6),
// //               ),
// //             );
// //           }
// //           return;
// //         }
// //       }

// //       setState(() => _isLoading = false);

// //       // 7. Proceed to Scanner
// //       if (!mounted) return;
// //       Navigator.push(
// //         context,
// //         MaterialPageRoute(
// //           builder: (context) =>
// //               QRScannerScreen(currentBssid: bssid!, currentDeviceId: deviceId),
// //         ),
// //       );
// //     } catch (e) {
// //       debugPrint('Global error during validation: $e');
// //       setState(() {
// //         _statusMessage = 'Error during validation: $e';
// //         _isLoading = false;
// //       });

// //       if (mounted) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           SnackBar(
// //             content: Text('Validation Error: $e'),
// //             backgroundColor: Colors.red,
// //             duration: const Duration(seconds: 5),
// //           ),
// //         );
// //       }
// //     }
// //   }

// //   // --- CHECK-OUT LOGIC ---
// //   Future<void> _handleCheckOut() async {
// //     final user = FirebaseAuth.instance.currentUser;
// //     if (user == null) return;

// //     final now = DateTime.now();
// //     final todayId = DateFormat('yyyy-MM-dd').format(now);

// //     final docRef = FirebaseFirestore.instance
// //         .collection('users')
// //         .doc(user.uid)
// //         .collection('attendance')
// //         .doc(todayId);

// //     final docSnap = await docRef.get();

// //     if (!docSnap.exists || docSnap.data()?['checkInTime'] == null) {
// //       if (!mounted) return;
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(
// //           content: Text('Cannot check out: You have not checked in today!'),
// //           backgroundColor: Colors.orange,
// //         ),
// //       );
// //       return;
// //     }

// //     if (docSnap.data()?['checkOutTime'] != null) {
// //       if (!mounted) return;
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(
// //           content: Text('You have already checked out for today.'),
// //           backgroundColor: Colors.blue,
// //         ),
// //       );
// //       return;
// //     }

// //     final confirm = await showDialog<bool>(
// //       context: context,
// //       builder: (ctx) => AlertDialog(
// //         title: const Text('Confirm Check-Out',
// //             style: TextStyle(color: darkText, fontWeight: FontWeight.bold)),
// //         content: Text(
// //             'Timestamp: ${DateFormat('hh:mm a - MMM dd, yyyy').format(now)}\n\nDo you want to proceed?',
// //             style: const TextStyle(color: darkText)),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.pop(ctx, false),
// //             child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
// //           ),
// //           ElevatedButton(
// //             onPressed: () => Navigator.pop(ctx, true),
// //             style: ElevatedButton.styleFrom(
// //               backgroundColor: maroon,
// //               shape: RoundedRectangleBorder(
// //                   borderRadius: BorderRadius.circular(10)),
// //             ),
// //             child:
// //                 const Text('Check-Out', style: TextStyle(color: Colors.white)),
// //           ),
// //         ],
// //       ),
// //     );

// //     if (confirm != true) return;

// //     setState(() => _isLoading = true);

// //     try {
// //       await docRef.update({
// //         'checkOutTime': FieldValue.serverTimestamp(),
// //         'status': 'Completed',
// //       });

// //       if (!mounted) return;

// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(
// //           content: Text('Successfully checked-out'),
// //           backgroundColor: Colors.green,
// //         ),
// //       );

// //       if (mounted) {
// //         setState(() {
// //           _isLoading = false;
// //           _statusMessage = 'You have checked out successfully.';
// //           _selectedIndex = 0;
// //         });
// //       }
// //     } catch (e) {
// //       if (!mounted) return;
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //             content: Text('Error recording check-out: $e'),
// //             backgroundColor: Colors.red),
// //       );
// //     } finally {
// //       if (mounted) setState(() => _isLoading = false);
// //     }
// //   }

// //   // Active View Generator
// //   Widget _buildBodyContent() {
// //     switch (_selectedIndex) {
// //       case 0:
// //         return _buildHomePage();
// //       case 1:
// //         return _buildCheckInTab();
// //       case 2:
// //         return _buildAttendanceHistoryTab();
// //       case 3:
// //         return _buildNotificationsTab();
// //       case 4:
// //         return _buildSettingsTab();
// //       default:
// //         return _buildHomePage();
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final List<String> pageTitles = [
// //       'Portal Home',
// //       'Attendance Terminal',
// //       'Attendance History',
// //       'Notifications',
// //       'Settings'
// //     ];

// //     return Scaffold(
// //       key: _scaffoldKey,
// //       backgroundColor: lightBg,
// //       drawer: _buildSlideDrawer(),
// //       body: Stack(
// //         children: [
// //           // Background Header Design Wave
// //           ClipPath(
// //             clipper: WavyHeaderClipper(),
// //             child: Container(
// //               height: 250,
// //               width: double.infinity,
// //               decoration: const BoxDecoration(
// //                 gradient: LinearGradient(
// //                   colors: [maroon, Color(0xFFA01A1A)],
// //                   begin: Alignment.topLeft,
// //                   end: Alignment.bottomRight,
// //                 ),
// //               ),
// //             ),
// //           ),
// //           SafeArea(
// //             child: Column(
// //               children: [
// //                 // Top Custom Navigation Bar
// //                 Padding(
// //                   padding: const EdgeInsets.symmetric(
// //                       horizontal: 16.0, vertical: 8.0),
// //                   child: Row(
// //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                     children: [
// //                       IconButton(
// //                         icon: const Icon(Icons.menu,
// //                             color: Colors.white, size: 28),
// //                         onPressed: () =>
// //                             _scaffoldKey.currentState?.openDrawer(),
// //                       ),
// //                       Text(
// //                         pageTitles[_selectedIndex],
// //                         style: const TextStyle(
// //                           color: Colors.white,
// //                           fontSize: 20,
// //                           fontWeight: FontWeight.bold,
// //                         ),
// //                       ),
// //                       IconButton(
// //                         icon: const Icon(Icons.logout,
// //                             color: Colors.white, size: 24),
// //                         onPressed: _handleLogout,
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //                 // Dynamic View Section
// //                 Expanded(
// //                   child: _buildBodyContent(),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   // --- DRAWER NAVIGATION ---
// //   Widget _buildSlideDrawer() {
// //     final user = FirebaseAuth.instance.currentUser;

// //     return Drawer(
// //       child: Container(
// //         color: lightBg,
// //         child: ListView(
// //           padding: EdgeInsets.zero,
// //           children: [
// //             StreamBuilder<DocumentSnapshot>(
// //               stream: FirebaseFirestore.instance
// //                   .collection('users')
// //                   .doc(user?.uid)
// //                   .snapshots(),
// //               builder: (context, snapshot) {
// //                 String name =
// //                     widget.userName.isNotEmpty ? widget.userName : 'User';
// //                 String role = 'Intern';
// //                 if (snapshot.hasData && snapshot.data!.exists) {
// //                   final data = snapshot.data!.data() as Map<String, dynamic>?;
// //                   if (data?['name'] != null &&
// //                       (data!['name'] as String).isNotEmpty) {
// //                     name = data['name'];
// //                   }
// //                   role = data?['role'] ?? 'Intern';
// //                 }
// //                 return DrawerHeader(
// //                   decoration: const BoxDecoration(
// //                     color: maroon,
// //                   ),
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     mainAxisAlignment: MainAxisAlignment.center,
// //                     children: [
// //                       CircleAvatar(
// //                         radius: 30,
// //                         backgroundColor: Colors.white,
// //                         child: Text(
// //                           name.isNotEmpty ? name[0].toUpperCase() : 'U',
// //                           style: const TextStyle(
// //                               fontSize: 26,
// //                               color: maroon,
// //                               fontWeight: FontWeight.bold),
// //                         ),
// //                       ),
// //                       const SizedBox(height: 10),
// //                       Text(name,
// //                           style: const TextStyle(
// //                               color: Colors.white,
// //                               fontWeight: FontWeight.bold,
// //                               fontSize: 18)),
// //                       Text('$role | ${user?.email ?? ''}',
// //                           style: const TextStyle(
// //                               color: Colors.white70, fontSize: 12)),
// //                     ],
// //                   ),
// //                 );
// //               },
// //             ),
// //             _buildDrawerTile(0, 'Home', Icons.home_rounded),
// //             _buildDrawerTile(1, 'Mark Attendance', Icons.fingerprint),
// //             _buildDrawerTile(2, 'Attendance History', Icons.history_rounded),
// //             _buildDrawerTile(3, 'Notifications', Icons.notifications_rounded),
// //             _buildDrawerTile(4, 'Settings', Icons.settings_rounded),
// //             const Divider(color: Colors.black12),
// //             ListTile(
// //               leading: const Icon(Icons.logout, color: maroon),
// //               title: const Text('Logout',
// //                   style:
// //                       TextStyle(color: darkText, fontWeight: FontWeight.w600)),
// //               onTap: _handleLogout,
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _buildDrawerTile(int index, String title, IconData icon) {
// //     final isSelected = _selectedIndex == index;
// //     return ListTile(
// //       selected: isSelected,
// //       selectedTileColor: maroon.withOpacity(0.08),
// //       leading: Icon(icon, color: isSelected ? maroon : Colors.grey.shade700),
// //       title: Text(
// //         title,
// //         style: TextStyle(
// //           color: isSelected ? maroon : darkText,
// //           fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
// //         ),
// //       ),
// //       onTap: () {
// //         setState(() => _selectedIndex = index);
// //         Navigator.pop(context);
// //       },
// //     );
// //   }

// //   // --- PAGE 1: HOME PAGE ---
// //   Widget _buildHomePage() {
// //     final user = FirebaseAuth.instance.currentUser;

// //     return StreamBuilder<DocumentSnapshot>(
// //       stream: FirebaseFirestore.instance
// //           .collection('users')
// //           .doc(user?.uid)
// //           .snapshots(),
// //       builder: (context, snapshot) {
// //         if (snapshot.connectionState == ConnectionState.waiting) {
// //           return const Center(child: CircularProgressIndicator(color: maroon));
// //         }

// //         final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

// //         // Priority: Firestore name -> Passed widget.userName -> Default Fallback
// //         String name = data['name'] ?? '';
// //         if (name.isEmpty) {
// //           name = widget.userName.isNotEmpty ? widget.userName : 'Intern Name';
// //         }

// //         final role = data['role'] ?? 'Intern';
// //         final department = data['department'] ?? 'Flutter Frontend Development';

// //         return SingleChildScrollView(
// //           padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               const SizedBox(height: 10),
// //               // Profile Header Card
// //               Container(
// //                 width: double.infinity,
// //                 padding: const EdgeInsets.all(20),
// //                 decoration: BoxDecoration(
// //                   color: Colors.white,
// //                   borderRadius: BorderRadius.circular(20),
// //                   boxShadow: [
// //                     BoxShadow(
// //                       color: Colors.black.withOpacity(0.06),
// //                       blurRadius: 15,
// //                       offset: const Offset(0, 5),
// //                     )
// //                   ],
// //                 ),
// //                 child: Row(
// //                   children: [
// //                     CircleAvatar(
// //                       radius: 32,
// //                       backgroundColor: maroon.withOpacity(0.1),
// //                       child: const Icon(Icons.person, size: 38, color: maroon),
// //                     ),
// //                     const SizedBox(width: 16),
// //                     Expanded(
// //                       child: Column(
// //                         crossAxisAlignment: CrossAxisAlignment.start,
// //                         children: [
// //                           Text(
// //                             'Welcome back,',
// //                             style: TextStyle(
// //                                 color: Colors.grey.shade600, fontSize: 13),
// //                           ),
// //                           Text(
// //                             name,
// //                             style: const TextStyle(
// //                               color: darkText,
// //                               fontSize: 20,
// //                               fontWeight: FontWeight.bold,
// //                             ),
// //                           ),
// //                           const SizedBox(height: 6),
// //                           Container(
// //                             padding: const EdgeInsets.symmetric(
// //                                 horizontal: 10, vertical: 4),
// //                             decoration: BoxDecoration(
// //                               color: maroon,
// //                               borderRadius: BorderRadius.circular(20),
// //                             ),
// //                             child: Text(
// //                               role,
// //                               style: const TextStyle(
// //                                 color: Colors.white,
// //                                 fontWeight: FontWeight.bold,
// //                                 fontSize: 11,
// //                               ),
// //                             ),
// //                           )
// //                         ],
// //                       ),
// //                     )
// //                   ],
// //                 ),
// //               ),
// //               const SizedBox(height: 24),
// //               const Text(
// //                 'Quick Overview',
// //                 style: TextStyle(
// //                     color: darkText, fontSize: 18, fontWeight: FontWeight.bold),
// //               ),
// //               const SizedBox(height: 12),
// //               Container(
// //                 padding: const EdgeInsets.all(20),
// //                 decoration: BoxDecoration(
// //                   color: Colors.white,
// //                   borderRadius: BorderRadius.circular(20),
// //                   boxShadow: [
// //                     BoxShadow(
// //                       color: Colors.black.withOpacity(0.04),
// //                       blurRadius: 10,
// //                       offset: const Offset(0, 4),
// //                     )
// //                   ],
// //                 ),
// //                 child: Column(
// //                   children: [
// //                     _buildProfileDetailRow(
// //                         Icons.business_rounded, 'Department', department),
// //                     const Divider(color: Colors.black12, height: 24),
// //                     _buildProfileDetailRow(Icons.email_rounded, 'Email Address',
// //                         user?.email ?? 'N/A'),
// //                     const Divider(color: Colors.black12, height: 24),
// //                     _buildProfileDetailRow(
// //                         Icons.calendar_today_rounded,
// //                         'Today',
// //                         DateFormat('EEEE, MMM dd, yyyy')
// //                             .format(DateTime.now())),
// //                   ],
// //                 ),
// //               ),
// //               const SizedBox(height: 22),
// //               Container(
// //                 width: double.infinity,
// //                 padding: const EdgeInsets.all(20),
// //                 decoration: BoxDecoration(
// //                   color: Colors.white,
// //                   borderRadius: BorderRadius.circular(20),
// //                   boxShadow: [
// //                     BoxShadow(
// //                       color: Colors.black.withOpacity(0.04),
// //                       blurRadius: 10,
// //                       offset: const Offset(0, 4),
// //                     )
// //                   ],
// //                 ),
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Row(
// //                       children: [
// //                         const Icon(Icons.beach_access_rounded,
// //                             color: maroon, size: 26),
// //                         const SizedBox(width: 12),
// //                         Expanded(
// //                           child: Text(
// //                             'Leave Application',
// //                             style: TextStyle(
// //                               color: darkText,
// //                               fontSize: 18,
// //                               fontWeight: FontWeight.bold,
// //                             ),
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                     const SizedBox(height: 10),
// //                     Text(
// //                       'Submit an e-application for leave. Once approved by admin, that day will be marked as Leave Approved instead of regular attendance.',
// //                       style:
// //                           TextStyle(color: Colors.grey.shade700, fontSize: 14),
// //                     ),
// //                     const SizedBox(height: 18),
// //                     SizedBox(
// //                       width: double.infinity,
// //                       height: 48,
// //                       child: ElevatedButton.icon(
// //                         icon:
// //                             const Icon(Icons.send_rounded, color: Colors.white),
// //                         label: const Text('Apply for Leave',
// //                             style: TextStyle(
// //                                 color: Colors.white,
// //                                 fontWeight: FontWeight.bold)),
// //                         style: ElevatedButton.styleFrom(
// //                           backgroundColor: maroon,
// //                           shape: RoundedRectangleBorder(
// //                               borderRadius: BorderRadius.circular(14)),
// //                         ),
// //                         onPressed: () => _showLeaveApplicationModal(context),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //               const SizedBox(height: 22),
// //               StreamBuilder<QuerySnapshot>(
// //                 stream: user == null
// //                     ? const Stream<QuerySnapshot>.empty()
// //                     : FirebaseFirestore.instance
// //                         .collection('leaves')
// //                         .where('userId', isEqualTo: user.uid)
// //                         .orderBy('createdAt', descending: true)
// //                         .limit(4)
// //                         .snapshots(),
// //                 builder: (context, leaveSnapshot) {
// //                   if (leaveSnapshot.connectionState ==
// //                       ConnectionState.waiting) {
// //                     return Container(
// //                       width: double.infinity,
// //                       padding: const EdgeInsets.all(20),
// //                       decoration: BoxDecoration(
// //                         color: Colors.white,
// //                         borderRadius: BorderRadius.circular(20),
// //                         boxShadow: [
// //                           BoxShadow(
// //                             color: Colors.black.withOpacity(0.04),
// //                             blurRadius: 12,
// //                             offset: const Offset(0, 4),
// //                           ),
// //                         ],
// //                       ),
// //                       child: const Center(
// //                         child: CircularProgressIndicator(color: maroon),
// //                       ),
// //                     );
// //                   }

// //                   final leaveDocs = leaveSnapshot.data?.docs ?? [];
// //                   final today = DateTime.now();
// //                   final todayApproved = leaveDocs.any((doc) {
// //                     final data = doc.data() as Map<String, dynamic>;
// //                     final Timestamp? startDate =
// //                         data['startDate'] as Timestamp?;
// //                     if (startDate == null) return false;
// //                     final date = startDate.toDate();
// //                     return date.year == today.year &&
// //                         date.month == today.month &&
// //                         date.day == today.day &&
// //                         data['status'] == 'Approved';
// //                   });
// //                   final todayPending = leaveDocs.any((doc) {
// //                     final data = doc.data() as Map<String, dynamic>;
// //                     final Timestamp? startDate =
// //                         data['startDate'] as Timestamp?;
// //                     if (startDate == null) return false;
// //                     final date = startDate.toDate();
// //                     return date.year == today.year &&
// //                         date.month == today.month &&
// //                         date.day == today.day &&
// //                         data['status'] == 'Pending';
// //                   });

// //                   return Container(
// //                     width: double.infinity,
// //                     padding: const EdgeInsets.all(20),
// //                     decoration: BoxDecoration(
// //                       color: Colors.white,
// //                       borderRadius: BorderRadius.circular(20),
// //                       boxShadow: [
// //                         BoxShadow(
// //                           color: Colors.black.withOpacity(0.04),
// //                           blurRadius: 10,
// //                           offset: const Offset(0, 4),
// //                         ),
// //                       ],
// //                     ),
// //                     child: Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [
// //                         const Text(
// //                           'Leave Status',
// //                           style: TextStyle(
// //                             fontSize: 18,
// //                             fontWeight: FontWeight.bold,
// //                             color: darkText,
// //                           ),
// //                         ),
// //                         const SizedBox(height: 8),
// //                         Text(
// //                           todayApproved
// //                               ? 'Today’s leave has been approved. Attendance won’t be required.'
// //                               : todayPending
// //                                   ? 'Your leave application for today is pending approval.'
// //                                   : 'No leave application exists for today.',
// //                           style: TextStyle(
// //                               color: Colors.grey.shade700, fontSize: 14),
// //                         ),
// //                         const SizedBox(height: 16),
// //                         if (leaveDocs.isEmpty)
// //                           Container(
// //                             width: double.infinity,
// //                             padding: const EdgeInsets.all(16),
// //                             decoration: BoxDecoration(
// //                               color: Colors.grey.shade50,
// //                               borderRadius: BorderRadius.circular(16),
// //                             ),
// //                             child: const Text(
// //                               'You currently have no recent leave applications. Use the button above to submit one.',
// //                               style: TextStyle(color: Colors.black87),
// //                             ),
// //                           )
// //                         else
// //                           Column(
// //                             children: leaveDocs.map((doc) {
// //                               final data = doc.data() as Map<String, dynamic>;
// //                               final Timestamp? startDate =
// //                                   data['startDate'] as Timestamp?;
// //                               final dateText = startDate != null
// //                                   ? DateFormat('EEE, MMM dd, yyyy')
// //                                       .format(startDate.toDate())
// //                                   : 'Unknown Date';
// //                               final status = data['status'] ?? 'Pending';

// //                               return Container(
// //                                 margin: const EdgeInsets.only(bottom: 12),
// //                                 padding: const EdgeInsets.all(14),
// //                                 decoration: BoxDecoration(
// //                                   color: Colors.grey.shade50,
// //                                   borderRadius: BorderRadius.circular(16),
// //                                   border:
// //                                       Border.all(color: Colors.grey.shade200),
// //                                 ),
// //                                 child: Row(
// //                                   children: [
// //                                     CircleAvatar(
// //                                       radius: 20,
// //                                       backgroundColor: status == 'Approved'
// //                                           ? Colors.green.shade100
// //                                           : Colors.orange.shade100,
// //                                       child: Icon(
// //                                         status == 'Approved'
// //                                             ? Icons.check_circle
// //                                             : Icons.hourglass_bottom,
// //                                         color: status == 'Approved'
// //                                             ? Colors.green.shade800
// //                                             : Colors.orange.shade800,
// //                                       ),
// //                                     ),
// //                                     const SizedBox(width: 12),
// //                                     Expanded(
// //                                       child: Column(
// //                                         crossAxisAlignment:
// //                                             CrossAxisAlignment.start,
// //                                         children: [
// //                                           Text(
// //                                             data['subject'] ??
// //                                                 'Leave Application',
// //                                             style: const TextStyle(
// //                                               fontWeight: FontWeight.bold,
// //                                               color: darkText,
// //                                             ),
// //                                           ),
// //                                           const SizedBox(height: 4),
// //                                           Text(
// //                                             dateText,
// //                                             style: TextStyle(
// //                                                 color: Colors.grey.shade600,
// //                                                 fontSize: 13),
// //                                           ),
// //                                         ],
// //                                       ),
// //                                     ),
// //                                     Container(
// //                                       padding: const EdgeInsets.symmetric(
// //                                           horizontal: 10, vertical: 6),
// //                                       decoration: BoxDecoration(
// //                                         color: status == 'Approved'
// //                                             ? Colors.green.shade50
// //                                             : Colors.orange.shade50,
// //                                         borderRadius: BorderRadius.circular(12),
// //                                       ),
// //                                       child: Text(
// //                                         status.toString().toUpperCase(),
// //                                         style: TextStyle(
// //                                           color: status == 'Approved'
// //                                               ? Colors.green.shade800
// //                                               : Colors.orange.shade800,
// //                                           fontWeight: FontWeight.bold,
// //                                           fontSize: 11,
// //                                         ),
// //                                       ),
// //                                     )
// //                                   ],
// //                                 ),
// //                               );
// //                             }).toList(),
// //                           ),
// //                       ],
// //                     ),
// //                   );
// //                 },
// //               ),
// //             ],
// //           ),
// //         );
// //       },
// //     );
// //   }

// //   Widget _buildProfileDetailRow(IconData icon, String label, String value) {
// //     return Row(
// //       children: [
// //         Icon(icon, color: maroon, size: 20),
// //         const SizedBox(width: 12),
// //         Text(label,
// //             style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
// //         const Spacer(),
// //         Expanded(
// //           child: Text(
// //             value,
// //             textAlign: TextAlign.end,
// //             style: const TextStyle(
// //                 color: darkText, fontWeight: FontWeight.bold, fontSize: 14),
// //             overflow: TextOverflow.ellipsis,
// //           ),
// //         ),
// //       ],
// //     );
// //   }

// //   // --- PAGE 2: CHECK-IN / CHECK-OUT ---
// //   Widget _buildCheckInTab() {
// //     return SingleChildScrollView(
// //       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.center,
// //         children: [
// //           const SizedBox(height: 10),
// //           Container(
// //             width: double.infinity,
// //             padding: const EdgeInsets.all(20),
// //             decoration: BoxDecoration(
// //               color: Colors.white,
// //               borderRadius: BorderRadius.circular(20),
// //               boxShadow: [
// //                 BoxShadow(
// //                   color: Colors.black.withOpacity(0.05),
// //                   blurRadius: 10,
// //                   offset: const Offset(0, 4),
// //                 )
// //               ],
// //             ),
// //             child: Column(
// //               children: [
// //                 const Icon(Icons.verified_user_rounded,
// //                     color: maroon, size: 36),
// //                 const SizedBox(height: 8),
// //                 Text(
// //                   _statusMessage,
// //                   textAlign: TextAlign.center,
// //                   style: const TextStyle(
// //                     fontSize: 14,
// //                     color: darkText,
// //                     fontWeight: FontWeight.w600,
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //           const SizedBox(height: 30),
// //           if (_isLoading)
// //             const Padding(
// //               padding: EdgeInsets.all(30.0),
// //               child: CircularProgressIndicator(color: maroon),
// //             )
// //           else
// //             GridView.count(
// //               crossAxisCount: 2,
// //               shrinkWrap: true,
// //               physics: const NeverScrollableScrollPhysics(),
// //               crossAxisSpacing: 16,
// //               mainAxisSpacing: 16,
// //               childAspectRatio: 1.0,
// //               children: [
// //                 _buildActionCard(
// //                   title: 'Check-In',
// //                   icon: Icons.fingerprint,
// //                   iconColor: const Color(0xFF2E7D32),
// //                   onTap: _verifyAndProceed,
// //                 ),
// //                 _buildActionCard(
// //                   title: 'Check-Out',
// //                   icon: Icons.exit_to_app_rounded,
// //                   iconColor: maroon,
// //                   onTap: _handleCheckOut,
// //                 ),
// //               ],
// //             ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildActionCard({
// //     required String title,
// //     required IconData icon,
// //     required Color iconColor,
// //     required VoidCallback onTap,
// //   }) {
// //     return Material(
// //       color: Colors.white,
// //       borderRadius: BorderRadius.circular(20),
// //       elevation: 2,
// //       shadowColor: Colors.black12,
// //       child: InkWell(
// //         onTap: onTap,
// //         borderRadius: BorderRadius.circular(20),
// //         child: Container(
// //           padding: const EdgeInsets.all(16),
// //           child: Column(
// //             mainAxisAlignment: MainAxisAlignment.center,
// //             children: [
// //               CircleAvatar(
// //                 radius: 28,
// //                 backgroundColor: iconColor.withOpacity(0.1),
// //                 child: Icon(icon, size: 32, color: iconColor),
// //               ),
// //               const SizedBox(height: 12),
// //               Text(
// //                 title,
// //                 textAlign: TextAlign.center,
// //                 style: TextStyle(
// //                   fontSize: 16,
// //                   fontWeight: FontWeight.bold,
// //                   color: iconColor,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }

// //   // Approval of the leave aftermath
// //   Future<bool> _isTodayApprovedLeave() async {
// //     final user = FirebaseAuth.instance.currentUser;
// //     final now = DateTime.now();
// //     final startOfDay = DateTime(now.year, now.month, now.day);
// //     final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

// //     final query = await FirebaseFirestore.instance
// //         .collection('leaves')
// //         .where('userId', isEqualTo: user?.uid)
// //         .where('status', isEqualTo: 'Approved')
// //         .where('startDate',
// //             isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
// //         .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
// //         .get();

// //     return query.docs.isNotEmpty;
// //   }

// //   // --- PAGE 3: HISTORY TAB ---
// //   Widget _buildAttendanceHistoryTab() {
// //     final user = FirebaseAuth.instance.currentUser;

// //     if (user == null) {
// //       return const Center(
// //         child: Text('Please log in to view history.',
// //             style: TextStyle(color: darkText)),
// //       );
// //     }

// //     return SingleChildScrollView(
// //       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           Row(
// //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //             children: [
// //               const Text(
// //                 'Monthly Summary',
// //                 style: TextStyle(
// //                   fontSize: 18,
// //                   fontWeight: FontWeight.bold,
// //                   color: Colors.white,
// //                 ),
// //               ),
// //               Container(
// //                 padding:
// //                     const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
// //                 decoration: BoxDecoration(
// //                   color: Colors.white,
// //                   borderRadius: BorderRadius.circular(20),
// //                   border: Border.all(color: Colors.grey.shade300),
// //                 ),
// //                 child: DropdownButtonHideUnderline(
// //                   child: DropdownButton<String>(
// //                     value: _selectedMonth,
// //                     dropdownColor: Colors.white,
// //                     icon: const Icon(Icons.arrow_drop_down, color: maroon),
// //                     style: const TextStyle(
// //                         color: darkText, fontWeight: FontWeight.bold),
// //                     onChanged: (String? newValue) {
// //                       if (newValue != null) {
// //                         setState(() => _selectedMonth = newValue);
// //                       }
// //                     },
// //                     items: _monthsList
// //                         .map<DropdownMenuItem<String>>((String value) {
// //                       return DropdownMenuItem<String>(
// //                         value: value,
// //                         child: Text(value),
// //                       );
// //                     }).toList(),
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //           const SizedBox(height: 16),
// //           StreamBuilder<QuerySnapshot>(
// //             stream: FirebaseFirestore.instance
// //                 .collection('users')
// //                 .doc(user.uid)
// //                 .collection('attendance')
// //                 .orderBy('checkInTime', descending: true)
// //                 .snapshots(),
// //             builder: (context, snapshot) {
// //               if (snapshot.connectionState == ConnectionState.waiting) {
// //                 return const Center(
// //                     child: CircularProgressIndicator(color: maroon));
// //               }

// //               final docs = snapshot.data?.docs ?? [];

// //               final filteredDocs = docs.where((doc) {
// //                 final data = doc.data() as Map<String, dynamic>;
// //                 final Timestamp? timestamp = data['checkInTime'] as Timestamp?;
// //                 if (timestamp == null) return false;

// //                 final date = timestamp.toDate();
// //                 final monthYearStr =
// //                     '${_monthNames[date.month - 1]} ${date.year}';
// //                 return monthYearStr == _selectedMonth;
// //               }).toList();

// //               int presentCount = filteredDocs.length;

// //               return Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   GridView.count(
// //                     crossAxisCount: 2,
// //                     crossAxisSpacing: 12,
// //                     mainAxisSpacing: 12,
// //                     childAspectRatio: 1.5,
// //                     shrinkWrap: true,
// //                     physics: const NeverScrollableScrollPhysics(),
// //                     children: [
// //                       _buildColoredStatCard(
// //                         'Total Attended',
// //                         '$presentCount Days',
// //                         Icons.check_circle_outline,
// //                         Colors.green.shade50,
// //                         Colors.green.shade800,
// //                       ),
// //                       _buildColoredStatCard(
// //                         'Absents',
// //                         '0 Days',
// //                         Icons.cancel_outlined,
// //                         Colors.red.shade50,
// //                         Colors.red.shade800,
// //                       ),
// //                       StreamBuilder<QuerySnapshot>(
// //                         stream: FirebaseFirestore.instance
// //                             .collection('leaves')
// //                             .where('userId', isEqualTo: user.uid)
// //                             .where('status', isEqualTo: 'Approved')
// //                             .where('startDate',
// //                                 isGreaterThanOrEqualTo: Timestamp.fromDate(
// //                                   DateTime(
// //                                     int.parse(_selectedMonth.split(' ')[1]),
// //                                     _monthNames.indexOf(
// //                                             _selectedMonth.split(' ')[0]) +
// //                                         1,
// //                                     1,
// //                                   ),
// //                                 ))
// //                             .where('startDate',
// //                                 isLessThanOrEqualTo: Timestamp.fromDate(
// //                                   DateTime(
// //                                     int.parse(_selectedMonth.split(' ')[1]),
// //                                     _monthNames.indexOf(
// //                                             _selectedMonth.split(' ')[0]) +
// //                                         2,
// //                                     0,
// //                                     23,
// //                                     59,
// //                                     59,
// //                                   ),
// //                                 ))
// //                             .snapshots(),
// //                         builder: (context, leaveCountSnapshot) {
// //                           final approvedLeaveCount = leaveCountSnapshot.hasData
// //                               ? leaveCountSnapshot.data!.docs.length
// //                               : 0;
// //                           return _buildColoredStatCard(
// //                             'Approved Leaves',
// //                             '$approvedLeaveCount Days',
// //                             Icons.event_note,
// //                             Colors.amber.shade50,
// //                             Colors.amber.shade900,
// //                           );
// //                         },
// //                       ),
// //                       _buildColoredStatCard(
// //                         'Holidays',
// //                         '0 Days',
// //                         Icons.beach_access,
// //                         Colors.blue.shade50,
// //                         Colors.blue.shade800,
// //                       ),
// //                     ],
// //                   ),
// //                   const SizedBox(height: 24),
// //                   Text(
// //                     'Detailed Logs for $_selectedMonth',
// //                     style: const TextStyle(
// //                       fontSize: 16,
// //                       fontWeight: FontWeight.bold,
// //                       color: darkText,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 12),
// //                   if (filteredDocs.isEmpty)
// //                     Container(
// //                       width: double.infinity,
// //                       padding: const EdgeInsets.all(20),
// //                       decoration: BoxDecoration(
// //                         color: Colors.white,
// //                         borderRadius: BorderRadius.circular(16),
// //                       ),
// //                       child: const Text(
// //                         'No attendance records found for this month.',
// //                         textAlign: TextAlign.center,
// //                         style: TextStyle(color: Colors.grey),
// //                       ),
// //                     )
// //                   else
// //                     ListView.builder(
// //                       shrinkWrap: true,
// //                       physics: const NeverScrollableScrollPhysics(),
// //                       itemCount: filteredDocs.length,
// //                       itemBuilder: (context, index) {
// //                         final data =
// //                             filteredDocs[index].data() as Map<String, dynamic>;

// //                         final Timestamp? checkInTs =
// //                             data['checkInTime'] as Timestamp?;
// //                         final Timestamp? checkOutTs =
// //                             data['checkOutTime'] as Timestamp?;

// //                         final String formattedDate = checkInTs != null
// //                             ? DateFormat('MMM dd, yyyy')
// //                                 .format(checkInTs.toDate())
// //                             : 'Unknown Date';

// //                         final String checkInStr = checkInTs != null
// //                             ? DateFormat('hh:mm a').format(checkInTs.toDate())
// //                             : '--:--';

// //                         final String checkOutStr = checkOutTs != null
// //                             ? DateFormat('hh:mm a').format(checkOutTs.toDate())
// //                             : 'Not Checked Out';

// //                         return _buildLogTile(
// //                           date: formattedDate,
// //                           title: 'Present',
// //                           subtitle: 'In: $checkInStr | Out: $checkOutStr',
// //                           color: checkOutTs != null
// //                               ? Colors.green.shade700
// //                               : Colors.amber.shade800,
// //                           icon: checkOutTs != null
// //                               ? Icons.check_circle_outline
// //                               : Icons.access_time,
// //                         );
// //                       },
// //                     ),
// //                 ],
// //               );
// //             },
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   // Mini-Mail//
// //   // --- MINI EMAIL LEAVE APPLICATION MODAL ---
// //   void _showLeaveApplicationModal(BuildContext context) {
// //     final formKey = GlobalKey<FormState>();
// //     final subjectController = TextEditingController();
// //     final reasonController = TextEditingController();
// //     DateTime? selectedLeaveDate;
// //     bool isSubmitting = false;

// //     showModalBottomSheet(
// //       context: context,
// //       isScrollControlled: true,
// //       backgroundColor: Colors.transparent,
// //       builder: (context) {
// //         return StatefulBuilder(
// //           builder: (BuildContext context, StateSetter setModalState) {
// //             return Padding(
// //               padding: EdgeInsets.only(
// //                 bottom: MediaQuery.of(context).viewInsets.bottom,
// //               ),
// //               child: Container(
// //                 padding: const EdgeInsets.all(24.0),
// //                 decoration: const BoxDecoration(
// //                   color: Colors.white,
// //                   borderRadius: BorderRadius.only(
// //                     topLeft: Radius.circular(28),
// //                     topRight: Radius.circular(28),
// //                   ),
// //                 ),
// //                 child: Form(
// //                   key: formKey,
// //                   child: Column(
// //                     mainAxisSize: MainAxisSize.min,
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       // --- MINI EMAIL HEADER ---
// //                       Row(
// //                         children: [
// //                           const Icon(Icons.mark_email_unread_outlined,
// //                               color: maroon, size: 28),
// //                           const SizedBox(width: 10),
// //                           const Text(
// //                             'Apply for Leave',
// //                             style: TextStyle(
// //                               fontSize: 20,
// //                               fontWeight: FontWeight.bold,
// //                               color: darkText,
// //                             ),
// //                           ),
// //                           const Spacer(),
// //                           IconButton(
// //                             icon: const Icon(Icons.close, color: Colors.grey),
// //                             onPressed: () => Navigator.pop(context),
// //                           )
// //                         ],
// //                       ),
// //                       const Divider(height: 24),

// //                       // --- SUBJECT FIELD ---
// //                       TextFormField(
// //                         controller: subjectController,
// //                         decoration: InputDecoration(
// //                           labelText: 'Subject',
// //                           hintText: 'e.g., Sick Leave / Personal Matter',
// //                           prefixIcon: const Icon(Icons.subject, color: maroon),
// //                           border: OutlineInputBorder(
// //                               borderRadius: BorderRadius.circular(12)),
// //                           filled: true,
// //                           fillColor: Colors.grey.shade50,
// //                         ),
// //                         validator: (val) => val == null || val.isEmpty
// //                             ? 'Please enter a subject'
// //                             : null,
// //                       ),
// //                       const SizedBox(height: 14),

// //                       // --- LEAVE DATE PICKER ---
// //                       InkWell(
// //                         onTap: () async {
// //                           final pickedDate = await showDatePicker(
// //                             context: context,
// //                             initialDate: DateTime.now(),
// //                             firstDate: DateTime.now(),
// //                             lastDate:
// //                                 DateTime.now().add(const Duration(days: 90)),
// //                           );
// //                           if (pickedDate != null) {
// //                             setModalState(() {
// //                               selectedLeaveDate = pickedDate;
// //                             });
// //                           }
// //                         },
// //                         child: Container(
// //                           padding: const EdgeInsets.symmetric(
// //                               horizontal: 14, vertical: 16),
// //                           decoration: BoxDecoration(
// //                             border: Border.all(color: Colors.grey.shade400),
// //                             borderRadius: BorderRadius.circular(12),
// //                             color: Colors.grey.shade50,
// //                           ),
// //                           child: Row(
// //                             children: [
// //                               const Icon(Icons.calendar_today_outlined,
// //                                   color: maroon),
// //                               const SizedBox(width: 12),
// //                               Text(
// //                                 selectedLeaveDate == null
// //                                     ? 'Select Leave Date'
// //                                     : DateFormat('EEEE, MMM dd, yyyy')
// //                                         .format(selectedLeaveDate!),
// //                                 style: TextStyle(
// //                                   color: selectedLeaveDate == null
// //                                       ? Colors.grey.shade600
// //                                       : darkText,
// //                                   fontWeight: FontWeight.w500,
// //                                 ),
// //                               ),
// //                             ],
// //                           ),
// //                         ),
// //                       ),
// //                       const SizedBox(height: 14),

// //                       // --- REASON FIELD ---
// //                       TextFormField(
// //                         controller: reasonController,
// //                         maxLines: 3,
// //                         decoration: InputDecoration(
// //                           labelText: 'Reason / Message',
// //                           hintText:
// //                               'Write a brief reason for your leave application...',
// //                           alignLabelWithHint: true,
// //                           prefixIcon: const Padding(
// //                             padding: EdgeInsets.only(bottom: 40),
// //                             child: Icon(Icons.notes, color: maroon),
// //                           ),
// //                           border: OutlineInputBorder(
// //                               borderRadius: BorderRadius.circular(12)),
// //                           filled: true,
// //                           fillColor: Colors.grey.shade50,
// //                         ),
// //                         validator: (val) => val == null || val.isEmpty
// //                             ? 'Please write your reason'
// //                             : null,
// //                       ),
// //                       const SizedBox(height: 20),

// //                       // --- SUBMIT BUTTON ---
// //                       SizedBox(
// //                         width: double.infinity,
// //                         height: 50,
// //                         child: ElevatedButton.icon(
// //                           icon: isSubmitting
// //                               ? const SizedBox.shrink()
// //                               : const Icon(Icons.send_rounded,
// //                                   color: Colors.white),
// //                           label: isSubmitting
// //                               ? const CircularProgressIndicator(
// //                                   color: Colors.white)
// //                               : const Text('Send Application',
// //                                   style: TextStyle(
// //                                       fontSize: 16,
// //                                       fontWeight: FontWeight.bold)),
// //                           style: ElevatedButton.styleFrom(
// //                             backgroundColor: maroon,
// //                             shape: RoundedRectangleBorder(
// //                                 borderRadius: BorderRadius.circular(12)),
// //                           ),
// //                           onPressed: isSubmitting
// //                               ? null
// //                               : () async {
// //                                   if (!formKey.currentState!.validate()) return;
// //                                   if (selectedLeaveDate == null) {
// //                                     ScaffoldMessenger.of(context).showSnackBar(
// //                                       const SnackBar(
// //                                           content: Text(
// //                                               'Please select a leave date.')),
// //                                     );
// //                                     return;
// //                                   }

// //                                   setModalState(() => isSubmitting = true);

// //                                   try {
// //                                     final user =
// //                                         FirebaseAuth.instance.currentUser;

// //                                     // Save Application to Firestore
// //                                     await FirebaseFirestore.instance
// //                                         .collection('leaves')
// //                                         .add({
// //                                       'userId': user?.uid,
// //                                       'userEmail': user?.email,
// //                                       'subject': subjectController.text.trim(),
// //                                       'reason': reasonController.text.trim(),
// //                                       'startDate': Timestamp.fromDate(
// //                                         DateTime(
// //                                             selectedLeaveDate!.year,
// //                                             selectedLeaveDate!.month,
// //                                             selectedLeaveDate!.day),
// //                                       ),
// //                                       'status': 'Pending',
// //                                       'createdAt': FieldValue.serverTimestamp(),
// //                                     });

// //                                     if (context.mounted) {
// //                                       Navigator.pop(context);
// //                                       ScaffoldMessenger.of(context)
// //                                           .showSnackBar(
// //                                         const SnackBar(
// //                                           content: Text(
// //                                               'Leave application sent to Admin!'),
// //                                           backgroundColor: Colors.green,
// //                                         ),
// //                                       );
// //                                     }
// //                                   } catch (e) {
// //                                     if (context.mounted) {
// //                                       ScaffoldMessenger.of(context)
// //                                           .showSnackBar(
// //                                         SnackBar(
// //                                             content: Text('Error: $e'),
// //                                             backgroundColor: Colors.red),
// //                                       );
// //                                     }
// //                                   } finally {
// //                                     setModalState(() => isSubmitting = false);
// //                                   }
// //                                 },
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             );
// //           },
// //         );
// //       },
// //     );
// //   }

// //   // --- PAGE 4: NOTIFICATIONS TAB ---
// //   Widget _buildNotificationsTab() {
// //     final user = FirebaseAuth.instance.currentUser;

// //     return Padding(
// //       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           const Text(
// //             'Announcements & Leave Approvals',
// //             style: TextStyle(
// //                 fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
// //           ),
// //           const SizedBox(height: 12),
// //           Expanded(
// //             child: StreamBuilder<QuerySnapshot>(
// //               stream: FirebaseFirestore.instance
// //                   .collection('notifications')
// //                   .where('recipientId',
// //                       whereIn: ['all', user?.uid ?? '']).snapshots(),
// //               builder: (context, snapshot) {
// //                 if (snapshot.connectionState == ConnectionState.waiting) {
// //                   return const Center(
// //                       child: CircularProgressIndicator(color: maroon));
// //                 }

// //                 final docs = snapshot.data?.docs ?? [];

// //                 if (docs.isEmpty) {
// //                   return Center(
// //                     child: Column(
// //                       mainAxisAlignment: MainAxisAlignment.center,
// //                       children: const [
// //                         Icon(Icons.notifications_off_outlined,
// //                             size: 50, color: Colors.grey),
// //                         SizedBox(height: 12),
// //                         Text('No notifications found',
// //                             style: TextStyle(color: Colors.grey)),
// //                       ],
// //                     ),
// //                   );
// //                 }

// //                 return ListView.builder(
// //                   itemCount: docs.length,
// //                   itemBuilder: (context, index) {
// //                     final data = docs[index].data() as Map<String, dynamic>;
// //                     final title = data['title'] ?? 'Notice';
// //                     final body = data['body'] ?? '';
// //                     final type = data['type'] ?? 'general';
// //                     final Timestamp? timestamp =
// //                         data['createdAt'] as Timestamp?;

// //                     IconData typeIcon = Icons.info_outline;
// //                     Color iconColor = Colors.blue;

// //                     if (type == 'holiday') {
// //                       typeIcon = Icons.beach_access;
// //                       iconColor = Colors.orange;
// //                     } else if (type == 'leave') {
// //                       typeIcon = Icons.event_available;
// //                       iconColor = Colors.green;
// //                     } else if (type == 'success') {
// //                       typeIcon = Icons.check_circle_outline;
// //                       iconColor = Colors.green;
// //                     }

// //                     return Container(
// //                       margin: const EdgeInsets.only(bottom: 12),
// //                       padding: const EdgeInsets.all(16),
// //                       decoration: BoxDecoration(
// //                         color: Colors.white,
// //                         borderRadius: BorderRadius.circular(16),
// //                         boxShadow: [
// //                           BoxShadow(
// //                             color: Colors.black.withOpacity(0.03),
// //                             blurRadius: 8,
// //                             offset: const Offset(0, 3),
// //                           )
// //                         ],
// //                       ),
// //                       child: Row(
// //                         crossAxisAlignment: CrossAxisAlignment.start,
// //                         children: [
// //                           CircleAvatar(
// //                             backgroundColor: iconColor.withOpacity(0.12),
// //                             child: Icon(typeIcon, color: iconColor),
// //                           ),
// //                           const SizedBox(width: 14),
// //                           Expanded(
// //                             child: Column(
// //                               crossAxisAlignment: CrossAxisAlignment.start,
// //                               children: [
// //                                 Text(
// //                                   title,
// //                                   style: const TextStyle(
// //                                       color: darkText,
// //                                       fontWeight: FontWeight.bold,
// //                                       fontSize: 15),
// //                                 ),
// //                                 const SizedBox(height: 4),
// //                                 Text(
// //                                   body,
// //                                   style: TextStyle(
// //                                       color: Colors.grey.shade700,
// //                                       fontSize: 13),
// //                                 ),
// //                                 if (timestamp != null) ...[
// //                                   const SizedBox(height: 8),
// //                                   Text(
// //                                     DateFormat('hh:mm a - MMM dd, yyyy')
// //                                         .format(timestamp.toDate()),
// //                                     style: const TextStyle(
// //                                         color: Colors.grey, fontSize: 11),
// //                                   ),
// //                                 ]
// //                               ],
// //                             ),
// //                           ),
// //                         ],
// //                       ),
// //                     );
// //                   },
// //                 );
// //               },
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   // --- PAGE 5: SETTINGS PAGE ---
// //   Widget _buildSettingsTab() {
// //     return Padding(
// //       padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           const Text(
// //             'Account Settings',
// //             style: TextStyle(
// //                 fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
// //           ),
// //           const SizedBox(height: 16),
// //           Container(
// //             decoration: BoxDecoration(
// //               color: Colors.white,
// //               borderRadius: BorderRadius.circular(16),
// //               boxShadow: [
// //                 BoxShadow(
// //                   color: Colors.black.withOpacity(0.04),
// //                   blurRadius: 10,
// //                   offset: const Offset(0, 4),
// //                 )
// //               ],
// //             ),
// //             child: ListTile(
// //               leading: const Icon(Icons.lock_outline, color: maroon),
// //               title: const Text('Security & Password',
// //                   style:
// //                       TextStyle(color: darkText, fontWeight: FontWeight.bold)),
// //               subtitle: const Text('Update your current password',
// //                   style: TextStyle(color: Colors.grey, fontSize: 12)),
// //               trailing: const Icon(Icons.arrow_forward_ios,
// //                   color: Colors.grey, size: 16),
// //               onTap: () {
// //                 Navigator.push(
// //                   context,
// //                   MaterialPageRoute(
// //                       builder: (context) =>
// //                           const SecuritySettingsScreen(maroon: maroon)),
// //                 );
// //               },
// //             ),
// //           )
// //         ],
// //       ),
// //     );
// //   }

// //   // --- HELPER COMPONENTS ---
// //   Widget _buildColoredStatCard(String label, String value, IconData icon,
// //       Color bgFillColor, Color textColor) {
// //     return Container(
// //       padding: const EdgeInsets.all(12),
// //       decoration: BoxDecoration(
// //         color: bgFillColor,
// //         borderRadius: BorderRadius.circular(16),
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         mainAxisAlignment: MainAxisAlignment.center,
// //         children: [
// //           Row(
// //             children: [
// //               Icon(icon, color: textColor, size: 18),
// //               const SizedBox(width: 6),
// //               Expanded(
// //                 child: Text(
// //                   label,
// //                   style: TextStyle(
// //                       color: textColor,
// //                       fontSize: 12,
// //                       fontWeight: FontWeight.w600),
// //                   overflow: TextOverflow.ellipsis,
// //                 ),
// //               ),
// //             ],
// //           ),
// //           const SizedBox(height: 8),
// //           Text(
// //             value,
// //             style: TextStyle(
// //                 color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildLogTile({
// //     required String date,
// //     required String title,
// //     required String subtitle,
// //     required Color color,
// //     required IconData icon,
// //   }) {
// //     return Container(
// //       margin: const EdgeInsets.only(bottom: 10),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(16),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.black.withOpacity(0.03),
// //             blurRadius: 6,
// //             offset: const Offset(0, 2),
// //           )
// //         ],
// //       ),
// //       child: ListTile(
// //         leading: CircleAvatar(
// //           backgroundColor: color.withOpacity(0.12),
// //           child: Icon(icon, color: color),
// //         ),
// //         title: Text(
// //           '$title - $date',
// //           style: const TextStyle(
// //               color: darkText, fontWeight: FontWeight.bold, fontSize: 14),
// //         ),
// //         subtitle: Text(
// //           subtitle,
// //           style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
// //         ),
// //         trailing: const Icon(
// //           Icons.access_time_filled,
// //           color: Colors.grey,
// //           size: 18,
// //         ),
// //       ),
// //     );
// //   }
// // }

// // // --- SUB-PAGE: SECURITY SETTINGS ---
// // class SecuritySettingsScreen extends StatefulWidget {
// //   final Color maroon;
// //   const SecuritySettingsScreen({super.key, required this.maroon});

// //   @override
// //   State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
// // }

// // class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
// //   final _securityFormKey = GlobalKey<FormState>();
// //   final TextEditingController _currentPasswordController =
// //       TextEditingController();
// //   final TextEditingController _newPasswordController = TextEditingController();
// //   final TextEditingController _confirmPasswordController =
// //       TextEditingController();
// //   bool _isChangingPassword = false;
// //   bool _obscureCurrent = true;
// //   bool _obscureNew = true;
// //   bool _obscureConfirm = true;

// //   @override
// //   void dispose() {
// //     _currentPasswordController.dispose();
// //     _newPasswordController.dispose();
// //     _confirmPasswordController.dispose();
// //     super.dispose();
// //   }

// //   Future<void> _updatePassword() async {
// //     if (!_securityFormKey.currentState!.validate()) return;

// //     setState(() => _isChangingPassword = true);

// //     try {
// //       User? user = FirebaseAuth.instance.currentUser;

// //       if (user != null && user.email != null) {
// //         AuthCredential credential = EmailAuthProvider.credential(
// //           email: user.email!,
// //           password: _currentPasswordController.text,
// //         );

// //         await user.reauthenticateWithCredential(credential);
// //         await user.updatePassword(_newPasswordController.text);

// //         if (!mounted) return;
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(
// //             content: Text('Password updated successfully!'),
// //             backgroundColor: Colors.green,
// //           ),
// //         );

// //         Navigator.pop(context);
// //       }
// //     } on FirebaseAuthException catch (e) {
// //       if (!mounted) return;
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text(e.message ?? 'Failed to update password.'),
// //           backgroundColor: Colors.red,
// //         ),
// //       );
// //     } catch (e) {
// //       if (!mounted) return;
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(
// //           content: Text('Error: $e'),
// //           backgroundColor: Colors.red,
// //         ),
// //       );
// //     } finally {
// //       if (mounted) {
// //         setState(() => _isChangingPassword = false);
// //       }
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: const Color(0xFFFAFAFA),
// //       body: Stack(
// //         children: [
// //           // Header Background Curve
// //           ClipPath(
// //             clipper: WavyHeaderClipper(),
// //             child: Container(
// //               height: 220,
// //               width: double.infinity,
// //               color: widget.maroon,
// //             ),
// //           ),
// //           SafeArea(
// //             child: SingleChildScrollView(
// //               padding:
// //                   const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
// //               child: Form(
// //                 key: _securityFormKey,
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Row(
// //                       children: [
// //                         IconButton(
// //                           icon:
// //                               const Icon(Icons.arrow_back, color: Colors.white),
// //                           onPressed: () => Navigator.pop(context),
// //                         ),
// //                         const SizedBox(width: 8),
// //                         const Text(
// //                           'Security & Password',
// //                           style: TextStyle(
// //                             fontSize: 20,
// //                             fontWeight: FontWeight.bold,
// //                             color: Colors.white,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                     const SizedBox(height: 50),
// //                     Container(
// //                       padding: const EdgeInsets.all(20),
// //                       decoration: BoxDecoration(
// //                         color: Colors.white,
// //                         borderRadius: BorderRadius.circular(20),
// //                         boxShadow: [
// //                           BoxShadow(
// //                             color: Colors.black.withOpacity(0.06),
// //                             blurRadius: 15,
// //                             offset: const Offset(0, 5),
// //                           )
// //                         ],
// //                       ),
// //                       child: Column(
// //                         crossAxisAlignment: CrossAxisAlignment.start,
// //                         children: [
// //                           const Text(
// //                             'Update Password',
// //                             style: TextStyle(
// //                               fontSize: 18,
// //                               fontWeight: FontWeight.bold,
// //                               color: Color(0xFF2C2C2C),
// //                             ),
// //                           ),
// //                           const SizedBox(height: 6),
// //                           Text(
// //                             'Update your account password below to ensure your profile stays secure.',
// //                             style: TextStyle(
// //                                 color: Colors.grey.shade600, fontSize: 13),
// //                           ),
// //                           const SizedBox(height: 24),
// //                           _buildPasswordField(
// //                             controller: _currentPasswordController,
// //                             labelText: 'Current Password',
// //                             obscureText: _obscureCurrent,
// //                             onToggleVisibility: () => setState(
// //                                 () => _obscureCurrent = !_obscureCurrent),
// //                             validator: (value) {
// //                               if (value == null || value.isEmpty) {
// //                                 return 'Please enter your current password';
// //                               }
// //                               return null;
// //                             },
// //                           ),
// //                           const SizedBox(height: 16),
// //                           _buildPasswordField(
// //                             controller: _newPasswordController,
// //                             labelText: 'New Password',
// //                             obscureText: _obscureNew,
// //                             onToggleVisibility: () =>
// //                                 setState(() => _obscureNew = !_obscureNew),
// //                             validator: (value) {
// //                               if (value == null || value.isEmpty) {
// //                                 return 'Please enter a new password';
// //                               }
// //                               if (value.length < 6) {
// //                                 return 'Password must be at least 6 characters long';
// //                               }
// //                               return null;
// //                             },
// //                           ),
// //                           const SizedBox(height: 16),
// //                           _buildPasswordField(
// //                             controller: _confirmPasswordController,
// //                             labelText: 'Confirm New Password',
// //                             obscureText: _obscureConfirm,
// //                             onToggleVisibility: () => setState(
// //                                 () => _obscureConfirm = !_obscureConfirm),
// //                             validator: (value) {
// //                               if (value == null || value.isEmpty) {
// //                                 return 'Please confirm your new password';
// //                               }
// //                               if (value != _newPasswordController.text) {
// //                                 return 'Passwords do not match';
// //                               }
// //                               return null;
// //                             },
// //                           ),
// //                           const SizedBox(height: 28),
// //                           SizedBox(
// //                             width: double.infinity,
// //                             height: 50,
// //                             child: ElevatedButton(
// //                               onPressed:
// //                                   _isChangingPassword ? null : _updatePassword,
// //                               style: ElevatedButton.styleFrom(
// //                                 backgroundColor: widget.maroon,
// //                                 foregroundColor: Colors.white,
// //                                 shape: RoundedRectangleBorder(
// //                                   borderRadius: BorderRadius.circular(14),
// //                                 ),
// //                                 elevation: 2,
// //                               ),
// //                               child: _isChangingPassword
// //                                   ? const SizedBox(
// //                                       height: 22,
// //                                       width: 22,
// //                                       child: CircularProgressIndicator(
// //                                         color: Colors.white,
// //                                         strokeWidth: 2.5,
// //                                       ),
// //                                     )
// //                                   : const Text(
// //                                       'Update Password',
// //                                       style: TextStyle(
// //                                         fontSize: 16,
// //                                         fontWeight: FontWeight.bold,
// //                                       ),
// //                                     ),
// //                             ),
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _buildPasswordField({
// //     required TextEditingController controller,
// //     required String labelText,
// //     required bool obscureText,
// //     required VoidCallback onToggleVisibility,
// //     required String? Function(String?) validator,
// //   }) {
// //     return TextFormField(
// //       controller: controller,
// //       obscureText: obscureText,
// //       style: const TextStyle(color: Color(0xFF2C2C2C)),
// //       validator: validator,
// //       decoration: InputDecoration(
// //         labelText: labelText,
// //         labelStyle: TextStyle(color: Colors.grey.shade600),
// //         prefixIcon: Icon(Icons.lock_outline, color: widget.maroon),
// //         suffixIcon: IconButton(
// //           icon: Icon(
// //             obscureText ? Icons.visibility_off : Icons.visibility,
// //             color: Colors.grey,
// //           ),
// //           onPressed: onToggleVisibility,
// //         ),
// //         enabledBorder: OutlineInputBorder(
// //           borderRadius: BorderRadius.circular(12),
// //           borderSide: BorderSide(color: Colors.grey.shade300),
// //         ),
// //         focusedBorder: OutlineInputBorder(
// //           borderRadius: BorderRadius.circular(12),
// //           borderSide: BorderSide(color: widget.maroon, width: 2),
// //         ),
// //         errorBorder: OutlineInputBorder(
// //           borderRadius: BorderRadius.circular(12),
// //           borderSide: const BorderSide(color: Colors.red),
// //         ),
// //         focusedErrorBorder: OutlineInputBorder(
// //           borderRadius: BorderRadius.circular(12),
// //           borderSide: const BorderSide(color: Colors.red, width: 2),
// //         ),
// //         filled: true,
// //         fillColor: Colors.grey.shade50,
// //       ),
// //     );
// //   }
// // }

// // // Custom Wave Clipper Header
// // class WavyHeaderClipper extends CustomClipper<Path> {
// //   @override
// //   Path getClip(Size size) {
// //     Path path = Path();
// //     path.lineTo(0, size.height - 60);

// //     var firstControlPoint = Offset(size.width * 0.25, size.height);
// //     var firstEndPoint = Offset(size.width * 0.55, size.height - 40);
// //     path.quadraticBezierTo(
// //       firstControlPoint.dx,
// //       firstControlPoint.dy,
// //       firstEndPoint.dx,
// //       firstEndPoint.dy,
// //     );

// //     var secondControlPoint = Offset(size.width * 0.8, size.height - 80);
// //     var secondEndPoint = Offset(size.width, size.height - 20);
// //     path.quadraticBezierTo(
// //       secondControlPoint.dx,
// //       secondControlPoint.dy,
// //       secondEndPoint.dx,
// //       secondEndPoint.dy,
// //     );

// //     path.lineTo(size.width, 0);
// //     path.close();
// //     return path;
// //   }

// //   @override
// //   bool shouldReclip(CustomClipper<Path> oldClipper) => false;
// // }

// dashboard_screen.dart

// attendance_screen.dart//
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:network_info_plus/network_info_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:intl/intl.dart';
// import 'login_screen.dart';
// import 'qr_scanner_screen.dart';

// // ─────────────────────────────────────────────
// // App-wide colors
// // ─────────────────────────────────────────────
// class AppColors {
//   static const Color maroon = Color(0xFF800000);
//   static const Color lightBg = Color(0xFFFAFAFA);
//   static const Color darkText = Color(0xFF2C2C2C);

//   AppColors._();
// }

// // ─────────────────────────────────────────────
// // Dashboard Screen
// // ─────────────────────────────────────────────
// class DashboardScreen extends StatefulWidget {
//   final String userName;

//   const DashboardScreen({super.key, required this.userName});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   int _selectedIndex = 0;
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

//   String _statusMessage = 'Ready to verify and mark attendance';
//   bool _isLoading = false;

//   static const List<String> _monthNames = [
//     'January',
//     'February',
//     'March',
//     'April',
//     'May',
//     'June',
//     'July',
//     'August',
//     'September',
//     'October',
//     'November',
//     'December',
//   ];

//   late final List<String> _monthsList;
//   late String _selectedMonth;

//   static const List<String> _pageTitles = [
//     'Portal Home',
//     'Attendance Terminal',
//     'Attendance History',
//     'Notifications',
//     'Settings',
//   ];

//   @override
//   void initState() {
//     super.initState();
//     final now = DateTime.now();
//     _monthsList = _monthNames.map((m) => '$m ${now.year}').toList();
//     _selectedMonth = '${_monthNames[now.month - 1]} ${now.year}';
//   }

//   // ─────────────────────────────────────────────
//   // Auth
//   // ─────────────────────────────────────────────

//   Future<void> _handleLogout() async {
//     await FirebaseAuth.instance.signOut();
//     if (!mounted) return;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => const LoginScreen()),
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Check-In
//   // ─────────────────────────────────────────────

//   Future<void> _verifyAndProceed() async {
//     try {
//       if (await _isTodayApprovedLeave()) {
//         if (!mounted) return;
//         _showSnackBar(
//           'Leave is already approved for today. Attendance is not required.',
//           Colors.green,
//         );
//         return;
//       }
//     } catch (e) {
//       debugPrint('Leave check error: $e');
//     }

//     _setLoading(true, 'Checking device permissions...');

//     try {
//       await [Permission.location, Permission.camera].request();
//       final deviceId = await _getDeviceId();

//       _setLoading(true, 'Verifying office Wi-Fi network...');
//       final bssid = await _getWifiBssid();

//       if (bssid == null || bssid.isEmpty) {
//         _setLoading(
//           false,
//           'Access Blocked: Unable to detect office Wi-Fi. '
//           'Please connect to the office network.',
//         );
//         _showSnackBar(
//           'Unable to detect Wi-Fi BSSID. Connect to office Wi-Fi.',
//           Colors.red,
//           duration: const Duration(seconds: 6),
//         );
//         return;
//       }

//       debugPrint('=== DETECTED BSSID: $bssid ===');
//       _showSnackBar('Detected BSSID: $bssid', Colors.blue);

//       if (!await _isBssidAllowed(bssid)) {
//         _setLoading(
//             false, 'Access Blocked: Not connected to authorized office Wi-Fi.');
//         _showSnackBar(
//           'Blocked: BSSID "$bssid" is not authorized.',
//           Colors.red,
//           duration: const Duration(seconds: 6),
//         );
//         return;
//       }

//       _setLoading(false, _statusMessage);

//       if (!mounted) return;
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => QRScannerScreen(
//             currentBssid: bssid,
//             currentDeviceId: deviceId,
//           ),
//         ),
//       );
//     } catch (e, stack) {
//       debugPrint('Validation error: $e\n$stack');
//       _setLoading(false, 'Error during validation: $e');
//       _showSnackBar('Validation Error: $e', Colors.red);
//     }
//   }

//   Future<String> _getDeviceId() async {
//     try {
//       final info = await DeviceInfoPlugin().androidInfo;
//       return info.id;
//     } catch (e) {
//       debugPrint('Device ID error: $e');
//       return 'unknown_device';
//     }
//   }

//   Future<String?> _getWifiBssid() async {
//     try {
//       return await NetworkInfo().getWifiBSSID();
//     } catch (e) {
//       debugPrint('BSSID fetch error: $e');
//       return null;
//     }
//   }

//   Future<bool> _isBssidAllowed(String bssid) async {
//     final doc = await FirebaseFirestore.instance
//         .collection('config')
//         .doc('attendance')
//         .get();

//     if (!doc.exists) return true;

//     final data = doc.data() ?? {};
//     final allowedBssids = (data['allowedBssids'] as List<dynamic>?) ?? [];

//     if (allowedBssids.isEmpty) return true;
//     return allowedBssids.contains(bssid);
//   }

//   // ─────────────────────────────────────────────
//   // Check-Out
//   // ─────────────────────────────────────────────

//   Future<void> _handleCheckOut() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//     final docRef = FirebaseFirestore.instance
//         .collection('users')
//         .doc(user.uid)
//         .collection('attendance')
//         .doc(today);

//     final snap = await docRef.get();
//     final data = snap.data();

//     if (!snap.exists || data?['checkInTime'] == null) {
//       _showSnackBar(
//           'Cannot check out: You have not checked in today!', Colors.orange);
//       return;
//     }

//     if (data?['checkOutTime'] != null) {
//       _showSnackBar('You have already checked out for today.', Colors.blue);
//       return;
//     }

//     final now = DateTime.now();
//     final confirmed = await _showCheckOutDialog(now);
//     if (confirmed != true) return;

//     _setLoading(true, 'Recording check-out...');

//     try {
//       await docRef.update({
//         'checkOutTime': FieldValue.serverTimestamp(),
//         'status': 'Completed',
//       });

//       if (!mounted) return;
//       _showSnackBar('Successfully checked-out', Colors.green);
//       setState(() {
//         _statusMessage = 'You have checked out successfully.';
//         _selectedIndex = 0;
//       });
//     } catch (e) {
//       _showSnackBar('Error recording check-out: $e', Colors.red);
//     } finally {
//       _setLoading(false, _statusMessage);
//     }
//   }

//   Future<bool?> _showCheckOutDialog(DateTime now) {
//     return showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Confirm Check-Out',
//             style: TextStyle(
//                 color: AppColors.darkText, fontWeight: FontWeight.bold)),
//         content: Text(
//           'Timestamp: ${DateFormat('hh:mm a - MMM dd, yyyy').format(now)}'
//           '\n\nDo you want to proceed?',
//           style: const TextStyle(color: AppColors.darkText),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.maroon,
//               shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10)),
//             ),
//             child:
//                 const Text('Check-Out', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Leave helpers
//   // ─────────────────────────────────────────────

//   Future<bool> _isTodayApprovedLeave() async {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     if (uid == null) return false;

//     final now = DateTime.now();
//     final start = DateTime(now.year, now.month, now.day);
//     final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

//     final query = await FirebaseFirestore.instance
//         .collection('leaves')
//         .where('userId', isEqualTo: uid)
//         .where('status', isEqualTo: 'Approved')
//         .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
//         .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
//         .get();

//     return query.docs.isNotEmpty;
//   }

//   ({DateTime start, DateTime end}) _monthDateRange(String monthYear) {
//     final parts = monthYear.split(' ');
//     final monthIndex = _monthNames.indexOf(parts[0]) + 1;
//     final year = int.parse(parts[1]);
//     final start = DateTime(year, monthIndex, 1);
//     final end = DateTime(year, monthIndex + 1, 0, 23, 59, 59);
//     return (start: start, end: end);
//   }

//   // ─────────────────────────────────────────────
//   // UI helpers
//   // ─────────────────────────────────────────────

//   void _setLoading(bool loading, [String? message]) {
//     if (!mounted) return;
//     setState(() {
//       _isLoading = loading;
//       if (message != null) _statusMessage = message;
//     });
//   }

//   void _showSnackBar(String message, Color color,
//       {Duration duration = const Duration(seconds: 4)}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: color,
//         behavior: SnackBarBehavior.floating,
//         duration: duration,
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Build
//   // ─────────────────────────────────────────────

//   Widget _buildBodyContent() {
//     switch (_selectedIndex) {
//       case 0:
//         return _buildHomePage();
//       case 1:
//         return _buildCheckInTab();
//       case 2:
//         return _buildAttendanceHistoryTab();
//       case 3:
//         return _buildNotificationsTab();
//       case 4:
//         return _buildSettingsTab();
//       default:
//         return _buildHomePage();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: AppColors.lightBg,
//       drawer: _buildSlideDrawer(),
//       body: Stack(
//         children: [
//           ClipPath(
//             clipper: WavyHeaderClipper(),
//             child: Container(
//               height: 250,
//               width: double.infinity,
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [AppColors.maroon, Color(0xFFA01A1A)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//               ),
//             ),
//           ),
//           SafeArea(
//             child: Column(
//               children: [
//                 Padding(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       IconButton(
//                         icon: const Icon(Icons.menu,
//                             color: Colors.white, size: 28),
//                         onPressed: () =>
//                             _scaffoldKey.currentState?.openDrawer(),
//                       ),
//                       Text(
//                         _pageTitles[_selectedIndex],
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.logout,
//                             color: Colors.white, size: 24),
//                         onPressed: _handleLogout,
//                       ),
//                     ],
//                   ),
//                 ),
//                 Expanded(child: _buildBodyContent()),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Drawer
//   // ─────────────────────────────────────────────

//   Widget _buildSlideDrawer() {
//     final user = FirebaseAuth.instance.currentUser;

//     return Drawer(
//       child: Container(
//         color: AppColors.lightBg,
//         child: ListView(
//           padding: EdgeInsets.zero,
//           children: [
//             StreamBuilder<DocumentSnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('users')
//                   .doc(user?.uid)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 final data = snapshot.data?.data() as Map<String, dynamic>?;
//                 final name = (data?['name'] as String?)?.isNotEmpty == true
//                     ? data!['name'] as String
//                     : (widget.userName.isNotEmpty ? widget.userName : 'User');
//                 final role = data?['role'] as String? ?? 'Intern';

//                 return DrawerHeader(
//                   decoration: const BoxDecoration(color: AppColors.maroon),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       CircleAvatar(
//                         radius: 30,
//                         backgroundColor: Colors.white,
//                         child: Text(
//                           name[0].toUpperCase(),
//                           style: const TextStyle(
//                             fontSize: 26,
//                             color: AppColors.maroon,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       Text(name,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 18,
//                           )),
//                       Text('$role | ${user?.email ?? ''}',
//                           style: const TextStyle(
//                               color: Colors.white70, fontSize: 12)),
//                     ],
//                   ),
//                 );
//               },
//             ),
//             _buildDrawerTile(0, 'Home', Icons.home_rounded),
//             _buildDrawerTile(1, 'Mark Attendance', Icons.fingerprint),
//             _buildDrawerTile(2, 'Attendance History', Icons.history_rounded),
//             _buildDrawerTile(3, 'Notifications', Icons.notifications_rounded),
//             _buildDrawerTile(4, 'Settings', Icons.settings_rounded),
//             const Divider(color: Colors.black12),
//             ListTile(
//               leading: const Icon(Icons.logout, color: AppColors.maroon),
//               title: const Text('Logout',
//                   style: TextStyle(
//                       color: AppColors.darkText, fontWeight: FontWeight.w600)),
//               onTap: _handleLogout,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildDrawerTile(int index, String title, IconData icon) {
//     final isSelected = _selectedIndex == index;
//     return ListTile(
//       selected: isSelected,
//       selectedTileColor: AppColors.maroon.withOpacity(0.08),
//       leading: Icon(icon,
//           color: isSelected ? AppColors.maroon : Colors.grey.shade700),
//       title: Text(
//         title,
//         style: TextStyle(
//           color: isSelected ? AppColors.maroon : AppColors.darkText,
//           fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
//         ),
//       ),
//       onTap: () {
//         setState(() => _selectedIndex = index);
//         Navigator.pop(context);
//       },
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Page 0 — Home
//   // ─────────────────────────────────────────────

//   Widget _buildHomePage() {
//     final user = FirebaseAuth.instance.currentUser;

//     return StreamBuilder<DocumentSnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('users')
//           .doc(user?.uid)
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(
//               child: CircularProgressIndicator(color: AppColors.maroon));
//         }

//         final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
//         final name = (data['name'] as String?)?.isNotEmpty == true
//             ? data['name'] as String
//             : (widget.userName.isNotEmpty ? widget.userName : 'Intern Name');
//         final role = data['role'] as String? ?? 'Intern';
//         final department =
//             data['department'] as String? ?? 'Flutter Frontend Development';

//         return SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const SizedBox(height: 10),
//               _ShadowCard(
//                 child: Row(
//                   children: [
//                     CircleAvatar(
//                       radius: 32,
//                       backgroundColor: AppColors.maroon.withOpacity(0.1),
//                       child: const Icon(Icons.person,
//                           size: 38, color: AppColors.maroon),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text('Welcome back,',
//                               style: TextStyle(
//                                   color: Colors.grey.shade600, fontSize: 13)),
//                           Text(name,
//                               style: const TextStyle(
//                                 color: AppColors.darkText,
//                                 fontSize: 20,
//                                 fontWeight: FontWeight.bold,
//                               )),
//                           const SizedBox(height: 6),
//                           _RoleBadge(role: role),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 24),
//               const _SectionLabel('Quick Overview'),
//               const SizedBox(height: 12),
//               _ShadowCard(
//                 child: Column(
//                   children: [
//                     _buildProfileDetailRow(
//                         Icons.business_rounded, 'Department', department),
//                     const Divider(color: Colors.black12, height: 24),
//                     _buildProfileDetailRow(
//                         Icons.email_rounded, 'Email', user?.email ?? 'N/A'),
//                     const Divider(color: Colors.black12, height: 24),
//                     _buildProfileDetailRow(
//                       Icons.calendar_today_rounded,
//                       'Today',
//                       DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now()),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 22),
//               _ShadowCard(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: const [
//                         Icon(Icons.beach_access_rounded,
//                             color: AppColors.maroon, size: 26),
//                         SizedBox(width: 12),
//                         Text('Leave Application',
//                             style: TextStyle(
//                               color: AppColors.darkText,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             )),
//                       ],
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       'Submit an e-application for leave. Once approved by '
//                       'admin, that day will be marked as Leave Approved.',
//                       style:
//                           TextStyle(color: Colors.grey.shade700, fontSize: 14),
//                     ),
//                     const SizedBox(height: 18),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 48,
//                       child: ElevatedButton.icon(
//                         icon:
//                             const Icon(Icons.send_rounded, color: Colors.white),
//                         label: const Text('Apply for Leave',
//                             style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold)),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: AppColors.maroon,
//                           shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(14)),
//                         ),
//                         onPressed: () => _showLeaveApplicationModal(context),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 22),
//               _buildLeaveStatusCard(user),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildLeaveStatusCard(User? user) {
//     return StreamBuilder<QuerySnapshot>(
//       stream: user == null
//           ? const Stream.empty()
//           : FirebaseFirestore.instance
//               .collection('leaves')
//               .where('userId', isEqualTo: user.uid)
//               .orderBy('createdAt', descending: true)
//               .limit(4)
//               .snapshots(),
//       builder: (context, leaveSnapshot) {
//         if (leaveSnapshot.connectionState == ConnectionState.waiting) {
//           return const _ShadowCard(
//             child: Center(
//               child: CircularProgressIndicator(color: AppColors.maroon),
//             ),
//           );
//         }

//         final leaveDocs = leaveSnapshot.data?.docs ?? [];
//         final today = DateTime.now();

//         bool isToday(Timestamp? ts) {
//           if (ts == null) return false;
//           final d = ts.toDate();
//           return d.year == today.year &&
//               d.month == today.month &&
//               d.day == today.day;
//         }

//         final todayApproved = leaveDocs.any((doc) {
//           final d = doc.data() as Map<String, dynamic>;
//           return isToday(d['startDate'] as Timestamp?) &&
//               d['status'] == 'Approved';
//         });

//         final todayPending = leaveDocs.any((doc) {
//           final d = doc.data() as Map<String, dynamic>;
//           return isToday(d['startDate'] as Timestamp?) &&
//               d['status'] == 'Pending';
//         });

//         return _ShadowCard(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const _SectionLabel('Leave Status'),
//               const SizedBox(height: 8),
//               Text(
//                 todayApproved
//                     ? "Today's leave has been approved. Attendance won't be required."
//                     : todayPending
//                         ? 'Your leave for today is pending approval.'
//                         : 'No leave application exists for today.',
//                 style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
//               ),
//               const SizedBox(height: 16),
//               if (leaveDocs.isEmpty)
//                 Container(
//                   width: double.infinity,
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: Colors.grey.shade50,
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   child: const Text(
//                     'No recent leave applications. Use the button above to submit one.',
//                     style: TextStyle(color: Colors.black87),
//                   ),
//                 )
//               else
//                 ...leaveDocs.map((doc) {
//                   final d = doc.data() as Map<String, dynamic>;
//                   final ts = d['startDate'] as Timestamp?;
//                   final dateText = ts != null
//                       ? DateFormat('EEE, MMM dd, yyyy').format(ts.toDate())
//                       : 'Unknown Date';
//                   final status = (d['status'] as String?) ?? 'Pending';
//                   final isApproved = status == 'Approved';

//                   return Container(
//                     margin: const EdgeInsets.only(bottom: 12),
//                     padding: const EdgeInsets.all(14),
//                     decoration: BoxDecoration(
//                       color: Colors.grey.shade50,
//                       borderRadius: BorderRadius.circular(16),
//                       border: Border.all(color: Colors.grey.shade200),
//                     ),
//                     child: Row(
//                       children: [
//                         CircleAvatar(
//                           radius: 20,
//                           backgroundColor: isApproved
//                               ? Colors.green.shade100
//                               : Colors.orange.shade100,
//                           child: Icon(
//                             isApproved
//                                 ? Icons.check_circle
//                                 : Icons.hourglass_bottom,
//                             color: isApproved
//                                 ? Colors.green.shade800
//                                 : Colors.orange.shade800,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 d['subject'] as String? ?? 'Leave Application',
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   color: AppColors.darkText,
//                                 ),
//                               ),
//                               const SizedBox(height: 4),
//                               Text(dateText,
//                                   style: TextStyle(
//                                       color: Colors.grey.shade600,
//                                       fontSize: 13)),
//                             ],
//                           ),
//                         ),
//                         _StatusBadge(status: status, isApproved: isApproved),
//                       ],
//                     ),
//                   );
//                 }),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildProfileDetailRow(IconData icon, String label, String value) {
//     return Row(
//       children: [
//         Icon(icon, color: AppColors.maroon, size: 20),
//         const SizedBox(width: 12),
//         Text(label,
//             style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
//         const Spacer(),
//         Expanded(
//           child: Text(
//             value,
//             textAlign: TextAlign.end,
//             style: const TextStyle(
//               color: AppColors.darkText,
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//             ),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Page 1 — Check-In / Check-Out
//   // ─────────────────────────────────────────────

//   Widget _buildCheckInTab() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           const SizedBox(height: 10),
//           _ShadowCard(
//             child: Column(
//               children: [
//                 const Icon(Icons.verified_user_rounded,
//                     color: AppColors.maroon, size: 36),
//                 const SizedBox(height: 8),
//                 Text(
//                   _statusMessage,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     color: AppColors.darkText,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 30),
//           if (_isLoading)
//             const Padding(
//               padding: EdgeInsets.all(30),
//               child: CircularProgressIndicator(color: AppColors.maroon),
//             )
//           else
//             GridView.count(
//               crossAxisCount: 2,
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               crossAxisSpacing: 16,
//               mainAxisSpacing: 16,
//               childAspectRatio: 1.0,
//               children: [
//                 _buildActionCard(
//                   title: 'Check-In',
//                   icon: Icons.fingerprint,
//                   iconColor: const Color(0xFF2E7D32),
//                   onTap: _verifyAndProceed,
//                 ),
//                 _buildActionCard(
//                   title: 'Check-Out',
//                   icon: Icons.exit_to_app_rounded,
//                   iconColor: AppColors.maroon,
//                   onTap: _handleCheckOut,
//                 ),
//               ],
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionCard({
//     required String title,
//     required IconData icon,
//     required Color iconColor,
//     required VoidCallback onTap,
//   }) {
//     return Material(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(20),
//       elevation: 2,
//       shadowColor: Colors.black12,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(20),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircleAvatar(
//                 radius: 28,
//                 backgroundColor: iconColor.withOpacity(0.1),
//                 child: Icon(icon, size: 32, color: iconColor),
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: iconColor,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Page 2 — History
//   // ─────────────────────────────────────────────

//   Widget _buildAttendanceHistoryTab() {
//     final user = FirebaseAuth.instance.currentUser;

//     if (user == null) {
//       return const Center(
//         child: Text('Please log in to view history.',
//             style: TextStyle(color: AppColors.darkText)),
//       );
//     }

//     return SingleChildScrollView(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text('Monthly Summary',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   )),
//               _MonthDropdown(
//                 months: _monthsList,
//                 selected: _selectedMonth,
//                 onChanged: (v) => setState(() => _selectedMonth = v),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           StreamBuilder<QuerySnapshot>(
//             stream: FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .collection('attendance')
//                 .orderBy('checkInTime', descending: true)
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.hasError) {
//                 return _ErrorCard(message: snapshot.error.toString());
//               }
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(
//                     child: CircularProgressIndicator(color: AppColors.maroon));
//               }

//               final allDocs = snapshot.data?.docs ?? [];
//               final filtered = allDocs.where((doc) {
//                 final d = doc.data() as Map<String, dynamic>;
//                 final ts = d['checkInTime'] as Timestamp?;
//                 if (ts == null) return false;
//                 final date = ts.toDate();
//                 return '${_monthNames[date.month - 1]} ${date.year}' ==
//                     _selectedMonth;
//               }).toList();

//               final range = _monthDateRange(_selectedMonth);

//               return Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   GridView.count(
//                     crossAxisCount: 2,
//                     crossAxisSpacing: 12,
//                     mainAxisSpacing: 12,
//                     childAspectRatio: 1.5,
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     children: [
//                       _buildColoredStatCard(
//                         'Total Attended',
//                         '${filtered.length} Days',
//                         Icons.check_circle_outline,
//                         Colors.green.shade50,
//                         Colors.green.shade800,
//                       ),
//                       _buildColoredStatCard(
//                         'Absents',
//                         '0 Days',
//                         Icons.cancel_outlined,
//                         Colors.red.shade50,
//                         Colors.red.shade800,
//                       ),
//                       StreamBuilder<QuerySnapshot>(
//                         stream: FirebaseFirestore.instance
//                             .collection('leaves')
//                             .where('userId', isEqualTo: user.uid)
//                             .where('status', isEqualTo: 'Approved')
//                             .where('startDate',
//                                 isGreaterThanOrEqualTo:
//                                     Timestamp.fromDate(range.start))
//                             .where('startDate',
//                                 isLessThanOrEqualTo:
//                                     Timestamp.fromDate(range.end))
//                             .snapshots(),
//                         builder: (_, leaveSnap) {
//                           final count = leaveSnap.data?.docs.length ?? 0;
//                           return _buildColoredStatCard(
//                             'Approved Leaves',
//                             '$count Days',
//                             Icons.event_note,
//                             Colors.amber.shade50,
//                             Colors.amber.shade900,
//                           );
//                         },
//                       ),
//                       _buildColoredStatCard(
//                         'Holidays',
//                         '0 Days',
//                         Icons.beach_access,
//                         Colors.blue.shade50,
//                         Colors.blue.shade800,
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 24),
//                   Text(
//                     'Detailed Logs for $_selectedMonth',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                       color: AppColors.darkText,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   if (filtered.isEmpty)
//                     Container(
//                       width: double.infinity,
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       child: const Text(
//                         'No attendance records found for this month.',
//                         textAlign: TextAlign.center,
//                         style: TextStyle(color: Colors.grey),
//                       ),
//                     )
//                   else
//                     ListView.builder(
//                       shrinkWrap: true,
//                       physics: const NeverScrollableScrollPhysics(),
//                       itemCount: filtered.length,
//                       itemBuilder: (_, i) {
//                         final d = filtered[i].data() as Map<String, dynamic>;
//                         final inTs = d['checkInTime'] as Timestamp?;
//                         final outTs = d['checkOutTime'] as Timestamp?;

//                         return _buildLogTile(
//                           date: inTs != null
//                               ? DateFormat('MMM dd, yyyy').format(inTs.toDate())
//                               : 'Unknown',
//                           title: 'Present',
//                           subtitle:
//                               'In: ${inTs != null ? DateFormat('hh:mm a').format(inTs.toDate()) : '--'}'
//                               ' | Out: ${outTs != null ? DateFormat('hh:mm a').format(outTs.toDate()) : 'Not Checked Out'}',
//                           color: outTs != null
//                               ? Colors.green.shade700
//                               : Colors.amber.shade800,
//                           icon: outTs != null
//                               ? Icons.check_circle_outline
//                               : Icons.access_time,
//                         );
//                       },
//                     ),
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Page 3 — Notifications
//   // ─────────────────────────────────────────────

//   Widget _buildNotificationsTab() {
//     final uid = FirebaseAuth.instance.currentUser?.uid;
//     final recipientIds = <String>['all'];
//     if (uid != null) recipientIds.add(uid);

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Announcements & Leave Approvals',
//             style: TextStyle(
//                 fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
//           ),
//           const SizedBox(height: 12),
//           Expanded(
//             child: StreamBuilder<QuerySnapshot>(
//               stream: FirebaseFirestore.instance
//                   .collection('notifications')
//                   .where('recipientId', whereIn: recipientIds)
//                   .snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.hasError) {
//                   return _ErrorCard(message: snapshot.error.toString());
//                 }
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(
//                       child:
//                           CircularProgressIndicator(color: AppColors.maroon));
//                 }

//                 final docs = snapshot.data?.docs ?? [];
//                 if (docs.isEmpty) {
//                   return const Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.notifications_off_outlined,
//                             size: 50, color: Colors.grey),
//                         SizedBox(height: 12),
//                         Text('No notifications found',
//                             style: TextStyle(color: Colors.grey)),
//                       ],
//                     ),
//                   );
//                 }

//                 return ListView.builder(
//                   itemCount: docs.length,
//                   itemBuilder: (_, i) {
//                     final d = docs[i].data() as Map<String, dynamic>;
//                     final title = d['title'] as String? ?? 'Notice';
//                     final body = d['body'] as String? ?? '';
//                     final type = d['type'] as String? ?? 'general';
//                     final ts = d['createdAt'] as Timestamp?;

//                     IconData icon;
//                     Color color;
//                     switch (type) {
//                       case 'holiday':
//                         icon = Icons.beach_access;
//                         color = Colors.orange;
//                         break;
//                       case 'leave':
//                         icon = Icons.event_available;
//                         color = Colors.green;
//                         break;
//                       case 'success':
//                         icon = Icons.check_circle_outline;
//                         color = Colors.green;
//                         break;
//                       default:
//                         icon = Icons.info_outline;
//                         color = Colors.blue;
//                     }

//                     return Container(
//                       margin: const EdgeInsets.only(bottom: 12),
//                       padding: const EdgeInsets.all(16),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.03),
//                             blurRadius: 8,
//                             offset: const Offset(0, 3),
//                           ),
//                         ],
//                       ),
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           CircleAvatar(
//                             backgroundColor: color.withOpacity(0.12),
//                             child: Icon(icon, color: color),
//                           ),
//                           const SizedBox(width: 14),
//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(title,
//                                     style: const TextStyle(
//                                       color: AppColors.darkText,
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 15,
//                                     )),
//                                 const SizedBox(height: 4),
//                                 Text(body,
//                                     style: TextStyle(
//                                         color: Colors.grey.shade700,
//                                         fontSize: 13)),
//                                 if (ts != null) ...[
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     DateFormat('hh:mm a - MMM dd, yyyy')
//                                         .format(ts.toDate()),
//                                     style: const TextStyle(
//                                         color: Colors.grey, fontSize: 11),
//                                   ),
//                                 ],
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Page 4 — Settings
//   // ─────────────────────────────────────────────

//   Widget _buildSettingsTab() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Account Settings',
//               style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white)),
//           const SizedBox(height: 16),
//           Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.04),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             child: ListTile(
//               leading: const Icon(Icons.lock_outline, color: AppColors.maroon),
//               title: const Text('Security & Password',
//                   style: TextStyle(
//                       color: AppColors.darkText, fontWeight: FontWeight.bold)),
//               subtitle: const Text('Update your current password',
//                   style: TextStyle(color: Colors.grey, fontSize: 12)),
//               trailing: const Icon(Icons.arrow_forward_ios,
//                   color: Colors.grey, size: 16),
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) =>
//                         const SecuritySettingsScreen(maroon: AppColors.maroon),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Leave modal launcher
//   // ─────────────────────────────────────────────

//   void _showLeaveApplicationModal(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => const _LeaveApplicationModal(),
//     );
//   }

//   // ─────────────────────────────────────────────
//   // Small builders
//   // ─────────────────────────────────────────────

//   Widget _buildColoredStatCard(
//       String label, String value, IconData icon, Color bg, Color fg) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: fg, size: 18),
//               const SizedBox(width: 6),
//               Expanded(
//                 child: Text(label,
//                     style: TextStyle(
//                       color: fg,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                     ),
//                     overflow: TextOverflow.ellipsis),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(value,
//               style: TextStyle(
//                   color: fg, fontSize: 18, fontWeight: FontWeight.bold)),
//         ],
//       ),
//     );
//   }

//   Widget _buildLogTile({
//     required String date,
//     required String title,
//     required String subtitle,
//     required Color color,
//     required IconData icon,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.03),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: ListTile(
//         leading: CircleAvatar(
//           backgroundColor: color.withOpacity(0.12),
//           child: Icon(icon, color: color),
//         ),
//         title: Text('$title - $date',
//             style: const TextStyle(
//               color: AppColors.darkText,
//               fontWeight: FontWeight.bold,
//               fontSize: 14,
//             )),
//         subtitle: Text(subtitle,
//             style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
//         trailing:
//             const Icon(Icons.access_time_filled, color: Colors.grey, size: 18),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────
// // Leave Application Modal
// // ─────────────────────────────────────────────

// class _LeaveApplicationModal extends StatefulWidget {
//   const _LeaveApplicationModal();

//   @override
//   State<_LeaveApplicationModal> createState() => _LeaveApplicationModalState();
// }

// class _LeaveApplicationModalState extends State<_LeaveApplicationModal> {
//   final _formKey = GlobalKey<FormState>();
//   final _subjectController = TextEditingController();
//   final _reasonController = TextEditingController();
//   DateTime? _selectedDate;
//   bool _isSubmitting = false;

//   @override
//   void dispose() {
//     _subjectController.dispose();
//     _reasonController.dispose();
//     super.dispose();
//   }

//   Future<void> _submit() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (_selectedDate == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select a leave date.')),
//       );
//       return;
//     }

//     setState(() => _isSubmitting = true);

//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       await FirebaseFirestore.instance.collection('leaves').add({
//         'userId': user?.uid,
//         'userEmail': user?.email,
//         'subject': _subjectController.text.trim(),
//         'reason': _reasonController.text.trim(),
//         'startDate': Timestamp.fromDate(DateTime(
//           _selectedDate!.year,
//           _selectedDate!.month,
//           _selectedDate!.day,
//         )),
//         'status': 'Pending',
//         'createdAt': FieldValue.serverTimestamp(),
//       });

//       if (!mounted) return;
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Leave application sent to Admin!'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
//       );
//     } finally {
//       if (mounted) setState(() => _isSubmitting = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//       ),
//       child: Container(
//         padding: const EdgeInsets.all(24),
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(28),
//             topRight: Radius.circular(28),
//           ),
//         ),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   const Icon(Icons.mark_email_unread_outlined,
//                       color: AppColors.maroon, size: 28),
//                   const SizedBox(width: 10),
//                   const Text('Apply for Leave',
//                       style: TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                           color: AppColors.darkText)),
//                   const Spacer(),
//                   IconButton(
//                     icon: const Icon(Icons.close, color: Colors.grey),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//               const Divider(height: 24),
//               TextFormField(
//                 controller: _subjectController,
//                 decoration: InputDecoration(
//                   labelText: 'Subject',
//                   hintText: 'e.g., Sick Leave / Personal Matter',
//                   prefixIcon:
//                       const Icon(Icons.subject, color: AppColors.maroon),
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12)),
//                   filled: true,
//                   fillColor: Colors.grey.shade50,
//                 ),
//                 validator: (v) =>
//                     v == null || v.isEmpty ? 'Please enter a subject' : null,
//               ),
//               const SizedBox(height: 14),
//               InkWell(
//                 onTap: () async {
//                   final picked = await showDatePicker(
//                     context: context,
//                     initialDate: DateTime.now(),
//                     firstDate: DateTime.now(),
//                     lastDate: DateTime.now().add(const Duration(days: 90)),
//                   );
//                   if (picked != null) {
//                     setState(() => _selectedDate = picked);
//                   }
//                 },
//                 child: Container(
//                   padding:
//                       const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey.shade400),
//                     borderRadius: BorderRadius.circular(12),
//                     color: Colors.grey.shade50,
//                   ),
//                   child: Row(
//                     children: [
//                       const Icon(Icons.calendar_today_outlined,
//                           color: AppColors.maroon),
//                       const SizedBox(width: 12),
//                       Text(
//                         _selectedDate == null
//                             ? 'Select Leave Date'
//                             : DateFormat('EEEE, MMM dd, yyyy')
//                                 .format(_selectedDate!),
//                         style: TextStyle(
//                           color: _selectedDate == null
//                               ? Colors.grey.shade600
//                               : AppColors.darkText,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               TextFormField(
//                 controller: _reasonController,
//                 maxLines: 3,
//                 decoration: InputDecoration(
//                   labelText: 'Reason / Message',
//                   hintText: 'Brief reason for your leave...',
//                   alignLabelWithHint: true,
//                   prefixIcon: const Padding(
//                     padding: EdgeInsets.only(bottom: 40),
//                     child: Icon(Icons.notes, color: AppColors.maroon),
//                   ),
//                   border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12)),
//                   filled: true,
//                   fillColor: Colors.grey.shade50,
//                 ),
//                 validator: (v) =>
//                     v == null || v.isEmpty ? 'Please write your reason' : null,
//               ),
//               const SizedBox(height: 20),
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton.icon(
//                   icon: _isSubmitting
//                       ? const SizedBox.shrink()
//                       : const Icon(Icons.send_rounded, color: Colors.white),
//                   label: _isSubmitting
//                       ? const CircularProgressIndicator(color: Colors.white)
//                       : const Text('Send Application',
//                           style: TextStyle(
//                               fontSize: 16, fontWeight: FontWeight.bold)),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.maroon,
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                   ),
//                   onPressed: _isSubmitting ? null : _submit,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────
// // Reusable small widgets
// // ─────────────────────────────────────────────

// class _ShadowCard extends StatelessWidget {
//   final Widget child;
//   const _ShadowCard({required this.child});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: child,
//     );
//   }
// }

// class _SectionLabel extends StatelessWidget {
//   final String text;
//   const _SectionLabel(this.text);

//   @override
//   Widget build(BuildContext context) {
//     return Text(text,
//         style: const TextStyle(
//           color: AppColors.darkText,
//           fontSize: 18,
//           fontWeight: FontWeight.bold,
//         ));
//   }
// }

// class _RoleBadge extends StatelessWidget {
//   final String role;
//   const _RoleBadge({required this.role});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//       decoration: BoxDecoration(
//         color: AppColors.maroon,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Text(role,
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//             fontSize: 11,
//           )),
//     );
//   }
// }

// class _StatusBadge extends StatelessWidget {
//   final String status;
//   final bool isApproved;
//   const _StatusBadge({required this.status, required this.isApproved});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: isApproved ? Colors.green.shade50 : Colors.orange.shade50,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Text(
//         status.toUpperCase(),
//         style: TextStyle(
//           color: isApproved ? Colors.green.shade800 : Colors.orange.shade800,
//           fontWeight: FontWeight.bold,
//           fontSize: 11,
//         ),
//       ),
//     );
//   }
// }

// class _MonthDropdown extends StatelessWidget {
//   final List<String> months;
//   final String selected;
//   final ValueChanged<String> onChanged;

//   const _MonthDropdown({
//     required this.months,
//     required this.selected,
//     required this.onChanged,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: Colors.grey.shade300),
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<String>(
//           value: selected,
//           dropdownColor: Colors.white,
//           icon: const Icon(Icons.arrow_drop_down, color: AppColors.maroon),
//           style: const TextStyle(
//               color: AppColors.darkText, fontWeight: FontWeight.bold),
//           onChanged: (v) {
//             if (v != null) onChanged(v);
//           },
//           items: months
//               .map((m) => DropdownMenuItem(value: m, child: Text(m)))
//               .toList(),
//         ),
//       ),
//     );
//   }
// }

// class _ErrorCard extends StatelessWidget {
//   final String message;
//   const _ErrorCard({required this.message});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(8),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.red.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.red.shade200),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.error_outline, color: Colors.red),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(message,
//                 style: const TextStyle(color: Colors.red, fontSize: 13)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────
// // Security Settings Screen  (was missing — this is what caused the error)
// // ─────────────────────────────────────────────

// class SecuritySettingsScreen extends StatefulWidget {
//   final Color maroon;
//   const SecuritySettingsScreen({super.key, required this.maroon});

//   @override
//   State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
// }

// class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _currentPasswordController = TextEditingController();
//   final _newPasswordController = TextEditingController();
//   final _confirmPasswordController = TextEditingController();

//   bool _isChangingPassword = false;
//   bool _obscureCurrent = true;
//   bool _obscureNew = true;
//   bool _obscureConfirm = true;

//   @override
//   void dispose() {
//     _currentPasswordController.dispose();
//     _newPasswordController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }

//   Future<void> _updatePassword() async {
//     if (!_formKey.currentState!.validate()) return;
//     setState(() => _isChangingPassword = true);

//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null || user.email == null) {
//         throw FirebaseAuthException(
//           code: 'no-user',
//           message: 'No signed-in user found.',
//         );
//       }

//       final credential = EmailAuthProvider.credential(
//         email: user.email!,
//         password: _currentPasswordController.text,
//       );

//       await user.reauthenticateWithCredential(credential);
//       await user.updatePassword(_newPasswordController.text);

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Password updated successfully!'),
//           backgroundColor: Colors.green,
//         ),
//       );
//       Navigator.pop(context);
//     } on FirebaseAuthException catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(e.message ?? 'Failed to update password.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
//       );
//     } finally {
//       if (mounted) setState(() => _isChangingPassword = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.lightBg,
//       body: Stack(
//         children: [
//           ClipPath(
//             clipper: WavyHeaderClipper(),
//             child: Container(
//               height: 220,
//               width: double.infinity,
//               color: widget.maroon,
//             ),
//           ),
//           SafeArea(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         IconButton(
//                           icon:
//                               const Icon(Icons.arrow_back, color: Colors.white),
//                           onPressed: () => Navigator.pop(context),
//                         ),
//                         const SizedBox(width: 8),
//                         const Text(
//                           'Security & Password',
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 50),
//                     Container(
//                       padding: const EdgeInsets.all(20),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.06),
//                             blurRadius: 15,
//                             offset: const Offset(0, 5),
//                           )
//                         ],
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Update Password',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color: AppColors.darkText,
//                             ),
//                           ),
//                           const SizedBox(height: 6),
//                           Text(
//                             'Update your account password below to keep your profile secure.',
//                             style: TextStyle(
//                                 color: Colors.grey.shade600, fontSize: 13),
//                           ),
//                           const SizedBox(height: 24),
//                           _buildPasswordField(
//                             controller: _currentPasswordController,
//                             labelText: 'Current Password',
//                             obscureText: _obscureCurrent,
//                             onToggleVisibility: () => setState(
//                                 () => _obscureCurrent = !_obscureCurrent),
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Please enter your current password';
//                               }
//                               return null;
//                             },
//                           ),
//                           const SizedBox(height: 16),
//                           _buildPasswordField(
//                             controller: _newPasswordController,
//                             labelText: 'New Password',
//                             obscureText: _obscureNew,
//                             onToggleVisibility: () =>
//                                 setState(() => _obscureNew = !_obscureNew),
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Please enter a new password';
//                               }
//                               if (value.length < 6) {
//                                 return 'Password must be at least 6 characters long';
//                               }
//                               return null;
//                             },
//                           ),
//                           const SizedBox(height: 16),
//                           _buildPasswordField(
//                             controller: _confirmPasswordController,
//                             labelText: 'Confirm New Password',
//                             obscureText: _obscureConfirm,
//                             onToggleVisibility: () => setState(
//                                 () => _obscureConfirm = !_obscureConfirm),
//                             validator: (value) {
//                               if (value == null || value.isEmpty) {
//                                 return 'Please confirm your new password';
//                               }
//                               if (value != _newPasswordController.text) {
//                                 return 'Passwords do not match';
//                               }
//                               return null;
//                             },
//                           ),
//                           const SizedBox(height: 28),
//                           SizedBox(
//                             width: double.infinity,
//                             height: 50,
//                             child: ElevatedButton(
//                               onPressed:
//                                   _isChangingPassword ? null : _updatePassword,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: widget.maroon,
//                                 foregroundColor: Colors.white,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(14),
//                                 ),
//                                 elevation: 2,
//                               ),
//                               child: _isChangingPassword
//                                   ? const SizedBox(
//                                       height: 22,
//                                       width: 22,
//                                       child: CircularProgressIndicator(
//                                         color: Colors.white,
//                                         strokeWidth: 2.5,
//                                       ),
//                                     )
//                                   : const Text(
//                                       'Update Password',
//                                       style: TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                     ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPasswordField({
//     required TextEditingController controller,
//     required String labelText,
//     required bool obscureText,
//     required VoidCallback onToggleVisibility,
//     required String? Function(String?) validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       obscureText: obscureText,
//       style: const TextStyle(color: AppColors.darkText),
//       validator: validator,
//       decoration: InputDecoration(
//         labelText: labelText,
//         labelStyle: TextStyle(color: Colors.grey.shade600),
//         prefixIcon: Icon(Icons.lock_outline, color: widget.maroon),
//         suffixIcon: IconButton(
//           icon: Icon(
//             obscureText ? Icons.visibility_off : Icons.visibility,
//             color: Colors.grey,
//           ),
//           onPressed: onToggleVisibility,
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: Colors.grey.shade300),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: widget.maroon, width: 2),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: Colors.red),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: Colors.red, width: 2),
//         ),
//         filled: true,
//         fillColor: Colors.grey.shade50,
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────
// // Custom wave clipper for header
// // ─────────────────────────────────────────────

// class WavyHeaderClipper extends CustomClipper<Path> {
//   @override
//   Path getClip(Size size) {
//     final path = Path()..lineTo(0, size.height - 60);

//     path.quadraticBezierTo(
//       size.width * 0.25,
//       size.height,
//       size.width * 0.55,
//       size.height - 40,
//     );
//     path.quadraticBezierTo(
//       size.width * 0.8,
//       size.height - 80,
//       size.width,
//       size.height - 20,
//     );

//     path.lineTo(size.width, 0);
//     path.close();
//     return path;
//   }

//   @override
//   bool shouldReclip(CustomClipper<Path> oldClipper) => false;
// }

// attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'qr_scanner_screen.dart';

// ─────────────────────────────────────────────
// App colors
// ─────────────────────────────────────────────
class AppColors {
  static const Color maroon = Color(0xFF800000);
  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color darkText = Color(0xFF2C2C2C);
  AppColors._();
}

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({super.key, required this.userName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _statusMessage = 'Ready to verify and mark attendance';
  bool _isLoading = false;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late final List<String> _monthsList;
  late String _selectedMonth;

  static const List<String> _pageTitles = [
    'Portal Home',
    'Attendance Terminal',
    'Attendance History',
    'Notifications',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthsList = _monthNames.map((m) => '$m ${now.year}').toList();
    _selectedMonth = '${_monthNames[now.month - 1]} ${now.year}';
  }

  /// Builds the composite doc ID used across the app for attendance
  String _attendanceDocId(String uid) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${uid}_$today';
  }

  // ─────────────────────────────────────────────
  // Auth
  // ─────────────────────────────────────────────

  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ─────────────────────────────────────────────
  // Check-In flow
  // ─────────────────────────────────────────────

  Future<void> _verifyAndProceed() async {
    try {
      if (await _isTodayApprovedLeave()) {
        if (!mounted) return;
        _showSnackBar(
          'Leave is already approved for today. Attendance is not required.',
          Colors.green,
        );
        return;
      }
    } catch (e) {
      debugPrint('Leave check error: $e');
    }

    _setLoading(true, 'Checking device permissions...');

    try {
      await [Permission.location, Permission.camera].request();
      final deviceId = await _getDeviceId();

      _setLoading(true, 'Verifying office Wi-Fi network...');
      final bssid = await _getWifiBssid();

      if (bssid == null || bssid.isEmpty) {
        _setLoading(false,
            'Access Blocked: Unable to detect office Wi-Fi. Please connect to the office network.');
        _showSnackBar(
          'Unable to detect Wi-Fi BSSID. Connect to office Wi-Fi.',
          Colors.red,
          duration: const Duration(seconds: 6),
        );
        return;
      }

      debugPrint('=== DETECTED BSSID: $bssid ===');
      _showSnackBar('Detected BSSID: $bssid', Colors.blue);

      if (!await _isBssidAllowed(bssid)) {
        _setLoading(
            false, 'Access Blocked: Not connected to authorized office Wi-Fi.');
        _showSnackBar(
          'Blocked: BSSID "$bssid" is not authorized.',
          Colors.red,
          duration: const Duration(seconds: 6),
        );
        return;
      }

      _setLoading(false, _statusMessage);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QRScannerScreen(
            currentBssid: bssid,
            currentDeviceId: deviceId,
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('Validation error: $e\n$stack');
      _setLoading(false, 'Error during validation: $e');
      _showSnackBar('Validation Error: $e', Colors.red);
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.id;
    } catch (e) {
      debugPrint('Device ID error: $e');
      return 'unknown_device';
    }
  }

  Future<String?> _getWifiBssid() async {
    try {
      return await NetworkInfo().getWifiBSSID();
    } catch (e) {
      debugPrint('BSSID fetch error: $e');
      return null;
    }
  }

  Future<bool> _isBssidAllowed(String bssid) async {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('attendance')
        .get();

    if (!doc.exists) return true;

    final data = doc.data() ?? {};
    final allowedBssids = (data['allowedBssids'] as List<dynamic>?) ?? [];

    if (allowedBssids.isEmpty) return true;
    return allowedBssids.contains(bssid);
  }

  // ─────────────────────────────────────────────
  // Check-Out flow
  // Matches Firestore rules: /attendance/{uid}_{date}, checkOutAt
  // ─────────────────────────────────────────────

  Future<void> _handleCheckOut() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = _attendanceDocId(user.uid);
    final docRef =
        FirebaseFirestore.instance.collection('attendance').doc(docId);

    final snap = await docRef.get();
    final data = snap.data();

    if (!snap.exists || data?['checkInAt'] == null) {
      _showSnackBar(
          'Cannot check out: You have not checked in today!', Colors.orange);
      return;
    }

    if (data?['checkOutAt'] != null) {
      _showSnackBar('You have already checked out for today.', Colors.blue);
      return;
    }

    final now = DateTime.now();
    final confirmed = await _showCheckOutDialog(now);
    if (confirmed != true) return;

    _setLoading(true, 'Recording check-out...');

    try {
      // ⚠️ Only include checkOutAt (server timestamp). No 'status' — rules forbid it.
      await docRef.update({
        'checkOutAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSnackBar('Successfully checked-out', Colors.green);
      setState(() {
        _statusMessage = 'You have checked out successfully.';
        _selectedIndex = 0;
      });
    } catch (e) {
      _showSnackBar('Error recording check-out: $e', Colors.red);
    } finally {
      _setLoading(false, _statusMessage);
    }
  }

  Future<bool?> _showCheckOutDialog(DateTime now) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Check-Out',
            style: TextStyle(
                color: AppColors.darkText, fontWeight: FontWeight.bold)),
        content: Text(
          'Timestamp: ${DateFormat('hh:mm a - MMM dd, yyyy').format(now)}'
          '\n\nDo you want to proceed?',
          style: const TextStyle(color: AppColors.darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.maroon,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                const Text('Check-Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Leave helpers
  // Rules expect: uid (not userId), status: 'approved' (lowercase)
  // ─────────────────────────────────────────────

  Future<bool> _isTodayApprovedLeave() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final query = await FirebaseFirestore.instance
        .collection('leaves')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    return query.docs.isNotEmpty;
  }

  ({DateTime start, DateTime end}) _monthDateRange(String monthYear) {
    final parts = monthYear.split(' ');
    final monthIndex = _monthNames.indexOf(parts[0]) + 1;
    final year = int.parse(parts[1]);
    final start = DateTime(year, monthIndex, 1);
    final end = DateTime(year, monthIndex + 1, 0, 23, 59, 59);
    return (start: start, end: end);
  }

  // ─────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────

  void _setLoading(bool loading, [String? message]) {
    if (!mounted) return;
    setState(() {
      _isLoading = loading;
      if (message != null) _statusMessage = message;
    });
  }

  void _showSnackBar(String message, Color color,
      {Duration duration = const Duration(seconds: 4)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildCheckInTab();
      case 2:
        return _buildAttendanceHistoryTab();
      case 3:
        return _buildNotificationsTab();
      case 4:
        return _buildSettingsTab();
      default:
        return _buildHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBg,
      drawer: _buildSlideDrawer(),
      body: Stack(
        children: [
          ClipPath(
            clipper: WavyHeaderClipper(),
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.maroon, Color(0xFFA01A1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu,
                            color: Colors.white, size: 28),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      ),
                      Text(
                        _pageTitles[_selectedIndex],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout,
                            color: Colors.white, size: 24),
                        onPressed: _handleLogout,
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildBodyContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Drawer
  // ─────────────────────────────────────────────

  Widget _buildSlideDrawer() {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Container(
        color: AppColors.lightBg,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final name = (data?['name'] as String?)?.isNotEmpty == true
                    ? data!['name'] as String
                    : (widget.userName.isNotEmpty ? widget.userName : 'User');
                final role = data?['role'] as String? ?? 'Intern';

                return DrawerHeader(
                  decoration: const BoxDecoration(color: AppColors.maroon),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 26,
                            color: AppColors.maroon,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          )),
                      Text('$role | ${user?.email ?? ''}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
            _buildDrawerTile(0, 'Home', Icons.home_rounded),
            _buildDrawerTile(1, 'Mark Attendance', Icons.fingerprint),
            _buildDrawerTile(2, 'Attendance History', Icons.history_rounded),
            _buildDrawerTile(3, 'Notifications', Icons.notifications_rounded),
            _buildDrawerTile(4, 'Settings', Icons.settings_rounded),
            const Divider(color: Colors.black12),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.maroon),
              title: const Text('Logout',
                  style: TextStyle(
                      color: AppColors.darkText, fontWeight: FontWeight.w600)),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.maroon.withOpacity(0.08),
      leading: Icon(icon,
          color: isSelected ? AppColors.maroon : Colors.grey.shade700),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.maroon : AppColors.darkText,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
    );
  }

  // ─────────────────────────────────────────────
  // Page 0 — Home
  // ─────────────────────────────────────────────

  Widget _buildHomePage() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.maroon));
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final name = (data['name'] as String?)?.isNotEmpty == true
            ? data['name'] as String
            : (widget.userName.isNotEmpty ? widget.userName : 'Intern Name');
        final role = data['role'] as String? ?? 'Intern';
        final department =
            data['department'] as String? ?? 'Flutter Frontend Development';

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _ShadowCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.maroon.withOpacity(0.1),
                      child: const Icon(Icons.person,
                          size: 38, color: AppColors.maroon),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13)),
                          Text(name,
                              style: const TextStyle(
                                color: AppColors.darkText,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              )),
                          const SizedBox(height: 6),
                          _RoleBadge(role: role),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionLabel('Quick Overview'),
              const SizedBox(height: 12),
              _ShadowCard(
                child: Column(
                  children: [
                    _buildProfileDetailRow(
                        Icons.business_rounded, 'Department', department),
                    const Divider(color: Colors.black12, height: 24),
                    _buildProfileDetailRow(
                        Icons.email_rounded, 'Email', user?.email ?? 'N/A'),
                    const Divider(color: Colors.black12, height: 24),
                    _buildProfileDetailRow(
                      Icons.calendar_today_rounded,
                      'Today',
                      DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _ShadowCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.beach_access_rounded,
                            color: AppColors.maroon, size: 26),
                        SizedBox(width: 12),
                        Text('Leave Application',
                            style: TextStyle(
                              color: AppColors.darkText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Submit an e-application for leave. Once approved by '
                      'admin, that day will be marked as Leave Approved.',
                      style:
                          TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon:
                            const Icon(Icons.send_rounded, color: Colors.white),
                        label: const Text('Apply for Leave',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.maroon,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _showLeaveApplicationModal(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _buildLeaveStatusCard(user),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaveStatusCard(User? user) {
    return StreamBuilder<QuerySnapshot>(
      stream: user == null
          ? const Stream.empty()
          : FirebaseFirestore.instance
              .collection('leaves')
              .where('uid', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .limit(4)
              .snapshots(),
      builder: (context, leaveSnapshot) {
        if (leaveSnapshot.connectionState == ConnectionState.waiting) {
          return const _ShadowCard(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.maroon),
            ),
          );
        }

        final leaveDocs = leaveSnapshot.data?.docs ?? [];
        final today = DateTime.now();

        bool isToday(Timestamp? ts) {
          if (ts == null) return false;
          final d = ts.toDate();
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }

        final todayApproved = leaveDocs.any((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return isToday(d['startDate'] as Timestamp?) &&
              d['status'] == 'approved';
        });

        final todayPending = leaveDocs.any((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return isToday(d['startDate'] as Timestamp?) &&
              d['status'] == 'pending';
        });

        return _ShadowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('Leave Status'),
              const SizedBox(height: 8),
              Text(
                todayApproved
                    ? "Today's leave has been approved. Attendance won't be required."
                    : todayPending
                        ? 'Your leave for today is pending approval.'
                        : 'No leave application exists for today.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (leaveDocs.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'No recent leave applications. Use the button above to submit one.',
                    style: TextStyle(color: Colors.black87),
                  ),
                )
              else
                ...leaveDocs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final ts = d['startDate'] as Timestamp?;
                  final dateText = ts != null
                      ? DateFormat('EEE, MMM dd, yyyy').format(ts.toDate())
                      : 'Unknown Date';
                  final status = (d['status'] as String?) ?? 'pending';
                  final isApproved = status == 'approved';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isApproved
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          child: Icon(
                            isApproved
                                ? Icons.check_circle
                                : Icons.hourglass_bottom,
                            color: isApproved
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['subject'] as String? ?? 'Leave Application',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(dateText,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        _StatusBadge(status: status, isApproved: isApproved),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.maroon, size: 20),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const Spacer(),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.darkText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // Page 1 — Check-In / Check-Out
  // ─────────────────────────────────────────────

  Widget _buildCheckInTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          _ShadowCard(
            child: Column(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppColors.maroon, size: 36),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(color: AppColors.maroon),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                _buildActionCard(
                  title: 'Check-In',
                  icon: Icons.fingerprint,
                  iconColor: const Color(0xFF2E7D32),
                  onTap: _verifyAndProceed,
                ),
                _buildActionCard(
                  title: 'Check-Out',
                  icon: Icons.exit_to_app_rounded,
                  iconColor: AppColors.maroon,
                  onTap: _handleCheckOut,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: iconColor.withOpacity(0.1),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Page 2 — History
  // Reads from top-level /attendance where uid == currentUser
  // ─────────────────────────────────────────────

  Widget _buildAttendanceHistoryTab() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('Please log in to view history.',
            style: TextStyle(color: AppColors.darkText)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monthly Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
              _MonthDropdown(
                months: _monthsList,
                selected: _selectedMonth,
                onChanged: (v) => setState(() => _selectedMonth = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where('uid', isEqualTo: user.uid)
                .orderBy('checkInAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorCard(message: snapshot.error.toString());
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.maroon));
              }

              final allDocs = snapshot.data?.docs ?? [];
              final filtered = allDocs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final ts = d['checkInAt'] as Timestamp?;
                if (ts == null) return false;
                final date = ts.toDate();
                return '${_monthNames[date.month - 1]} ${date.year}' ==
                    _selectedMonth;
              }).toList();

              final range = _monthDateRange(_selectedMonth);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildColoredStatCard(
                        'Total Attended',
                        '${filtered.length} Days',
                        Icons.check_circle_outline,
                        Colors.green.shade50,
                        Colors.green.shade800,
                      ),
                      _buildColoredStatCard(
                        'Absents',
                        '0 Days',
                        Icons.cancel_outlined,
                        Colors.red.shade50,
                        Colors.red.shade800,
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('leaves')
                            .where('uid', isEqualTo: user.uid)
                            .where('status', isEqualTo: 'approved')
                            .where('startDate',
                                isGreaterThanOrEqualTo:
                                    Timestamp.fromDate(range.start))
                            .where('startDate',
                                isLessThanOrEqualTo:
                                    Timestamp.fromDate(range.end))
                            .snapshots(),
                        builder: (_, leaveSnap) {
                          final count = leaveSnap.data?.docs.length ?? 0;
                          return _buildColoredStatCard(
                            'Approved Leaves',
                            '$count Days',
                            Icons.event_note,
                            Colors.amber.shade50,
                            Colors.amber.shade900,
                          );
                        },
                      ),
                      _buildColoredStatCard(
                        'Holidays',
                        '0 Days',
                        Icons.beach_access,
                        Colors.blue.shade50,
                        Colors.blue.shade800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Detailed Logs for $_selectedMonth',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'No attendance records found for this month.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final d = filtered[i].data() as Map<String, dynamic>;
                        final inTs = d['checkInAt'] as Timestamp?;
                        final outTs = d['checkOutAt'] as Timestamp?;

                        return _buildLogTile(
                          date: inTs != null
                              ? DateFormat('MMM dd, yyyy').format(inTs.toDate())
                              : 'Unknown',
                          title: 'Present',
                          subtitle:
                              'In: ${inTs != null ? DateFormat('hh:mm a').format(inTs.toDate()) : '--'}'
                              ' | Out: ${outTs != null ? DateFormat('hh:mm a').format(outTs.toDate()) : 'Not Checked Out'}',
                          color: outTs != null
                              ? Colors.green.shade700
                              : Colors.amber.shade800,
                          icon: outTs != null
                              ? Icons.check_circle_outline
                              : Icons.access_time,
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Page 3 — Notifications
  // ─────────────────────────────────────────────

  Widget _buildNotificationsTab() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final recipientIds = <String>['all'];
    if (uid != null) recipientIds.add(uid);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Announcements & Leave Approvals',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', whereIn: recipientIds)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorCard(message: snapshot.error.toString());
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.maroon));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 50, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No notifications found',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final title = d['title'] as String? ?? 'Notice';
                    final body = d['body'] as String? ?? '';
                    final type = d['type'] as String? ?? 'general';
                    final ts = d['createdAt'] as Timestamp?;

                    IconData icon;
                    Color color;
                    switch (type) {
                      case 'holiday':
                        icon = Icons.beach_access;
                        color = Colors.orange;
                        break;
                      case 'leave':
                        icon = Icons.event_available;
                        color = Colors.green;
                        break;
                      case 'success':
                        icon = Icons.check_circle_outline;
                        color = Colors.green;
                        break;
                      default:
                        icon = Icons.info_outline;
                        color = Colors.blue;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withOpacity(0.12),
                            child: Icon(icon, color: color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title,
                                    style: const TextStyle(
                                      color: AppColors.darkText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    )),
                                const SizedBox(height: 4),
                                Text(body,
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13)),
                                if (ts != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    DateFormat('hh:mm a - MMM dd, yyyy')
                                        .format(ts.toDate()),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Page 4 — Settings
  // ─────────────────────────────────────────────

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account Settings',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.maroon),
              title: const Text('Security & Password',
                  style: TextStyle(
                      color: AppColors.darkText, fontWeight: FontWeight.bold)),
              subtitle: const Text('Update your current password',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.grey, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SecuritySettingsScreen(maroon: AppColors.maroon),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Leave modal launcher
  // ─────────────────────────────────────────────

  void _showLeaveApplicationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LeaveApplicationModal(),
    );
  }

  // ─────────────────────────────────────────────
  // Small builders
  // ─────────────────────────────────────────────

  Widget _buildColoredStatCard(
      String label, String value, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: fg, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLogTile({
    required String date,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color),
        ),
        title: Text('$title - $date',
            style: const TextStyle(
              color: AppColors.darkText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            )),
        subtitle: Text(subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing:
            const Icon(Icons.access_time_filled, color: Colors.grey, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Leave Application Modal
// Writes: uid (not userId), status: 'pending' (lowercase)
// ─────────────────────────────────────────────

class _LeaveApplicationModal extends StatefulWidget {
  const _LeaveApplicationModal();

  @override
  State<_LeaveApplicationModal> createState() => _LeaveApplicationModalState();
}

class _LeaveApplicationModalState extends State<_LeaveApplicationModal> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a leave date.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not logged in');
      }

      // ⚠️ Rules require: uid (not userId), status = 'pending' (lowercase)
      await FirebaseFirestore.instance.collection('leaves').add({
        'uid': user.uid,
        'userEmail': user.email,
        'subject': _subjectController.text.trim(),
        'reason': _reasonController.text.trim(),
        'startDate': Timestamp.fromDate(DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        )),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave application sent to Admin!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined,
                      color: AppColors.maroon, size: 28),
                  const SizedBox(width: 10),
                  const Text('Apply for Leave',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g., Sick Leave / Personal Matter',
                  prefixIcon:
                      const Icon(Icons.subject, color: AppColors.maroon),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please enter a subject' : null,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.maroon),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate == null
                            ? 'Select Leave Date'
                            : DateFormat('EEEE, MMM dd, yyyy')
                                .format(_selectedDate!),
                        style: TextStyle(
                          color: _selectedDate == null
                              ? Colors.grey.shade600
                              : AppColors.darkText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason / Message',
                  hintText: 'Brief reason for your leave...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.notes, color: AppColors.maroon),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please write your reason' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox.shrink()
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Send Application',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.maroon,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reusable small widgets
// ─────────────────────────────────────────────

class _ShadowCard extends StatelessWidget {
  final Widget child;
  const _ShadowCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
          color: AppColors.darkText,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ));
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.maroon,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          )),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isApproved;
  const _StatusBadge({required this.status, required this.isApproved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isApproved ? Colors.green.shade800 : Colors.orange.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  final List<String> months;
  final String selected;
  final ValueChanged<String> onChanged;

  const _MonthDropdown({
    required this.months,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.maroon),
          style: const TextStyle(
              color: AppColors.darkText, fontWeight: FontWeight.bold),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: months
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Security Settings Screen
// ─────────────────────────────────────────────

class SecuritySettingsScreen extends StatefulWidget {
  final Color maroon;
  const SecuritySettingsScreen({super.key, required this.maroon});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isChangingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isChangingPassword = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No signed-in user found.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to update password.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: Stack(
        children: [
          ClipPath(
            clipper: WavyHeaderClipper(),
            child: Container(
              height: 220,
              width: double.infinity,
              color: widget.maroon,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Security & Password',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Update Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Update your account password below to keep your profile secure.',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          _buildPasswordField(
                            controller: _currentPasswordController,
                            labelText: 'Current Password',
                            obscureText: _obscureCurrent,
                            onToggleVisibility: () => setState(
                                () => _obscureCurrent = !_obscureCurrent),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your current password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordField(
                            controller: _newPasswordController,
                            labelText: 'New Password',
                            obscureText: _obscureNew,
                            onToggleVisibility: () =>
                                setState(() => _obscureNew = !_obscureNew),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a new password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters long';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            labelText: 'Confirm New Password',
                            obscureText: _obscureConfirm,
                            onToggleVisibility: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your new password';
                              }
                              if (value != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  _isChangingPassword ? null : _updatePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.maroon,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2,
                              ),
                              child: _isChangingPassword
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Update Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String labelText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: AppColors.darkText),
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(Icons.lock_outline, color: widget.maroon),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: onToggleVisibility,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.maroon, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Custom wave clipper
// ─────────────────────────────────────────────

class WavyHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()..lineTo(0, size.height - 60);

    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.55,
      size.height - 40,
    );
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height - 80,
      size.width,
      size.height - 20,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
