import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String error = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final result = await _auth.signInWithEmailAndPassword(
            _emailController.text.trim(), _passwordController.text);
        if (result == null) {
          setState(() {
            error = 'Could not sign in with those credentials';
            _isLoading = false;
          });
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        setState(() {
          error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await _auth.signInWithGoogle();
      if (result == null) {
        setState(() {
          error = 'Could not sign in with Google';
          _isLoading = false;
        });
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background orbs
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.indigo.withOpacity(isDark ? 0.2 : 0.1),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.2, left: -80,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.violet.withOpacity(isDark ? 0.15 : 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),
                      // Logo
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [AppTheme.indigo, AppTheme.violet],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.indigo.withOpacity(0.35),
                              blurRadius: 20, offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.edit_note_rounded,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Welcome\nback.',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTheme.darkText : AppTheme.lightText,
                          height: 1.1,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to your notes',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark
                              ? AppTheme.darkSubtext
                              : const Color(0xFF666688),
                        ),
                      ),
                      const SizedBox(height: 44),
                      Form(
                        key: _formKey,
                        child: Column(children: [
                          _buildField(
                            controller: _emailController,
                            label: 'Email address',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) =>
                                val!.isEmpty ? 'Enter an email' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: isDark
                                    ? AppTheme.darkSubtext
                                    : const Color(0xFF9999AA),
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (val) => val!.length < 6
                                ? 'Password must be 6+ characters'
                                : null,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 28),
                      _buildPrimaryButton(
                          label: 'Sign In',
                          onTap: _isLoading ? null : _signIn,
                          isLoading: _isLoading),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: Divider(
                            color: isDark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or',
                              style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkSubtext
                                      : const Color(0xFF9999AA),
                                  fontSize: 13)),
                        ),
                        Expanded(child: Divider(
                            color: isDark
                                ? AppTheme.darkBorder
                                : AppTheme.lightBorder)),
                      ]),
                      const SizedBox(height: 16),
                      _buildGoogleButton(
                          onTap: _isLoading ? null : _signInWithGoogle,
                          isDark: isDark),
                      const SizedBox(height: 32),
                      Center(
                        child: GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkSubtext
                                      : const Color(0xFF666688),
                                  fontSize: 14),
                              children: const [
                                TextSpan(
                                  text: 'Register',
                                  style: TextStyle(
                                    color: AppTheme.indigo,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (error.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(error,
                                    style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 13))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: TextStyle(
          color: isDark ? AppTheme.darkText : AppTheme.lightText, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon,
            color: isDark ? AppTheme.darkSubtext : const Color(0xFF9999AA),
            size: 20),
        suffixIcon: suffixIcon,
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  Widget _buildPrimaryButton(
      {required String label,
      required VoidCallback? onTap,
      bool isLoading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: onTap == null
              ? LinearGradient(colors: [
                  AppTheme.indigo.withOpacity(0.4),
                  AppTheme.violet.withOpacity(0.4)
                ])
              : const LinearGradient(
                  colors: [AppTheme.indigo, AppTheme.violet],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.indigo.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(
      {required VoidCallback? onTap, required bool isDark}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isDark
              ? AppTheme.darkCard
              : AppTheme.lightSurface,
          border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('G',
                style: TextStyle(
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Text('Continue with Google',
                style: TextStyle(
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}