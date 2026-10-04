import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  static const Color primaryColor = Color(0xFFA94327);
  static const Color tealColor = Color(0xFF008F82);

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How does the adoption process work?',
      'answer':
          '1. Find an adoptable pet you love on the Home or Pets tab.\n2. Tap "Apply for Adoption" to submit your structured questionnaire.\n3. Shelter staff review your application and schedule an interview.\n4. Complete the adoption agreement and welcome your new best friend home!',
    },
    {
      'question': 'Is pet adoption really 100% free?',
      'answer':
          'Yes! Adoption fees are waived in partnership with Jagna Animal Lover and Rescue Group to encourage loving homes for rescue animals. Adopters only commit to providing lifelong food, healthcare, and safe shelter.',
    },
    {
      'question': 'Can I visit and meet the pet in person first?',
      'answer':
          'Absolutely! Tap "Schedule Visit" on any pet details page to pick an appointment date and time at the shelter. This gives you and your family time to interact with the pet before applying.',
    },
    {
      'question': 'What requirements or documents are needed?',
      'answer':
          'You will need:\n• One government-issued valid ID\n• Verification of your residence or landlord pet permission\n• Agreement to participate in a standard shelter welfare check-in.',
    },
    {
      'question': 'How do I track my submitted application?',
      'answer':
          'Navigate to your Profile tab and tap "My Applications". Your active applications update live with review statuses: Submitted, Under Review, Approved, or Scheduled for Visit.',
    },
    {
      'question': 'How does the AR 3D Preview work?',
      'answer':
          'On supported devices, tap "AR Preview" on a pet\'s profile to open the camera. Point your phone at a flat floor surface to view a true-to-scale 3D companion in your living room!',
    },
    {
      'question': 'Why can\'t I use AR View on my device?',
      'answer':
          'AR View requires an ARCore-compatible Android device with camera tracking. If your hardware is unsupported, the app seamlessly switches to our Virtual Room Fallback so you can still inspect and interact with the 3D pet without errors.',
    },
    {
      'question': 'How do I save a pet to my favorites?',
      'answer':
          'Tap the heart icon on any pet\'s card or details page. The pet will instantly appear in your Saved Pets list accessible directly from your Profile tab.',
    },
    {
      'question': 'How do I update my profile information?',
      'answer':
          'Navigate to your Profile tab and tap "Edit Profile". You can update your full name, contact phone number, home address, and upload a custom profile picture.',
    },
  ];

  void _callPhone(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact shelter at: $phone')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact shelter at: $phone')),
        );
      }
    }
  }

  void _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=My Future Pet Support Request');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email support at: $email')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email support at: $email')),
        );
      }
    }
  }

  void _showFeedbackDialog() {
    final isDark = ThemeService.isDarkMode(context);
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dialogText = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF062B35);
    final dialogSubText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inputBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String category = 'Feedback';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Send Feedback or Report Issue',
                style: TextStyle(
                  color: dialogText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category',
                      style: TextStyle(
                        color: dialogText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      dropdownColor: dialogBg,
                      style: TextStyle(
                        color: dialogText,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Feedback',
                          child: Text('Feedback & Suggestions', style: TextStyle(color: dialogText)),
                        ),
                        DropdownMenuItem(
                          value: 'Bug Report',
                          child: Text('Technical Issue / Bug', style: TextStyle(color: dialogText)),
                        ),
                        DropdownMenuItem(
                          value: 'Adoption Help',
                          child: Text('Adoption Application Help', style: TextStyle(color: dialogText)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Subject',
                      style: TextStyle(
                        color: dialogText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: subjectController,
                      style: TextStyle(color: dialogText, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Brief summary',
                        hintStyle: TextStyle(color: dialogSubText, fontSize: 13),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Message',
                      style: TextStyle(
                        color: dialogText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: messageController,
                      style: TextStyle(color: dialogText, fontSize: 13),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe your question or issue...',
                        hintStyle: TextStyle(color: dialogSubText, fontSize: 13),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: inputBorder),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: dialogSubText),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final message = messageController.text.trim();
                    if (message.isEmpty) return;
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Thank you! Your feedback has been received.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
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
          'Help & Support',
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
            // SHELTER CONTACT CARD
            // ==================================================
            _buildSectionHeader('Partner Shelter Contact', Icons.support_agent_rounded, textCol),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF008F82).withValues(alpha: 0.2)
                              : const Color(0xFFE5F8F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.home_work_outlined,
                          color: tealColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jagna Animal Lover & Rescue',
                              style: TextStyle(
                                color: textCol,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Jagna, Bohol, Philippines',
                              style: TextStyle(
                                color: subTextCol,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: borderCol),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callPhone('+63 900 000 0000'),
                          icon: const Icon(Icons.phone_outlined, size: 16),
                          label: const Text('Call Shelter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: const BorderSide(color: primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _sendEmail('support@myfuturepet.org'),
                          icon: const Icon(Icons.mail_outline_rounded, size: 16),
                          label: const Text('Email Help'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tealColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // FAQ ACCORDION
            // ==================================================
            _buildSectionHeader('Frequently Asked Questions', Icons.quiz_outlined, textCol),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCol),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _faqs.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: borderCol),
                  itemBuilder: (context, index) {
                    final item = _faqs[index];
                    return Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          14,
                        ),
                        title: Text(
                          item['question']!,
                          style: TextStyle(
                            color: textCol,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        iconColor: tealColor,
                        collapsedIconColor: subTextCol,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item['answer']!,
                              style: TextStyle(
                                color: subTextCol,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // SEND FEEDBACK BUTTON
            // ==================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF7C2D12).withValues(alpha: 0.25)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF9A3412).withValues(alpha: 0.5)
                      : const Color(0xFFFED7AA),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.rate_review_outlined,
                    color: Color(0xFFEA580C),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Have an Idea or Encountered a Bug?',
                          style: TextStyle(
                            color: textCol,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Send feedback to our development team',
                          style: TextStyle(
                            color: subTextCol,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _showFeedbackDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Send'),
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

  Widget _buildSectionHeader(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 17, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
