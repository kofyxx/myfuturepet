import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  static const Color primaryColor = Color(0xFFA94327);
  static const Color tealColor = Color(0xFF008F82);

  String _preferredSpecies = 'All Pets';
  String _preferredSize = 'Any Size';
  String _preferredAge = 'Any Age';
  List<String> _selectedTemperaments = ['Friendly', 'Gentle'];

  bool _vaccinatedOnly = false;
  bool _freeAdoptionOnly = true;
  bool _specialNeedsWelcomed = false;

  final List<String> _speciesOptions = ['All Pets', 'Dogs Only', 'Cats Only'];
  final List<String> _sizeOptions = ['Any Size', 'Small', 'Medium', 'Large'];
  final List<String> _ageOptions = [
    'Any Age',
    'Puppy / Kitten (< 1 yr)',
    'Young (1 - 3 yrs)',
    'Adult (3 - 7 yrs)',
    'Senior (7+ yrs)',
  ];

  final List<String> _temperamentOptions = [
    'Friendly',
    'Gentle',
    'Good with Kids',
    'Calm / Quiet',
    'Playful / Active',
    'Independent',
    'Trained',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _preferredSpecies = prefs.getString('pref_species') ?? 'All Pets';
      _preferredSize = prefs.getString('pref_size') ?? 'Any Size';
      _preferredAge = prefs.getString('pref_age') ?? 'Any Age';
      _selectedTemperaments = prefs.getStringList('pref_temperament') ??
          ['Friendly', 'Gentle'];
      _vaccinatedOnly = prefs.getBool('pref_vaccinated') ?? false;
      _freeAdoptionOnly = prefs.getBool('pref_free_adoption') ?? true;
      _specialNeedsWelcomed = prefs.getBool('pref_special_needs') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pref_species', _preferredSpecies);
    await prefs.setString('pref_size', _preferredSize);
    await prefs.setString('pref_age', _preferredAge);
    await prefs.setStringList('pref_temperament', _selectedTemperaments);
    await prefs.setBool('pref_vaccinated', _vaccinatedOnly);
    await prefs.setBool('pref_free_adoption', _freeAdoptionOnly);
    await prefs.setBool('pref_special_needs', _specialNeedsWelcomed);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Adoption preferences saved!'),
            ],
          ),
          backgroundColor: Color(0xFF008F82),
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
          'Adoption Preferences',
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
            // SPECIES PREFERENCE
            // ==================================================
            _buildSectionHeader('Preferred Species', Icons.pets_outlined, textCol),
            const SizedBox(height: 10),
            _buildSingleSelectWrap(
              options: _speciesOptions,
              selected: _preferredSpecies,
              onSelected: (val) => setState(() => _preferredSpecies = val),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textCol: textCol,
            ),

            const SizedBox(height: 24),

            // ==================================================
            // SIZE PREFERENCE
            // ==================================================
            _buildSectionHeader('Preferred Pet Size', Icons.straighten_outlined, textCol),
            const SizedBox(height: 10),
            _buildSingleSelectWrap(
              options: _sizeOptions,
              selected: _preferredSize,
              onSelected: (val) => setState(() => _preferredSize = val),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textCol: textCol,
            ),

            const SizedBox(height: 24),

            // ==================================================
            // AGE PREFERENCE
            // ==================================================
            _buildSectionHeader('Preferred Age Group', Icons.cake_outlined, textCol),
            const SizedBox(height: 10),
            _buildSingleSelectWrap(
              options: _ageOptions,
              selected: _preferredAge,
              onSelected: (val) => setState(() => _preferredAge = val),
              isDark: isDark,
              cardBg: cardBg,
              borderCol: borderCol,
              textCol: textCol,
            ),

            const SizedBox(height: 24),

            // ==================================================
            // TEMPERAMENT PREFERENCE
            // ==================================================
            _buildSectionHeader(
              'Personality & Temperament',
              Icons.psychology_outlined,
              textCol,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _temperamentOptions.map((trait) {
                final isSelected = _selectedTemperaments.contains(trait);
                return FilterChip(
                  label: Text(trait),
                  selected: isSelected,
                  selectedColor: isDark
                      ? tealColor.withValues(alpha: 0.25)
                      : const Color(0xFFE5F8F6),
                  backgroundColor: cardBg,
                  checkmarkColor: tealColor,
                  labelStyle: TextStyle(
                    color: isSelected ? tealColor : textCol,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: isSelected ? tealColor : borderCol,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTemperaments.add(trait);
                      } else {
                        _selectedTemperaments.remove(trait);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // HEALTH & POLICIES
            // ==================================================
            _buildSectionHeader(
              'Health & Shelter Requirements',
              Icons.health_and_safety_outlined,
              textCol,
            ),
            const SizedBox(height: 10),
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
                    title: Text(
                      'Fully Vaccinated Only',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Filter for pets with complete vaccination cards',
                      style: TextStyle(
                        color: subTextCol,
                        fontSize: 12,
                      ),
                    ),
                    value: _vaccinatedOnly,
                    activeThumbColor: tealColor,
                    onChanged: (val) => setState(() => _vaccinatedOnly = val),
                  ),
                  Divider(height: 1, color: borderCol),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      'Free Adoption Only',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Highlight pets with waived adoption & care fees',
                      style: TextStyle(
                        color: subTextCol,
                        fontSize: 12,
                      ),
                    ),
                    value: _freeAdoptionOnly,
                    activeThumbColor: tealColor,
                    onChanged: (val) =>
                        setState(() => _freeAdoptionOnly = val),
                  ),
                  Divider(height: 1, color: borderCol),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      'Special Needs Pets Welcomed',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Include pets requiring extra TLC or quiet homes',
                      style: TextStyle(
                        color: subTextCol,
                        fontSize: 12,
                      ),
                    ),
                    value: _specialNeedsWelcomed,
                    activeThumbColor: tealColor,
                    onChanged: (val) =>
                        setState(() => _specialNeedsWelcomed = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ==================================================
            // SAVE BUTTON
            // ==================================================
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _savePreferences,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text(
                  'Save Preferences',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
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

  Widget _buildSingleSelectWrap({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    required bool isDark,
    required Color cardBg,
    required Color borderCol,
    required Color textCol,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selected == option;
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          selectedColor: isDark
              ? primaryColor.withValues(alpha: 0.3)
              : const Color(0xFFFEE2E2),
          backgroundColor: cardBg,
          labelStyle: TextStyle(
            color: isSelected ? (isDark ? const Color(0xFFFF8A65) : primaryColor) : textCol,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
          side: BorderSide(
            color: isSelected ? primaryColor : borderCol,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onSelected: (val) {
            if (val) onSelected(option);
          },
        );
      }).toList(),
    );
  }
}
