import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../services/theme_service.dart';
import 'notifications_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const Color primaryColor = Color(0xFFA94327);
  static const Color tealColor = Color(0xFF008F82);

  bool _pushNotifications = true;
  bool _adoptionAlerts = true;
  bool _visitReminders = true;
  bool _shelterBroadcasts = true;
  bool _communityInteractions = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('notif_push_enabled') ?? true;
      _adoptionAlerts = prefs.getBool('notif_adoption_enabled') ?? true;
      _visitReminders = prefs.getBool('notif_visit_enabled') ?? true;
      _shelterBroadcasts = prefs.getBool('notif_broadcasts_enabled') ?? true;
      _communityInteractions = prefs.getBool('notif_community_enabled') ?? true;
    });
  }

  Future<void> _updatePref(String key, bool value, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label ${value ? 'enabled' : 'disabled'}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.isDarkMode(context);
    final bgCol = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5FAFD);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textCol = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF062B35);
    final subTextCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final appBarBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgCol,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textCol,
            size: 19,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notification Settings',
          style: TextStyle(
            color: textCol,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: borderCol,
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // INBOX SHORTCUT BANNER
            // ==================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCol),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification Inbox',
                          style: TextStyle(
                            color: textCol,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ValueListenableBuilder<int>(
                          valueListenable:
                              NotificationService().unreadCountNotifier,
                          builder: (context, unreadCount, child) {
                            return Text(
                              unreadCount > 0
                                  ? '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}'
                                  : 'All notifications caught up',
                              style: TextStyle(
                                color: unreadCount > 0
                                    ? primaryColor
                                    : subTextCol,
                                fontSize: 12.5,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // MASTER TOGGLE
            // ==================================================
            _buildSectionHeader('Push Notifications', Icons.sensors_rounded, textCol),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderCol),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                secondary: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
                title: Text(
                  'Allow Push Notifications',
                  style: TextStyle(
                    color: textCol,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Enable alerts on this device',
                  style: TextStyle(
                    color: subTextCol,
                    fontSize: 12.5,
                  ),
                ),
                value: _pushNotifications,
                activeThumbColor: primaryColor,
                onChanged: (val) {
                  setState(() => _pushNotifications = val);
                  _updatePref(
                    'notif_push_enabled',
                    val,
                    'Push notifications',
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // ALERT CATEGORIES
            // ==================================================
            _buildSectionHeader(
              'Activity & Status Alerts',
              Icons.tune_rounded,
              textCol,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF14532D).withValues(alpha: 0.4)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Adoption Updates',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Alerts on application review, approval, & interviews',
                      style: TextStyle(
                        color: subTextCol,
                        fontSize: 12,
                      ),
                    ),
                    value: _adoptionAlerts && _pushNotifications,
                    activeThumbColor: tealColor,
                    onChanged: _pushNotifications
                        ? (val) {
                            setState(() => _adoptionAlerts = val);
                            _updatePref(
                              'notif_adoption_enabled',
                              val,
                              'Adoption alerts',
                            );
                          }
                        : null,
                  ),
                  Divider(height: 1, color: borderCol),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF7C2D12).withValues(alpha: 0.4)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_month_outlined,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Visit & Appointment Reminders',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '24-hour and 1-hour reminders before shelter visits',
                      style: TextStyle(
                        color: subTextCol,
                        fontSize: 12,
                      ),
                    ),
                    value: _visitReminders && _pushNotifications,
                    activeThumbColor: tealColor,
                    onChanged: _pushNotifications
                        ? (val) {
                            setState(() => _visitReminders = val);
                            _updatePref(
                              'notif_visit_enabled',
                              val,
                              'Appointment reminders',
                            );
                          }
                        : null,
                  ),
                  Divider(height: 1, color: borderCol),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF581C87).withValues(alpha: 0.4)
                            : const Color(0xFFFDF4FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        color: Color(0xFFA855F7),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Shelter Broadcasts & Drives',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Urgent rescue alerts, adoption events, & news',
                      style: TextStyle(
                        color: subTextCol,
                        fontSize: 12,
                      ),
                    ),
                    value: _shelterBroadcasts && _pushNotifications,
                    activeThumbColor: tealColor,
                    onChanged: _pushNotifications
                        ? (val) {
                            setState(() => _shelterBroadcasts = val);
                            _updatePref(
                              'notif_broadcasts_enabled',
                              val,
                              'Shelter broadcasts',
                            );
                          }
                        : null,
                  ),
                  Divider(height: 1, color: borderCol),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0369A1).withValues(alpha: 0.4)
                            : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.forum_outlined,
                        color: Color(0xFF0284C7),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Community Interactions',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Likes and comments on your shared pet stories',
                      style: TextStyle(
                        color: subTextCol,
                        fontSize: 12,
                      ),
                    ),
                    value: _communityInteractions && _pushNotifications,
                    activeThumbColor: tealColor,
                    onChanged: _pushNotifications
                        ? (val) {
                            setState(() => _communityInteractions = val);
                            _updatePref(
                              'notif_community_enabled',
                              val,
                              'Community alerts',
                            );
                          }
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textCol) {
    return Row(
      children: [
        Icon(icon, size: 17, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textCol,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
