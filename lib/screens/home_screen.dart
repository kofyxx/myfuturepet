import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final Color primaryColor = const Color(0xFFA94327);
  final Color backgroundColor = const Color(0xFFF5FAFD);
  final Color darkText = const Color(0xFF062B35);

  final List<Map<String, dynamic>> featuredPets = [
    {
      'name': 'Max',
      'breed': 'Golden Retriever',
      'age': '2 yrs',
      'image':
          'https://images.unsplash.com/photo-1552053831-71594a27632d?w=800',
      'local': true,
    },
    {
      'name': 'Luna',
      'breed': 'Domestic Shorthair',
      'age': '1 yr',
      'image':
          'https://images.unsplash.com/photo-1519052537078-e6302a4968d4?w=800',
      'local': false,
    },
  ];

  final List<Map<String, String>> recommendedPets = [
    {
      'name': 'Charlie',
      'breed': 'Bulldog',
      'age': '3 yrs',
      'image':
          'https://images.unsplash.com/photo-1558788353-f76d92427f16?w=800',
    },
    {
      'name': 'Milo',
      'breed': 'Siamese',
      'age': '2 yrs',
      'image':
          'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=800',
    },
    {
      'name': 'Daisy',
      'breed': 'Poodle',
      'age': '1 yr',
      'image':
          'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800',
    },
    {
      'name': 'Oliver',
      'breed': 'Tabby',
      'age': '4 mos',
      'image':
          'https://images.unsplash.com/photo-1574158622682-e40e69881006?w=800',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomePage(),
            _buildPetsPage(),
            _buildARPage(),
            _buildFeedPage(),
            _buildProfilePage(),
          ],
        ),
      ),

      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // HOME PAGE
  // ============================================================

  Widget _buildHomePage() {
    final user = AuthService().currentUser;

    final String displayName =
        user?.userMetadata?['name']?.toString() ??
        user?.email?.split('@').first ??
        'Pet Lover';

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // --------------------------------------------------------
        // TOP APP BAR
        // --------------------------------------------------------

        SliverToBoxAdapter(
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE5E5E5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // PROFILE IMAGE
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE5E5E5),
                    ),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // APP NAME
                Expanded(
                  child: Text(
                    'My Future Pet',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // NOTIFICATION
                IconButton(
                  onPressed: () {
                    _showMessage(
                      'No new notifications.',
                    );
                  },
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: darkText,
                    size: 27,
                  ),
                ),
              ],
            ),
          ),
        ),

        // --------------------------------------------------------
        // CONTENT
        // --------------------------------------------------------

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            28,
            15,
            28,
            30,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                // HERO BANNER
                _buildHeroBanner(),

                const SizedBox(height: 34),

                // CATEGORIES
                _buildSectionTitle(
                  title: 'Categories',
                  showSeeAll: false,
                ),

                const SizedBox(height: 15),

                _buildCategories(),

                const SizedBox(height: 34),

                // FEATURED
                _buildSectionTitle(
                  title: 'Featured Pets',
                  showSeeAll: true,
                  onSeeAll: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),

                const SizedBox(height: 14),

                _buildFeaturedPets(),

                const SizedBox(height: 40),

                // RECOMMENDED
                _buildSectionTitle(
                  title: 'Recommended for You',
                  showSeeAll: false,
                ),

                const SizedBox(height: 15),

                _buildRecommendedPets(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HERO BANNER
  // ============================================================

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      height: 248,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFC95635),
            Color(0xFF99644F),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find your new best\nfriend',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Discover pets available for adoption near\nyou.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),

          const Spacer(),

          ElevatedButton.icon(
            onPressed: () {
              _showMessage(
                'Pet search coming soon.',
              );
            },

            icon: const Icon(
              Icons.search,
              size: 22,
            ),

            label: const Text(
              'Start Search',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFFAA3F20),
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 14,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle({
    required String title,
    required bool showSeeAll,
    VoidCallback? onSeeAll,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: darkText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        if (showSeeAll)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'See all ›',
              style: TextStyle(
                color: primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  Widget _buildCategories() {
    return Row(
      children: [
        Expanded(
          child: _buildCategoryCard(
            title: 'Dogs',
            icon: Icons.pets,
            iconBackground:
                const Color(0xFFFFAF62),
            onTap: () {
              _showMessage(
                'Showing dogs.',
              );
            },
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: _buildCategoryCard(
            title: 'Cats',
            icon: Icons.cruelty_free,
            iconBackground:
                const Color(0xFF008F82),
            onTap: () {
              _showMessage(
                'Showing cats.',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required IconData icon,
    required Color iconBackground,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 134,
        decoration: BoxDecoration(
          color: const Color(0xFFE5F5FD),
          borderRadius:
              BorderRadius.circular(17),
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF67310F),
                size: 35,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              title,
              style: TextStyle(
                color: darkText,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FEATURED PETS
  // ============================================================

  Widget _buildFeaturedPets() {
    return SizedBox(
      height: 320,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,

        physics:
            const BouncingScrollPhysics(),

        itemCount: featuredPets.length,

        separatorBuilder:
            (_, __) =>
                const SizedBox(width: 16),

        itemBuilder: (context, index) {
          final pet =
              featuredPets[index];

          return _buildFeaturedPetCard(
            pet,
          );
        },
      ),
    );
  }

  Widget _buildFeaturedPetCard(
    Map<String, dynamic> pet,
  ) {
    return GestureDetector(
      onTap: () {
        _showMessage(
          'Opening ${pet['name']} profile.',
        );
      },

      child: Container(
        width: 272,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius:
              BorderRadius.circular(25),
        ),
        clipBehavior:
            Clip.antiAlias,

        child: Stack(
          children: [
            // IMAGE
            Positioned.fill(
              child: Image.network(
                pet['image'],
                fit: BoxFit.cover,

                errorBuilder:
                    (_, __, ___) {
                  return Container(
                    color:
                        const Color(0xFF222222),
                    child: const Icon(
                      Icons.pets,
                      color: Colors.white,
                      size: 70,
                    ),
                  );
                },
              ),
            ),

            // DARK GRADIENT
            Positioned.fill(
              child: DecoratedBox(
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black
                          .withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),

            // FAVORITE BUTTON
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  _showMessage(
                    '${pet['name']} added to favorites.',
                  );
                },
                child: Container(
                  width: 43,
                  height: 43,
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withOpacity(0.55),
                    shape:
                        BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    color:
                        Color(0xFF16414A),
                    size: 26,
                  ),
                ),
              ),
            ),

            // PET INFORMATION
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet['name'],
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 28,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 2,
                        ),

                        Text(
                          '${pet['breed']} • ${pet['age']}',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (pet['local'] == true)
                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFF008F82,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: const Text(
                        'Local',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 11,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RECOMMENDED PETS
  // ============================================================

  Widget _buildRecommendedPets() {
    return GridView.builder(
      shrinkWrap: true,

      physics:
          const NeverScrollableScrollPhysics(),

      itemCount:
          recommendedPets.length,

      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 0.76,
      ),

      itemBuilder: (context, index) {
        final pet =
            recommendedPets[index];

        return _buildRecommendedPetCard(
          pet,
        );
      },
    );
  }

  Widget _buildRecommendedPetCard(
    Map<String, String> pet,
  ) {
    return GestureDetector(
      onTap: () {
        _showMessage(
          'Opening ${pet['name']} profile.',
        );
      },

      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.05),
              blurRadius: 6,
              offset:
                  const Offset(0, 2),
            ),
          ],
        ),

        clipBehavior:
            Clip.antiAlias,

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Expanded(
              child: Image.network(
                pet['image']!,
                width: double.infinity,
                fit: BoxFit.cover,

                errorBuilder:
                    (_, __, ___) {
                  return Container(
                    color:
                        const Color(0xFFE9EEF0),
                    child: const Center(
                      child: Icon(
                        Icons.pets,
                        size: 50,
                        color:
                            Color(0xFFA94327),
                      ),
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                13,
                10,
                13,
                11,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    pet['name']!,
                    style:
                        TextStyle(
                      color: darkText,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '${pet['breed']} • ${pet['age']}',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Color(0xFF6E5D57),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2F5FC),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset:
                const Offset(0, -2),
          ),
        ],
      ),

      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),

          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,

            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
              ),

              _buildNavItem(
                index: 1,
                icon: Icons.pets,
                label: 'Pets',
              ),

              _buildNavItem(
                index: 2,
                icon: Icons.center_focus_strong,
                label: 'AR View',
              ),

              _buildNavItem(
                index: 3,
                icon: Icons.people_outline,
                label: 'Feed',
              ),

              _buildNavItem(
                index: 4,
                icon: Icons.person_outline,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected =
        _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },

      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 200),

        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 7,
        ),

        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFFB15F)
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(25),
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Icon(
              icon,
              size: 23,
              color: selected
                  ? const Color(0xFF713711)
                  : const Color(0xFF526069),
            ),

            const SizedBox(height: 2),

            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? const Color(0xFF713711)
                    : const Color(0xFF526069),
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OTHER PAGES - TEMPORARY
  // ============================================================

  Widget _buildPetsPage() {
    return _buildPlaceholderPage(
      icon: Icons.pets,
      title: 'Pets',
      description:
          'Browse pets available for adoption.',
    );
  }

  Widget _buildARPage() {
    return _buildPlaceholderPage(
      icon: Icons.center_focus_strong,
      title: 'AR View',
      description:
          'View pets using Augmented Reality.',
    );
  }

  Widget _buildFeedPage() {
    return _buildPlaceholderPage(
      icon: Icons.people_outline,
      title: 'Community Feed',
      description:
          'See updates from the pet community.',
    );
  }

  Widget _buildProfilePage() {
    final user =
        AuthService().currentUser;

    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(25),

      child: Column(
        children: [
          const SizedBox(height: 30),

          const CircleAvatar(
            radius: 50,
            backgroundColor:
                Color(0xFFE5F5FD),
            child: Icon(
              Icons.person,
              size: 55,
              color: Color(0xFFA94327),
            ),
          ),

          const SizedBox(height: 15),

          Text(
            user?.userMetadata?['name']
                    ?.toString() ??
                'Pet Lover',
            style: TextStyle(
              color: darkText,
              fontSize: 23,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            user?.email ?? '',
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 35),

          SizedBox(
            width: double.infinity,
            height: 55,

            child: ElevatedButton.icon(
              onPressed: _logout,

              icon: const Icon(
                Icons.logout,
              ),

              label: const Text(
                'Logout',
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryColor,
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 80,
              color: primaryColor,
            ),

            const SizedBox(height: 20),

            Text(
              title,
              style: TextStyle(
                color: darkText,
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    try {
      await AuthService().logout();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,

        MaterialPageRoute(
          builder: (_) =>
              const LoginScreen(),
        ),

        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Logout failed: $e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }
}










// import 'package:flutter/material.dart';

// import '../services/auth_service.dart';
// import 'login_screen.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   bool _isLoggingOut = false;

//   // ============================================================
//   // LOGOUT
//   // ============================================================

//   Future<void> _logout() async {
//     // Prevent multiple logout clicks
//     if (_isLoggingOut) return;

//     try {
//       setState(() {
//         _isLoggingOut = true;
//       });

//       // Sign out from Supabase
//       await AuthService().logout();

//       if (!mounted) return;

//       // Remove HomeScreen and go back to LoginScreen
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder: (context) => const LoginScreen(),
//         ),
//         (route) => false,
//       );
//     } catch (e) {
//       if (!mounted) return;

//       setState(() {
//         _isLoggingOut = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Logout failed: $e',
//           ),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 4),
//         ),
//       );
//     }
//   }

//   // ============================================================
//   // BUILD
//   // ============================================================

//   @override
//   Widget build(BuildContext context) {
//     // Get currently logged-in Supabase user
//     final user = AuthService().currentUser;

//     return Scaffold(
//       // ==========================================================
//       // APP BAR
//       // ==========================================================

//       appBar: AppBar(
//         title: const Text(
//           'My Future Pet',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//           ),
//         ),

//         backgroundColor: const Color(0xFFA94327),

//         foregroundColor: Colors.white,

//         // ========================================================
//         // LOGOUT BUTTON
//         // ========================================================

//         actions: [
//           IconButton(
//             tooltip: 'Logout',

//             // Disable button while logging out
//             onPressed: _isLoggingOut ? null : _logout,

//             icon: _isLoggingOut
//                 ? const SizedBox(
//                     width: 22,
//                     height: 22,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2.5,
//                       color: Colors.white,
//                     ),
//                   )
//                 : const Icon(
//                     Icons.logout,
//                   ),
//           ),
//         ],
//       ),

//       // ==========================================================
//       // BODY
//       // ==========================================================

//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),

//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,

//             children: [
//               // ==================================================
//               // PET ICON
//               // ==================================================

//               const Icon(
//                 Icons.pets,
//                 size: 80,
//                 color: Color(0xFFA94327),
//               ),

//               const SizedBox(height: 20),

//               // ==================================================
//               // WELCOME
//               // ==================================================

//               const Text(
//                 'Welcome to My Future Pet!',

//                 textAlign: TextAlign.center,

//                 style: TextStyle(
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),

//               const SizedBox(height: 10),

//               // ==================================================
//               // USER EMAIL
//               // ==================================================

//               Text(
//                 user?.email ?? 'No email found',

//                 textAlign: TextAlign.center,

//                 style: const TextStyle(
//                   color: Colors.grey,
//                   fontSize: 16,
//                 ),
//               ),

//               const SizedBox(height: 30),

//               // ==================================================
//               // DASHBOARD MESSAGE
//               // ==================================================

//               const Text(
//                 'Your pet adoption dashboard will go here.',

//                 textAlign: TextAlign.center,

//                 style: TextStyle(
//                   fontSize: 15,
//                   color: Colors.grey,
//                 ),
//               ),

//               const SizedBox(height: 40),

//               // ==================================================
//               // LOGOUT BUTTON
//               // ==================================================
//               //
//               // This is an additional visible logout button.
//               // You can remove this section if you only want
//               // the logout icon in the AppBar.
//               //

//               SizedBox(
//                 width: 220,
//                 height: 50,

//                 child: ElevatedButton.icon(
//                   onPressed:
//                       _isLoggingOut ? null : _logout,

//                   icon: _isLoggingOut
//                       ? const SizedBox(
//                           width: 20,
//                           height: 20,

//                           child:
//                               CircularProgressIndicator(
//                             strokeWidth: 2,
//                             color: Colors.white,
//                           ),
//                         )
//                       : const Icon(
//                           Icons.logout,
//                         ),

//                   label: Text(
//                     _isLoggingOut
//                         ? 'Logging out...'
//                         : 'Logout',
//                   ),

//                   style:
//                       ElevatedButton.styleFrom(
//                     backgroundColor:
//                         const Color(0xFFA94327),

//                     foregroundColor:
//                         Colors.white,

//                     disabledBackgroundColor:
//                         Colors.grey,

//                     shape:
//                         RoundedRectangleBorder(
//                       borderRadius:
//                           BorderRadius.circular(25),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }









// import 'package:flutter/material.dart';

// import '../services/auth_service.dart';
// import 'login_screen.dart';

// class HomeScreen extends StatelessWidget {
//   const HomeScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final user =
//         AuthService().currentUser;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'My Future Pet',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//           ),
//         ),

//         backgroundColor:
//             const Color(0xFFA94327),

//         foregroundColor: Colors.white,

//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),

//             onPressed: () async {
//               await AuthService().logout();

//               if (!context.mounted) return;

//               Navigator.pushAndRemoveUntil(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) =>
//                       const LoginScreen(),
//                 ),
//                 (route) => false,
//               );
//             },
//           ),
//         ],
//       ),

//       body: Center(
//         child: Column(
//           mainAxisAlignment:
//               MainAxisAlignment.center,

//           children: [
//             const Icon(
//               Icons.pets,
//               size: 80,
//               color: Color(0xFFA94327),
//             ),

//             const SizedBox(height: 20),

//             const Text(
//               'Welcome to My Future Pet!',
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),

//             const SizedBox(height: 10),

//             Text(
//               user?.email ?? '',
//               style: const TextStyle(
//                 color: Colors.grey,
//               ),
//             ),

//             const SizedBox(height: 30),

//             const Text(
//               'Your pet adoption dashboard will go here.',
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }