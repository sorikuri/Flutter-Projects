// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'attendance_screen.dart';
// import 'app_logo.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   bool _rememberMe = false;
//   bool _showPassword = false;
//   bool _isLoading = false;
//   String _errorMessage = '';

//   @override
//   void initState() {
//     super.initState();
//     _loadSavedCredentials();
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadSavedCredentials() async {
//     final prefs = await SharedPreferences.getInstance();
//     final savedName = prefs.getString('saved_name') ?? '';
//     final savedEmail = prefs.getString('saved_email') ?? '';
//     final savedPassword = prefs.getString('saved_password') ?? '';
//     final savedRemember = prefs.getBool('saved_remember_me') ?? false;

//     if (savedRemember) {
//       setState(() {
//         _rememberMe = true;
//         _nameController.text = savedName;
//         _emailController.text = savedEmail;
//         _passwordController.text = savedPassword;
//         _showPassword = false;
//       });
//     }
//   }

//   Future<void> _saveCredentials() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool('saved_remember_me', _rememberMe);
//     if (_rememberMe) {
//       await prefs.setString('saved_name', _nameController.text.trim());
//       await prefs.setString('saved_email', _emailController.text.trim());
//       await prefs.setString('saved_password', _passwordController.text);
//     } else {
//       await prefs.remove('saved_name');
//       await prefs.remove('saved_email');
//       await prefs.remove('saved_password');
//     }
//   }

//   Future<void> _login() async {
//     final name = _nameController.text.trim();
//     final email = _emailController.text.trim();
//     final password = _passwordController.text;

//     if (name.isEmpty) {
//       setState(() {
//         _errorMessage = 'Please enter your full name.';
//       });
//       return;
//     }

//     if (email.isEmpty && password.isEmpty) {
//       setState(() {
//         _errorMessage = 'Please enter your name, email and password.';
//       });
//       return;
//     }

//     if (email.isEmpty) {
//       setState(() {
//         _errorMessage = 'Please enter your email address.';
//       });
//       return;
//     }

//     if (password.isEmpty) {
//       setState(() {
//         _errorMessage = 'Please enter your password.';
//       });
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _errorMessage = '';
//     });

//     try {
//       await FirebaseAuth.instance.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );

//       await _saveCredentials();

//       if (!mounted) return;

//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => DashboardScreen(userName: name),
//         ),
//       );
//     } on FirebaseAuthException catch (e) {
//       setState(() {
//         switch (e.code) {
//           case 'user-not-found':
//           case 'wrong-password':
//           case 'invalid-credential':
//             _errorMessage = 'Invalid email or password. Please try again.';
//             break;
//           case 'invalid-email':
//             _errorMessage = 'The email address format is invalid.';
//             break;
//           case 'user-disabled':
//             _errorMessage = 'This user account has been disabled.';
//             break;
//           case 'too-many-requests':
//             _errorMessage =
//                 'Too many failed login attempts. Please try again later.';
//             break;
//           default:
//             _errorMessage =
//                 'Authentication failed. Please check your credentials.';
//         }
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'An unexpected error occurred. Please try again.';
//       });
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _resetPassword() async {
//     final resetEmailController = TextEditingController(
//       text: _emailController.text.trim(),
//     );

//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           title: const Text(
//             'Reset Password',
//             style: TextStyle(
//               color: Color(0xFF800000),
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Enter your email address and we will send you a password reset link.',
//                 style: TextStyle(fontSize: 14),
//               ),
//               const SizedBox(height: 16),
//               TextField(
//                 controller: resetEmailController,
//                 keyboardType: TextInputType.emailAddress,
//                 decoration: const InputDecoration(
//                   labelText: 'Email Address',
//                   labelStyle: TextStyle(color: Color(0xFF800000)),
//                   border: OutlineInputBorder(),
//                   focusedBorder: OutlineInputBorder(
//                     borderSide: BorderSide(color: Color(0xFF800000), width: 2),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
//             ),
//             ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color(0xFF800000),
//                 foregroundColor: Colors.white,
//               ),
//               onPressed: () async {
//                 final email = resetEmailController.text.trim();
//                 if (email.isEmpty) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('Please enter an email address.'),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                   return;
//                 }

//                 try {
//                   await FirebaseAuth.instance.sendPasswordResetEmail(
//                     email: email,
//                   );

//                   final prefs = await SharedPreferences.getInstance();
//                   await prefs.remove('saved_password');
//                   _passwordController.clear();

//                   if (!mounted) return;
//                   Navigator.pop(context);
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text(
//                         'Password reset link sent! Check your email to create a new password.',
//                       ),
//                       backgroundColor: Colors.green,
//                     ),
//                   );
//                 } on FirebaseAuthException catch (e) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                         e.code == 'user-not-found'
//                             ? 'No account found with this email.'
//                             : 'Failed to send reset email. Please try again.',
//                       ),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                 } catch (e) {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(
//                       content: Text('An error occurred. Please try again.'),
//                       backgroundColor: Colors.red,
//                     ),
//                   );
//                 }
//               },
//               child: const Text('Send Email'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF800000), // Maroon Background Top Half
//       body: SafeArea(
//         bottom: false,
//         child: Column(
//           children: [
//             // Upper Section (Maroon Header Area)
//             Container(
//               height: MediaQuery.of(context).size.height * 0.28,
//               width: double.infinity,
//               padding: const EdgeInsets.symmetric(horizontal: 24.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: const [
//                   AppLogo(
//                     width: 220,
//                     height: 60,
//                     title: 'CDGAI',
//                     subtitle: 'Intern Attendance Portal',
//                     white: true,
//                   ),
//                   SizedBox(height: 14),
//                   Text(
//                     'Sign In',
//                     style: TextStyle(
//                       fontSize: 28,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             // Lower Section (White Card Container)
//             Expanded(
//               child: Container(
//                 width: double.infinity,
//                 decoration: const BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(36),
//                     topRight: Radius.circular(36),
//                   ),
//                 ),
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 28.0,
//                     vertical: 36.0,
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Full Name Field
//                       const Text(
//                         'Full Name',
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                           color: Color(0xFF800000),
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       TextFormField(
//                         controller: _nameController,
//                         textCapitalization: TextCapitalization.words,
//                         decoration: const InputDecoration(
//                           filled: true,
//                           fillColor: Color.fromARGB(255, 246, 241, 241),
//                           hintText: 'Enter your full name',
//                           prefixIcon: Icon(Icons.person_outline,
//                               color: Color(0xFF800000)),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide: BorderSide.none,
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide:
//                                 BorderSide(color: Color(0xFF800000), width: 2),
//                           ),
//                           contentPadding: EdgeInsets.symmetric(
//                             vertical: 16,
//                             horizontal: 14,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 20),

//                       // Email Field Header + Forgot Password
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           const Text(
//                             'Email Address',
//                             style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.bold,
//                               color: Color(0xFF800000),
//                             ),
//                           ),
//                           InkWell(
//                             onTap: _resetPassword,
//                             child: const Text(
//                               'Forgot Password?',
//                               style: TextStyle(
//                                 fontSize: 13,
//                                 color: Colors.blue,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       TextFormField(
//                         controller: _emailController,
//                         keyboardType: TextInputType.emailAddress,
//                         decoration: const InputDecoration(
//                           filled: true,
//                           fillColor: Color.fromARGB(255, 246, 241, 241),
//                           hintText: 'Enter your email',
//                           prefixIcon: Icon(Icons.email_outlined,
//                               color: Color(0xFF800000)),
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide: BorderSide.none,
//                           ),
//                           focusedBorder: OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide:
//                                 BorderSide(color: Color(0xFF800000), width: 2),
//                           ),
//                           contentPadding: EdgeInsets.symmetric(
//                             vertical: 16,
//                             horizontal: 14,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 20),

//                       // Password Field Header
//                       const Text(
//                         'Password',
//                         style: TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                           color: Color(0xFF800000),
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       TextFormField(
//                         controller: _passwordController,
//                         obscureText: !_showPassword,
//                         decoration: InputDecoration(
//                           filled: true,
//                           fillColor: const Color.fromARGB(255, 246, 241, 241),
//                           hintText: 'Enter your password',
//                           prefixIcon: const Icon(Icons.lock_outline,
//                               color: Color(0xFF800000)),
//                           border: const OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide: BorderSide.none,
//                           ),
//                           focusedBorder: const OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide:
//                                 BorderSide(color: Color(0xFF800000), width: 2),
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             vertical: 16,
//                             horizontal: 14,
//                           ),
//                           suffixIcon: IconButton(
//                             splashRadius: 20,
//                             onPressed: () {
//                               setState(() {
//                                 _showPassword = !_showPassword;
//                               });
//                             },
//                             icon: Icon(
//                               _showPassword
//                                   ? Icons.visibility
//                                   : Icons.visibility_off,
//                               color: const Color(0xFF800000),
//                               size: 22,
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 12),

//                       // Remember Me Checkbox
//                       InkWell(
//                         onTap: () {
//                           setState(() {
//                             _rememberMe = !_rememberMe;
//                           });
//                         },
//                         borderRadius: BorderRadius.circular(4),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             SizedBox(
//                               height: 24,
//                               width: 24,
//                               child: Checkbox(
//                                 value: _rememberMe,
//                                 activeColor: const Color(0xFF800000),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(4),
//                                 ),
//                                 onChanged: (value) {
//                                   setState(() {
//                                     _rememberMe = value ?? false;
//                                   });
//                                 },
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             const Text(
//                               'Remember me',
//                               style: TextStyle(
//                                 fontSize: 13,
//                                 color: Color(0xFF800000),
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(height: 16),

//                       // Error Message Block
//                       if (_errorMessage.isNotEmpty)
//                         Padding(
//                           padding: const EdgeInsets.only(bottom: 12.0),
//                           child: Text(
//                             _errorMessage,
//                             style: const TextStyle(
//                               color: Colors.red,
//                               fontSize: 13,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                         ),

//                       // Login Button
//                       SizedBox(
//                         width: double.infinity,
//                         child: _isLoading
//                             ? const Center(
//                                 child: CircularProgressIndicator(
//                                   color: Color(0xFF800000),
//                                 ),
//                               )
//                             : ElevatedButton(
//                                 onPressed: _login,
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: const Color(0xFF800000),
//                                   foregroundColor: Colors.white,
//                                   padding:
//                                       const EdgeInsets.symmetric(vertical: 16),
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   elevation: 2,
//                                 ),
//                                 child: const Text(
//                                   'Login',
//                                   style: TextStyle(
//                                     fontSize: 16,
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_screen.dart';
import 'app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _showPassword = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('saved_name') ?? '';
    final savedEmail = prefs.getString('saved_email') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';
    final savedRemember = prefs.getBool('saved_remember_me') ?? false;

    if (savedRemember && mounted) {
      setState(() {
        _rememberMe = true;
        _nameController.text = savedName;
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _showPassword = false;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('saved_remember_me', _rememberMe);
    if (_rememberMe) {
      await prefs.setString('saved_name', _nameController.text.trim());
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setString('saved_password', _passwordController.text);
    } else {
      await prefs.remove('saved_name');
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
    }
  }

  /// After successful login, save the entered name into Firebase Auth's
  /// displayName AND create/update the /interns/{uid} profile immediately.
  ///
  /// This is what fixes "Intern ylilao" — the web dashboard reads /interns
  /// and previously that collection was empty because rules blocked writes
  /// and the login never wrote anything anyway.
  Future<void> _syncUserProfile(User user, String enteredName) async {
    try {
      // 1. Force-refresh so email/displayName are fresh from Firebase
      await user.reload();
      final freshUser = FirebaseAuth.instance.currentUser ?? user;

      final email = freshUser.email ?? '';
      final trimmedName = enteredName.trim();

      debugPrint('=== SYNC PROFILE ===');
      debugPrint('UID: ${freshUser.uid}');
      debugPrint('Email: "$email"');
      debugPrint('Entered name: "$trimmedName"');
      debugPrint('Current displayName: "${freshUser.displayName}"');

      // 2. Save the entered name as displayName in Firebase Auth if needed
      if (trimmedName.isNotEmpty && freshUser.displayName != trimmedName) {
        await freshUser.updateDisplayName(trimmedName);
        debugPrint('✅ Updated Firebase Auth displayName to "$trimmedName"');
      }

      // 3. Create/update /interns/{uid} profile in Firestore
      final profileRef =
          FirebaseFirestore.instance.collection('interns').doc(freshUser.uid);

      final snap = await profileRef.get();

      if (!snap.exists) {
        // First time — create the profile
        // Note: role/team/active/internID are NOT included because rules
        // block interns from setting protected fields. Admin sets those.
        await profileRef.set({
          'uid': freshUser.uid,
          'email': email,
          'name': trimmedName.isNotEmpty ? trimmedName : email.split('@').first,
          'phone': '',
          'lastLogin': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ CREATED /interns/${freshUser.uid}');
      } else {
        // Profile exists — patch missing/stale fields
        final data = snap.data() ?? {};
        final Map<String, dynamic> updates = {};

        final existingEmail = (data['email'] as String?) ?? '';
        final existingName = (data['name'] as String?) ?? '';

        if (email.isNotEmpty && existingEmail != email) {
          updates['email'] = email;
        }

        if (trimmedName.isNotEmpty && existingName != trimmedName) {
          updates['name'] = trimmedName;
        }

        updates['lastLogin'] = FieldValue.serverTimestamp();

        await profileRef.update(updates);
        debugPrint(
            '✅ UPDATED /interns/${freshUser.uid} with ${updates.keys.toList()}');
      }
    } on FirebaseException catch (e) {
      // Log Firestore/Auth errors but DON'T block login
      debugPrint('❌ Profile sync FAILED: ${e.code} — ${e.message}');
    } catch (e, stack) {
      debugPrint('❌ Profile sync unexpected error: $e\n$stack');
    }
  }

  Future<void> _login() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name.');
      return;
    }

    if (email.isEmpty && password.isEmpty) {
      setState(
          () => _errorMessage = 'Please enter your name, email and password.');
      return;
    }

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Sign in
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Sync profile — this is the fix for the "no email / wrong name" issue
      if (credential.user != null) {
        await _syncUserProfile(credential.user!, name);
      }

      // 3. Save "remember me" credentials
      await _saveCredentials();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(userName: name),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case 'user-not-found':
          case 'wrong-password':
          case 'invalid-credential':
            _errorMessage = 'Invalid email or password. Please try again.';
            break;
          case 'invalid-email':
            _errorMessage = 'The email address format is invalid.';
            break;
          case 'user-disabled':
            _errorMessage = 'This user account has been disabled.';
            break;
          case 'too-many-requests':
            _errorMessage =
                'Too many failed login attempts. Please try again later.';
            break;
          default:
            _errorMessage =
                'Authentication failed. Please check your credentials.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final initialEmail = _emailController.text.trim();

    if (!mounted) return;

    final resetEmailController = TextEditingController(text: initialEmail);

    return showDialog(
      context: context,
      builder: (dialogContext) => _ResetPasswordDialog(
        resetEmailController: resetEmailController,
        onPasswordReset: () {
          SharedPreferences.getInstance().then((prefs) {
            prefs.remove('saved_password');
          });
          _passwordController.clear();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF800000),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.28,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppLogo(
                    width: 220,
                    height: 60,
                    title: 'CDGAI',
                    subtitle: 'Intern Attendance Portal',
                    white: true,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28.0,
                    vertical: 36.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF800000),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color.fromARGB(255, 246, 241, 241),
                          hintText: 'Enter your full name',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: Color(0xFF800000),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: Color(0xFF800000),
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF800000),
                            ),
                          ),
                          InkWell(
                            onTap: _resetPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Color.fromARGB(255, 246, 241, 241),
                          hintText: 'Enter your email',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Color(0xFF800000),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: Color(0xFF800000),
                              width: 2,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF800000),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color.fromARGB(255, 246, 241, 241),
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF800000),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: Color(0xFF800000),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 14,
                          ),
                          suffixIcon: IconButton(
                            splashRadius: 20,
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF800000),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          setState(() => _rememberMe = !_rememberMe);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: const Color(0xFF800000),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Remember me',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF800000),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF800000),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF800000),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  final TextEditingController resetEmailController;
  final VoidCallback onPasswordReset;

  const _ResetPasswordDialog({
    required this.resetEmailController,
    required this.onPasswordReset,
  });

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  bool _isSending = false;

  Future<void> _sendResetEmail() async {
    final email = widget.resetEmailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      widget.onPasswordReset();

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset link sent! Check your email to create a new password.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'user-not-found'
                ? 'No account found with this email.'
                : 'Failed to send reset email. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Reset Password',
        style: TextStyle(
          color: Color(0xFF800000),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your email address and we will send you a password reset link.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.resetEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              labelStyle: TextStyle(color: Color(0xFF800000)),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF800000), width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF800000),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSending ? null : _sendResetEmail,
          child: _isSending
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Send Email'),
        ),
      ],
    );
  }
}
