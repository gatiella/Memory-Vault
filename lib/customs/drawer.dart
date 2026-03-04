import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class CustomDrawer extends StatelessWidget {
  final AuthService authService;
  const CustomDrawer({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userEmail = authService.getCurrentUserEmail() ?? 'Not logged in';
    final isSystem = themeService.themeMode == ThemeMode.system;

    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.indigo, AppTheme.violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                const Text('My Account',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(userEmail,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.75), fontSize: 13)),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Theme toggle
                _buildTile(
                  context: context,
                  isDark: isDark,
                  icon: isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  title: isDark ? 'Light Mode' : 'Dark Mode',
                  subtitle: isSystem ? 'Currently following system' : null,
                  onTap: () {
                    themeService.toggleTheme();
                    Navigator.pop(context);
                  },
                ),
                // Follow system — only show when manually locked
                if (!isSystem)
                  // _buildTile(
                  //   context: context,
                  //   isDark: isDark,
                  //   icon: Icons.brightness_auto_rounded,
                  //   title: 'Follow System',
                  //   onTap: () {
                  //     themeService.resetToSystem();
                  //     Navigator.pop(context);
                  //   },
                  // ),
                // _buildTile(
                //   context: context,
                //   isDark: isDark,
                //   icon: Icons.settings_outlined,
                //   title: 'Settings',
                //   onTap: () => Navigator.pop(context),
                // ),
                Divider(
                    color:
                        isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    height: 24),
                _buildTile(
                  context: context,
                  isDark: isDark,
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  color: Colors.redAccent,
                  onTap: () async {
                    await authService.signOut();
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('Made with ❤️ by gatiella',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkSubtext
                          : const Color(0xFF9999AA))),
              const SizedBox(height: 4),
              Text('Version 1.0.1',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.darkSubtext
                          : const Color(0xFF9999AA))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final tileColor =
        color ?? (isDark ? AppTheme.darkText : AppTheme.lightText);
    return ListTile(
      leading: Icon(icon, color: tileColor, size: 22),
      title: Text(title,
          style: TextStyle(
              color: tileColor,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.darkSubtext
                      : const Color(0xFF9999AA)))
          : null,
      onTap: onTap,
      horizontalTitleGap: 8,
    );
  }
}