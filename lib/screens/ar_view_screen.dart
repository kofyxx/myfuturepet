import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../pet_data.dart';

class ARViewScreen extends StatefulWidget {
  final Map<String, dynamic>? pet;
  final VoidCallback? onBack;

  const ARViewScreen({
    super.key,
    this.pet,
    this.onBack,
  });

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ============================================================
  // PALETTE & STYLING
  // ============================================================

  static const Color primaryColor = Color(0xFFA94327);
  static const Color darkBrown = Color(0xFF604A43);
  static const Color darkText = Color(0xFF24343A);

  // ============================================================
  // CAMERA STATE
  // ============================================================

  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;

  bool _cameraReady = false;
  bool _cameraError = false;

  // ============================================================
  // AR SPATIAL PLACEMENT & GESTURE STATE
  // ============================================================

  bool _isPetPlaced = true;
  Offset _petPosition = const Offset(0.5, 0.58); // Normalized viewport coordinates [0..1]
  double _scale = 1.0; // Sizing factor (0.5 to 2.2)
  double _baseScale = 1.0;

  String _currentAction = 'Normal'; // 'Normal', 'Sit', 'Wag Tail', 'Speak'
  bool _showSpeechBubble = false;

  // Wag tail animation controller
  late AnimationController _wagController;
  late Animation<double> _wagAnimation;

  // ============================================================
  // AR SURFACE DETECTION & GYROSCOPE MOTION PARALLAX
  // ============================================================

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  bool _surfaceDetected = true;
  String _surfaceStatus = 'Floor Surface Detected 🐾';
  bool _isGroundAnchored = true;
  Offset _gyroParallax = Offset.zero;

  // ============================================================
  // RESOLVED PET DATA
  // ============================================================

  Map<String, dynamic> get _resolvedPet {
    if (widget.pet != null && widget.pet!.isNotEmpty) {
      return widget.pet!;
    }
    if (PetData.pets.isNotEmpty) {
      return PetData.pets.first;
    }
    return {
      'name': 'Sky',
      'breed': 'Labrador mix',
      'type': 'dog',
      'size': 'large',
      'status': 'available',
      'image_url': 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=800',
    };
  }

  String get _petName => _resolvedPet['name']?.toString() ?? 'Sky';
  String get _petBreed => _resolvedPet['breed']?.toString() ?? 'Rescue Pet';
  String get _petType => (_resolvedPet['type']?.toString() ?? 'dog').toLowerCase();
  String get _petSize => _resolvedPet['size']?.toString().toUpperCase() ?? 'MEDIUM';
  String get _petImageUrl {
    final direct = _resolvedPet['image_url']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final photos = _resolvedPet['photos'];
    if (photos is List && photos.isNotEmpty) {
      return photos.first.toString();
    }
    return '';
  }

  // ============================================================
  // 3D MODEL & GOOGLE ARCORE SCENE VIEWER INTEGRATION
  // ============================================================

  bool _is3DStudioMode = false;

  String get _modelGlbUrl {
    final direct = _resolvedPet['model_url']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final isCat = _petType == 'cat' ||
        (_resolvedPet['category']?.toString().toLowerCase() == 'cats');
    if (isCat) {
      return 'https://szdjfucozmsxqjvctptv.supabase.co/storage/v1/object/public/pet-photos/models/cat.glb';
    }
    return 'https://szdjfucozmsxqjvctptv.supabase.co/storage/v1/object/public/pet-photos/models/dog.glb';
  }

