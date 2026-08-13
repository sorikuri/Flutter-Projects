import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetScreen extends StatefulWidget {
  final String oobCode; // Out-of-band code from Firebase

  const PasswordResetScreen({
    super.key,
    required this.oobCode,
  });

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isSuccess = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _verifyResetCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Verify the reset code is valid and get the user's email
  Future<void> _verifyResetCode() async {
    try {
      final email =
          await FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);

      if (mounted) {
        setState(() {
          _userEmail = email;
        });
      }

      debugPrint('✅ Reset code verified for email: $email');
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          switch (e.code) {
            case 'invalid-action-code':
              _errorMessage =
                  'This password reset link is invalid or has expired. Please request a new one.';
              break;
            case 'expired-action-code':
              _errorMessage =
                  'This password reset link has expired. Please request a new one.';
              break;
            default:
              _errorMessage = 'Error verifying reset link: ${e.message}';
          }
        });
      }
      debugPrint('❌ Reset code verification failed: ${e.code} - ${e.message}');
    }
  }

  /// Validate password strength
  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain an uppercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain a number.';
    }
    return null;
  }

  /// Update password in Firebase
  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validation
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password.');
      return;
    }

    if (confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Please confirm your password.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    // Check password strength
    final validationError = _validatePassword(password);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Confirm password reset with the OOB code
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: password,
      );

      debugPrint('✅ Password reset successful for $_userEmail');

      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Password reset successfully! Redirecting to login...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Redirect to login after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          switch (e.code) {
            case 'weak-password':
              _errorMessage =
                  'The password is too weak. Please use a stronger password.';
              break;
            case 'invalid-action-code':
              _errorMessage =
                  'This password reset link is invalid or has expired. Please request a new one.';
              break;
            case 'expired-action-code':
              _errorMessage =
                  'This password reset link has expired. Please request a new one.';
              break;
            default:
              _errorMessage = 'Failed to reset password: ${e.message}';
          }
        });
      }
      debugPrint('❌ Password reset failed: ${e.code} - ${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
      debugPrint('❌ Password reset error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF800000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF800000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userEmail != null
                        ? 'Create a new password for $_userEmail'
                        : 'Verifying reset link...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // Form Container
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
                  child: _buildContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Loading state
    if (_userEmail == null && _errorMessage.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF800000)),
          const SizedBox(height: 16),
          const Text('Verifying password reset link...'),
        ],
      );
    }

    // Error state - invalid link
    if (_errorMessage.isNotEmpty && !_isSuccess) {
      return Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF800000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 32,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Login'),
          ),
        ],
      );
    }

    // Success state
    if (_isSuccess) {
      return Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Password reset successfully!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.green,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can now login with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    // Form state
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error Message
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
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

        // New Password Field
        const Text(
          'New Password',
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
            hintText: 'Enter new password',
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
                setState(() => _showPassword = !_showPassword);
              },
              icon: Icon(
                _showPassword ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF800000),
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Password requirements:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        _buildRequirement(
            'At least 6 characters', _passwordController.text.length >= 6),
        _buildRequirement('Contains an uppercase letter',
            RegExp(r'[A-Z]').hasMatch(_passwordController.text)),
        _buildRequirement('Contains a number',
            RegExp(r'[0-9]').hasMatch(_passwordController.text)),

        const SizedBox(height: 20),

        // Confirm Password Field
        const Text(
          'Confirm Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF800000),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: !_showConfirmPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color.fromARGB(255, 246, 241, 241),
            hintText: 'Confirm password',
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
                setState(() => _showConfirmPassword = !_showConfirmPassword);
              },
              icon: Icon(
                _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF800000),
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Reset Button
        SizedBox(
          width: double.infinity,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF800000),
                  ),
                )
              : ElevatedButton(
                  onPressed: _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF800000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Back to Login',
              style: TextStyle(
                color: Color(0xFF800000),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