  Future<void> _launchGoogleSceneViewer() async {
    final modelUrl = _modelGlbUrl;
    final petTitle = 'My Future Pet - $_petName';

    // 1. Android Intent URI format for Google ARCore Scene Viewer
    final intentUri = Uri.parse(
      'intent://arvr.google.com/scene-viewer/1.0?file=${Uri.encodeComponent(modelUrl)}&mode=ar_only&title=${Uri.encodeComponent(petTitle)}&resizable=false#Intent;scheme=https;package=com.google.ar.core;action=android.intent.action.VIEW;end;',
    );

    // 2. Fallback Web/HTTPS format
    final webUri = Uri.parse(
      'https://arvr.google.com/scene-viewer/1.0?file=${Uri.encodeComponent(modelUrl)}&mode=ar_only&title=${Uri.encodeComponent(petTitle)}',
    );

    try {
      if (await canLaunchUrl(intentUri)) {
        await launchUrl(intentUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('Scene Viewer Intent error: $e');
    }

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('Scene Viewer Web error: $e');
    }

    if (mounted) {
      _showMessage(
        'Opening 3D studio. For real floor projection, Google Play Services for AR is recommended.',
      );
    }
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _wagController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _wagAnimation = Tween<double>(begin: -0.07, end: 0.07).animate(
      CurvedAnimation(
        parent: _wagController,
        curve: Curves.easeInOut,
      ),
    );

    // Initial camera startup
    _initializeCamera();

    // Start surface detection and gyro motion parallax
    _initSensors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _wagController.dispose();
    final controller = _cameraController;
    _cameraController = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_cameraController != null) {
        setState(() {
          _cameraReady = false;
        });
        final controller = _cameraController;
        _cameraController = null;
        controller?.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _initSensors() {
    if (kIsWeb) return;

    try {
      _accelerometerSubscription = accelerometerEventStream().listen(
        (event) {
          final norm = math.sqrt(event.x * event.x + event.z * event.z);
          final pitchDegrees = (math.atan2(event.y, norm) * 180 / math.pi).abs();

          // Pitch between 18 and 78 degrees indicates pointing toward ground/floor
          final bool detected = pitchDegrees >= 18.0 && pitchDegrees <= 78.0;
          if (detected != _surfaceDetected && mounted) {
            setState(() {
              _surfaceDetected = detected;
              _surfaceStatus = detected
                  ? 'Floor Surface Detected (Dining / Kitchen Floor)'
                  : 'Point camera towards the floor to align surface';
            });
          }
        },
        onError: (_) {},
      );

      _gyroscopeSubscription = gyroscopeEventStream().listen(
        (event) {
          if (!_isGroundAnchored || !mounted) return;
          // Apply counter-motion parallax displacement:
          // event.y: yaw velocity (turning left/right), event.x: pitch velocity
          final dx = _gyroParallax.dx - (event.y * 0.0075);
          final dy = _gyroParallax.dy + (event.x * 0.0075);
          setState(() {
            _gyroParallax = Offset(
              dx.clamp(-0.20, 0.20) * 0.985,
              dy.clamp(-0.16, 0.16) * 0.985,
            );
          });
        },
        onError: (_) {},
      );
    } catch (e) {
      debugPrint('Sensor initialization error: $e');
    }
  }

  // ============================================================
  // CAMERA INITIALIZATION WITH BUDGET / WEB FALLBACK
  // ============================================================

  Future<void> _initializeCamera() async {
    // If running on web or desktop without rear camera, switch to failsafe fallback gracefully
    if (kIsWeb) {
      setState(() {
        _cameraError = true;
        _cameraReady = false;
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraError = true;
          _cameraReady = false;
        });
        return;
      }

      CameraDescription selectedCamera = cameras.first;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.back) {
          selectedCamera = cam;
          break;
        }
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _cameraController = controller;
      _initializeCameraFuture = controller.initialize();
      await _initializeCameraFuture;

      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _cameraError = false;
      });
    } catch (e) {
      debugPrint('Camera initialization error (using AR Virtual Room fallback): $e');
      if (!mounted) return;
      setState(() {
        _cameraError = true;
        _cameraReady = false;
      });
    }
  }

  // ============================================================
  // ACTIONS (SIT, WAG TAIL, SPEAK)
  // ============================================================

  void _triggerAction(String action) {
    setState(() {
      _currentAction = action;
      _showSpeechBubble = false;
    });

    if (action == 'Wag Tail') {
      _wagController.repeat(reverse: true);
      _showMessage('$_petName is happily wagging its tail! 🐾');
    } else {
      _wagController.stop();
      _wagController.reset();
    }

    if (action == 'Sit') {
      _showMessage('$_petName is in a calm sit stance.');
    }

    if (action == 'Speak') {
      setState(() => _showSpeechBubble = true);
      final sound = _petType == 'cat' ? 'Meow! Purrr... 🐱' : 'Woof! Woof! 🐶';
      _showMessage('$_petName says: $sound');

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _currentAction == 'Speak') {
          setState(() => _showSpeechBubble = false);
        }
      });
    }
  }

  void _resetAR() {
    setState(() {
      _petPosition = const Offset(0.5, 0.58);
      _scale = 1.0;
      _currentAction = 'Normal';
      _showSpeechBubble = false;
    });
    _wagController.stop();
    _wagController.reset();
    _showMessage('AR view reset to default center placement.');
  }

  void _togglePlacement() {
    setState(() {
      _isPetPlaced = !_isPetPlaced;
    });
    if (_isPetPlaced) {
      _showMessage('$_petName placed in your surroundings! Drag to move, pinch to resize.');
    } else {
      _showMessage('Aim reticle at a flat surface and tap to place $_petName.');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.onBack != null) {
          widget.onBack!();
        }
      },
      child: Scaffold(
        backgroundColor: darkBrown,
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Stack(
                children: [
                  // 1. Live Camera or Virtual Room Fallback (when in Camera mode)
                  if (!_is3DStudioMode)
                    Positioned.fill(
                      child: _buildCameraOrFallback(size),
                    ),

                  // 1b. 3D Studio Model Viewer (when in 3D Studio mode)
                  if (_is3DStudioMode)
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFF1E2833),
                        child: ModelViewer(
                          key: ValueKey(_modelGlbUrl),
                          src: _modelGlbUrl,
                          alt: '3D model of $_petName',
                          ar: true,
                          arModes: const ['scene-viewer', 'webxr', 'quick-look'],
                          autoRotate: true,
                          cameraControls: true,
                          autoPlay: true,
                          animationName: _currentAction == 'Sit'
                              ? 'sit'
                              : (_currentAction == 'Wag Tail' ? 'idle' : 'idle'),
                          backgroundColor: const Color(0xFF1E2833),
                        ),
                      ),
                    ),

                  // 1.5 Floor Placement Guide Reticle (only when placing in camera mode)
                  if (!_is3DStudioMode && !_isPetPlaced)
                    Positioned(
                      bottom: size.height * 0.35,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF00E5D0), width: 1.2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, color: Color(0xFF00E5D0), size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Aim at floor & tap shutter to place pet',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 2. Interactive Pet Spatial Canvas (Pinch / Drag / Shadow) only in camera mode
                  if (!_is3DStudioMode)
                    Positioned.fill(
                      child: _buildInteractiveSpatialCanvas(size),
                    ),

                  // 3. Top Header Bar (Back, Mode Tabs, Floor AR)
                  Positioned(
                    top: 14,
                    left: 14,
                    right: 14,
                    child: _buildTopHeaderBar(),
                  ),

                  // 3.5 Surface Detection HUD Status Banner
                  Positioned(
                    top: 68,
                    left: 16,
                    right: 16,
                    child: _buildSurfaceStatusBanner(),
                  ),

                  // 4. Right Side Toolbar (Move, Resize, Reset, Sizing Slider) - only in camera mode
                  if (!_is3DStudioMode)
                    Positioned(
                      right: 14,
                      bottom: 230,
                      child: _buildRightControls(),
                    ),

                  // 5. Behavior Action Pills (Sit, Wag Tail, Speak)
                  Positioned(
                    bottom: 175,
                    left: 0,
                    right: 0,
                    child: _buildActionRow(),
                  ),

                  // 6. Selected Pet Information Card
                  Positioned(
                    bottom: 92,
                    left: 20,
                    right: 20,
                    child: _buildPetInfoCard(),
                  ),

                  // 7. Bottom Shutter / Placement Button
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: _buildPlacementShutterButton(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CAMERA PASSTHROUGH OR VIRTUAL ROOM FALLBACK
  // ============================================================

  Widget _buildCameraOrFallback(Size size) {
    if (!_cameraError && _cameraReady && _cameraController != null && _cameraController!.value.isInitialized) {
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.width * _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          ),
        ),
      );
    }

    // AR Failsafe Rule: Virtual Room Floor Perspective
    return _buildVirtualRoomFallback(size);
  }

  Widget _buildVirtualRoomFallback(Size size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2C3E50),
            Color(0xFF1E2833),
            Color(0xFF141920),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Room Wall Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Perspective Floor Base
          Positioned(
            top: size.height * 0.42,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(
              painter: _FloorPerspectivePainter(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SPATIAL CANVAS: DRAG, PINCH, SHADOW & ACTION REACTION
  // ============================================================

  Widget _buildInteractiveSpatialCanvas(Size size) {
    if (!_isPetPlaced) {
      // Reticle targeting guide centered on screen
      return Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00E5D0).withValues(alpha: 0.85),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5D0).withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFFFFA65C),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    final cardW = 180.0 * _scale;
    final cardH = 220.0 * _scale;

    // Position calculations with ground parallax anchoring
    final effectiveX = (_petPosition.dx + (_isGroundAnchored ? _gyroParallax.dx : 0.0)).clamp(0.05, 0.95);
    final effectiveY = (_petPosition.dy + (_isGroundAnchored ? _gyroParallax.dy : 0.0)).clamp(0.15, 0.90);

    // Mathematically centered horizontally on screen
    final petX = (effectiveX * size.width) - (cardW / 2);
    final petY = (effectiveY * size.height) - (cardH / 2);

    final maxLeft = math.max(0.0, size.width - cardW);
    final leftPos = petX.clamp(0.0, maxLeft).toDouble();
    final maxTop = math.max(60.0, size.height - cardH - 120.0);
    final topPos = petY.clamp(60.0, math.max(60.0, maxTop)).toDouble();

    return Positioned(
      left: leftPos,
      top: topPos,
      child: GestureDetector(
        onScaleStart: (details) {
          _baseScale = _scale;
        },
        onScaleUpdate: (details) {
          setState(() {
            // Scale
            _scale = (_baseScale * details.scale).clamp(0.5, 2.2);

            // Drag / Pan position
            final newDx = _petPosition.dx + (details.focalPointDelta.dx / size.width);
            final newDy = _petPosition.dy + (details.focalPointDelta.dy / size.height);
            _petPosition = Offset(newDx.clamp(0.1, 0.9), newDy.clamp(0.2, 0.85));
          });
        },
        child: AnimatedBuilder(
          animation: _wagAnimation,
          builder: (context, child) {
            // Dynamic action transforms
            double rotation = 0.0;
            double verticalOffset = 0.0;

            if (_currentAction == 'Wag Tail') {
              rotation = _wagAnimation.value;
            } else if (_currentAction == 'Sit') {
              verticalOffset = 22.0 * _scale; // Sit closer to the contact shadow
            }

            return Transform.translate(
              offset: Offset(0, verticalOffset),
              child: Transform.rotate(
                angle: rotation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Speech bubble when speaking
                    if (_showSpeechBubble) _buildSpeechBubble(),

                    // Pet Avatar with rounded spatial card
                    _buildPetAvatar(),

                    const SizedBox(height: 6),

                    // Realistic Perspective Contact Shadow
                    _buildFloorContactShadow(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeechBubble() {
    final sound = _petType == 'cat' ? 'Meow! Purrr... 🐾' : 'Woof! Woof! 🐾';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        sound,
        style: const TextStyle(
          color: darkBrown,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPetAvatar() {
    final cardWidth = 180.0 * _scale;
    final cardHeight = 190.0 * _scale;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24 * _scale),
        border: Border.all(
          color: Colors.white,
          width: 3.5 * _scale,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 16 * _scale,
            offset: Offset(0, 6 * _scale),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21 * _scale),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image from Supabase or fallback
            if (_petImageUrl.isNotEmpty)
              Image.network(
                _petImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackPetGraphic(),
              )
            else
              _buildFallbackPetGraphic(),

            // Subtle gradient scrim
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),

            // Live Pet Badge
            Positioned(
              bottom: 8 * _scale,
              left: 8 * _scale,
              right: 8 * _scale,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _petName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14 * _scale,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _petBreed,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10 * _scale,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6 * _scale,
                      vertical: 2 * _scale,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF078F80),
                      borderRadius: BorderRadius.circular(10 * _scale),
                    ),
                    child: Text(
                      _petSize,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9 * _scale,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFallbackPetGraphic() {
    return Container(
      color: const Color(0xFF795548),
      child: Center(
        child: Icon(
          _petType == 'cat' ? Icons.pets : Icons.pets,
          color: Colors.white,
          size: 54 * _scale,
        ),
      ),
    );
  }

  Widget _buildFloorContactShadow() {
    final shadowWidth = 140.0 * _scale;
    final shadowHeight = 22.0 * _scale;

    return Container(
      width: shadowWidth,
      height: shadowHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.elliptical(shadowWidth / 2, shadowHeight / 2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18 * _scale,
            spreadRadius: 2 * _scale,
            offset: Offset(0, 3 * _scale),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP BAR (BACK, TITLE PILL, HELP)
  // ============================================================

  Widget _buildTopHeaderBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _roundButton(
          icon: Icons.arrow_back,
          onTap: _handleBack,
        ),

        // Mode switch tabs: Camera AR vs 3D Studio
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeTab(
                title: 'Camera AR',
                icon: Icons.camera_alt_outlined,
                isSelected: !_is3DStudioMode,
                onTap: () {
                  setState(() => _is3DStudioMode = false);
                  _showMessage('Switched to Live Camera AR View');
                },
              ),
              _buildModeTab(
                title: '3D Studio',
                icon: Icons.view_in_ar_rounded,
                isSelected: _is3DStudioMode,
                onTap: () {
                  setState(() => _is3DStudioMode = true);
                  _showMessage('Switched to Interactive 3D Model Studio');
                },
              ),
            ],
          ),
        ),

        // Floor AR button (Google ARCore Scene Viewer)
        _roundButton(
          icon: Icons.view_in_ar,
          tooltip: 'Floor AR (ARCore)',
          backgroundColor: const Color(0xFF008F82),
          iconColor: Colors.white,
          onTap: _launchGoogleSceneViewer,
        ),
      ],
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : darkText,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : darkText,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SURFACE STATUS HUD BANNER
  // ============================================================

  Widget _buildSurfaceStatusBanner() {
    final statusText = _is3DStudioMode
        ? '3D Interactive Studio • 360° View & Rigged Animations'
        : _surfaceStatus;
    final isDetected = _is3DStudioMode ? true : _surfaceDetected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDetected ? const Color(0xFF00E5D0) : const Color(0xFFFFA65C),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _is3DStudioMode
                ? Icons.view_in_ar_rounded
                : (_surfaceDetected ? Icons.check_circle_rounded : Icons.search_rounded),
            size: 15,
            color: isDetected ? const Color(0xFF00E5D0) : const Color(0xFFFFA65C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!_is3DStudioMode && _surfaceDetected) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isGroundAnchored = !_isGroundAnchored;
                  _gyroParallax = Offset.zero;
                });
                _showMessage(_isGroundAnchored
                    ? 'Floor surface locked! Pet stays fixed on ground.'
                    : 'Floor lock off (free-floating).');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isGroundAnchored ? const Color(0xFF008F82) : Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isGroundAnchored ? 'LOCKED' : 'UNLOCK',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else if (_is3DStudioMode) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _launchGoogleSceneViewer,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF008F82),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_in_ar, size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'FLOOR AR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // RIGHT SIDE CONTROLS (RESET, SCALE SLIDER)
  // ============================================================

  Widget _buildRightControls() {
    return Column(
      children: [
        _roundButton(
          icon: _isGroundAnchored ? Icons.anchor : Icons.anchor_outlined,
          tooltip: _isGroundAnchored ? 'Floor Anchor: ON' : 'Floor Anchor: OFF',
          backgroundColor: _isGroundAnchored ? const Color(0xFF008F82) : Colors.white,
          iconColor: _isGroundAnchored ? Colors.white : darkBrown,
          onTap: () {
            setState(() {
              _isGroundAnchored = !_isGroundAnchored;
              _gyroParallax = Offset.zero;
            });
            _showMessage(_isGroundAnchored
                ? 'Floor surface lock enabled! 🐾'
                : 'Free-floating mode enabled.');
          },
        ),
        const SizedBox(height: 10),
        _roundButton(
          icon: Icons.refresh,
          tooltip: 'Reset AR Position',
          onTap: _resetAR,
        ),
        const SizedBox(height: 10),
        _roundButton(
          icon: Icons.zoom_in,
          tooltip: 'Enlarge Pet',
          onTap: () {
            setState(() {
              _scale = (_scale + 0.15).clamp(0.5, 2.2);
            });
            _showMessage('Scale: ${(_scale * 100).toInt()}%');
          },
        ),
        const SizedBox(height: 10),
        _roundButton(
          icon: Icons.zoom_out,
          tooltip: 'Shrink Pet',
          onTap: () {
            setState(() {
              _scale = (_scale - 0.15).clamp(0.5, 2.2);
            });
            _showMessage('Scale: ${(_scale * 100).toInt()}%');
          },
        ),
        const SizedBox(height: 10),
        _roundButton(
          icon: Icons.help_outline,
          tooltip: 'How to Use AR',
          onTap: _showHelpDialog,
        ),
      ],
    );
  }

  // ============================================================
  // BEHAVIOR ACTIONS (SIT, WAG TAIL, SPEAK)
  // ============================================================

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _actionButton(
          label: 'Sit',
          icon: Icons.airline_seat_recline_normal,
          isSelected: _currentAction == 'Sit',
          onTap: () => _triggerAction('Sit'),
        ),
        const SizedBox(width: 8),
        _actionButton(
          label: 'Wag Tail',
          icon: Icons.pets,
          isSelected: _currentAction == 'Wag Tail',
          onTap: () => _triggerAction('Wag Tail'),
        ),
        const SizedBox(width: 8),
        _actionButton(
          label: 'Speak',
          icon: Icons.record_voice_over,
          isSelected: _currentAction == 'Speak',
          onTap: () => _triggerAction('Speak'),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : darkBrown,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : darkBrown,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PET SUMMARY BOTTOM CARD
  // ============================================================

  Widget _buildPetInfoCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: _petImageUrl.isNotEmpty
                  ? Image.network(
                      _petImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildThumbFallback(),
                    )
                  : _buildThumbFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _petName,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_petBreed • $_petSize size',
                  style: const TextStyle(
                    color: Color(0xFF6A7982),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isPetPlaced ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPetPlaced ? Icons.check_circle : Icons.touch_app,
                  size: 13,
                  color: _isPetPlaced ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                ),
                const SizedBox(width: 4),
                Text(
                  _isPetPlaced ? 'Placed' : 'Tap to Place',
                  style: TextStyle(
                    color: _isPetPlaced ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbFallback() {
    return Container(
      color: const Color(0xFFE0E0E0),
      child: const Icon(
        Icons.pets,
        color: Color(0xFF757575),
        size: 26,
      ),
    );
  }

  // ============================================================
  // PLACEMENT SHUTTER BUTTON
  // ============================================================

  Widget _buildPlacementShutterButton() {
    if (_is3DStudioMode) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _launchGoogleSceneViewer,
          icon: const Icon(Icons.view_in_ar, color: Colors.white, size: 20),
          label: const Text(
            'Project on Real Floor (Google AR)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF008F82),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 6,
          ),
        ),
      );
    }

    return Center(
      child: GestureDetector(
        onTap: _togglePlacement,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isPetPlaced ? primaryColor : const Color(0xFF078F80),
            ),
            child: Icon(
              _isPetPlaced ? Icons.crop_free : Icons.add_location_alt,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? darkBrown,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELP DIALOG
  // ============================================================

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.view_in_ar, color: primaryColor),
              SizedBox(width: 8),
              Text(
                'How to use AR View',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpRow(Icons.touch_app, 'Tap the shutter button or surface to place $_petName.'),
              const SizedBox(height: 10),
              _buildHelpRow(Icons.pan_tool, 'Touch and drag to move $_petName around your space.'),
              const SizedBox(height: 10),
              _buildHelpRow(Icons.pinch, 'Pinch with 2 fingers or use the right zoom buttons to scale size.'),
              const SizedBox(height: 10),
              _buildHelpRow(Icons.view_in_ar_rounded, 'Switch to "3D Studio" at top for full 360° orbiting and rigged animations.'),
              const SizedBox(height: 10),
              _buildHelpRow(Icons.open_in_new, 'Tap "Floor AR" to project real 3D pet on your physical floor with Google ARCore surface tracking.'),
              const SizedBox(height: 10),
              _buildHelpRow(Icons.pets, 'Tap Sit, Wag Tail, or Speak to trigger real-time pet reactions.'),
              const SizedBox(height: 10),
              _buildHelpRow(Icons.refresh, 'Tap Reset to return $_petName to the center.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Got it!',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF078F80)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 13),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// ============================================================
// FLOOR PERSPECTIVE PAINTER (BUDGET / WEBCAM FALLBACK)
// ============================================================

class _FloorPerspectivePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4A342B).withValues(alpha: 0.85),
          const Color(0xFF281C16),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Floor planks / grid perspective lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    final vanishingX = size.width / 2;
    const vanishingY = -60.0;

    for (double x = -size.width * 0.4; x <= size.width * 1.4; x += size.width * 0.15) {
      canvas.drawLine(
        Offset(vanishingX, vanishingY),
        Offset(x, size.height),
        linePaint,
      );
    }

    // Horizontal perspective lines
    for (double i = 0.15; i < 1.0; i += 0.16) {
      final y = size.height * math.pow(i, 1.8);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}