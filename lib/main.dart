import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';

// ─────────────────────────────────────────────
//  THEME COLORS
// ─────────────────────────────────────────────
const kGold       = Color(0xFFC9A84C);
const kGoldLight  = Color(0xFFF0D080);
const kRebel      = Color(0xFF8B5CF6);
const kRebelLight = Color(0xFFC4B5FD);
const kNight      = Color(0xFF050508);
const kDeep       = Color(0xFF0A0A14);
const kSurface    = Color(0xFF0F0F1A);


// Feed category colors
const kCatOC      = Color(0xFFEC4899); // pink — your original character
const kCatPlot    = Color(0xFF8B5CF6); // purple — rp plots  
const kCatArt     = Color(0xFFF59E0B); // amber — art
const kCatMemes   = Color(0xFF10B981); // emerald — memes
const kCatAll     = Color(0xFF888888);

// ─────────────────────────────────────────────
//  MAIN
// ─────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MynxApp());
}

// ─────────────────────────────────────────────
//  GOOGLE SIGN-IN
// ─────────────────────────────────────────────
Future<UserCredential> signInWithGoogle() async {
  if (kIsWeb) {
    final p = GoogleAuthProvider()
      ..setCustomParameters({"prompt": "select_account"});
    return await FirebaseAuth.instance.signInWithPopup(p);
  }
  final gs = GoogleSignIn();
  await gs.signOut();
  final acc = await gs.signIn();
  if (acc == null) throw Exception("Sign in aborted");
  final a = await acc.authentication;
  return await FirebaseAuth.instance.signInWithCredential(
    GoogleAuthProvider.credential(
      accessToken: a.accessToken,
      idToken: a.idToken,
    ),
  );
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────
Future<String?> uploadImage(File file, String path) async {
  try {
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  } catch (e) {
    debugPrint("Upload error: $e");
    return null;
  }
}

Future<File?> pickImage({bool gallery = true}) async {
  try {
    final p = ImagePicker();
    final x = await p.pickImage(
      source: gallery ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 75,
    );
    return x != null ? File(x.path) : null;
  } catch (e) {
    debugPrint("Pick image error: $e");
    return null;
  }
}

// ─────────────────────────────────────────────
//  APP ROOT  — persistent login state
// ─────────────────────────────────────────────
class MynxApp extends StatelessWidget {
  const MynxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kNight,
        colorScheme: const ColorScheme.dark(primary: kGold, secondary: kRebel),
      ),
      home: const _SplashGate(),
    );
  }
}

// ── Splash gate decides where to route ───────
class _SplashGate extends StatefulWidget {
  const _SplashGate();
  @override
  State<_SplashGate> createState() => _SplashGateState();
}
  class _SplashGateState extends State<_SplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _SplashScreen();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        if (snap.hasData && snap.data != null) {
          final user = snap.data!;
          if (user.displayName == null || user.displayName!.isEmpty) {
            return const ProfileSetupScreen();
          }
          return const MainShell();
        }
        return const LoreIntroScreen();
      },
    );
  }
}

// ─────────────────────────────────────────────
//  SPLASH SCREEN
// ─────────────────────────────────────────────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl, _pulseCtrl, _particleCtrl;
  late Animation<double> _logoFade, _logoScale, _pulse;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _particleCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _logoCtrl.forward();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      body: Stack(children: [
        // Animated particles
        AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) => CustomPaint(
              painter: ParticlePainter(_particleCtrl.value),
              size: Size.infinite),
        ),
        // Radial glow behind logo
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) => Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  kRebel.withOpacity(0.08 + _pulse.value * 0.06),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
        // Logo
        Center(
          child: FadeTransition(
            opacity: _logoFade,
            child: ScaleTransition(
              scale: _logoScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Moon glyph
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Text(
                      "🌙",
                      style: TextStyle(
                        fontSize: 48,
                        shadows: [
                          Shadow(
                              color: kRebelLight
                                  .withOpacity(0.3 + _pulse.value * 0.4),
                              blurRadius: 30),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // MynX wordmark
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 68,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          shadows: [Shadow(color: kGold, blurRadius: 40)]),
                      children: [
                        TextSpan(
                            text: "Myn",
                            style: TextStyle(color: kGoldLight)),
                        TextSpan(
                            text: "X",
                            style: TextStyle(
                                color: kRebelLight,
                                shadows: [
                                  Shadow(color: kRebel, blurRadius: 30)
                                ])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "WHERE MISCHIEF BEGINS",
                    style: TextStyle(
                        color: kRebelLight,
                        fontSize: 11,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 32),
                  // Shimmer loading bar
                  _ShimmerBar(),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ShimmerBar extends StatefulWidget {
  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Container(
          width: 160,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            color: Colors.white.withOpacity(0.06),
          ),
          child: FractionallySizedBox(
            widthFactor: 0.4,
            alignment: Alignment(_c.value * 2 - 1, 0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: const LinearGradient(
                  colors: [Colors.transparent, kGoldLight, Colors.transparent],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  MAIN SHELL
// ═══════════════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  late AnimationController _navCtrl;
  final _pages = const [HomeFeedPage(), ChatFeedPage(), ProfilePage()];

  @override
  void initState() {
    super.initState();
    _navCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _navCtrl.forward();
  }

  @override
  void dispose() {
    _navCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kDeep,
          boxShadow: [
            BoxShadow(
                color: kGold.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -4))
          ],
          border: Border(top: BorderSide(color: kGold.withOpacity(0.10))),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                  icon: Icons.auto_awesome,
                  activeIcon: Icons.auto_awesome,
                  label: "Feed",
                  idx: 0,
                  current: _idx,
                  onTap: () => setState(() => _idx = 0)),
              _NavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: "Chat",
                  idx: 1,
                  current: _idx,
                  onTap: () => setState(() => _idx = 1)),
              _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: "Profile",
                  idx: 2,
                  current: _idx,
                  onTap: () => setState(() => _idx = 2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int idx, current;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.idx,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = idx == current;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.all(active ? 6 : 0),
            decoration: BoxDecoration(
              color: active ? kGold.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              active ? activeIcon : icon,
              color: active ? kGold : Colors.white24,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
                color: active ? kGold : Colors.white24,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.normal),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  HOME FEED PAGE
// ═══════════════════════════════════════════════════════════
class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({super.key});
  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  String _activeCategory = "All";

  static const _categories = [
    {"label": "All",        "color": kCatAll},
    {"label": "Originals",  "color": kCatOC},
    {"label": "Plotcraft",  "color": kCatPlot},
    {"label": "Artboard",   "color": kCatArt},
    {"label": "Chaosboard", "color": kCatMemes},
  ];

  Query<Map<String, dynamic>> get _query {
    var q = FirebaseFirestore.instance
        .collection("posts")
        .orderBy("createdAt", descending: true)
        .limit(40);
    if (_activeCategory != "All") {
      q = q.where("category", isEqualTo: _activeCategory);
    }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5),
                      children: [
                        TextSpan(
                            text: "Myn",
                            style: TextStyle(color: kGoldLight)),
                        TextSpan(
                            text: "X",
                            style: TextStyle(
                                color: kRebelLight,
                                shadows: [
                                  Shadow(color: kRebel, blurRadius: 20)
                                ])),
                      ],
                    ),
                  ),
                  Row(children: [
                    _iconBtn(Icons.search, () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const SearchPage()))),
                    const SizedBox(width: 8),
                    _iconBtn(Icons.notifications_none, () {}),
                    const SizedBox(width: 8),
                    _iconBtn(Icons.casino_outlined, () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RpToolsPage()))),
                  ]),
                ]),
          ),
          const SizedBox(height: 12),
          // ── Category chips ───────────────────────
          SizedBox(
            height: 36,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat   = _categories[i];
                final label = cat["label"] as String;
                final color = cat["color"] as Color;
                final active = _activeCategory == label;
                return GestureDetector(
                  onTap: () => setState(() => _activeCategory = label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? color.withOpacity(0.18)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active ? color : Colors.white12),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color: active ? color : Colors.white38,
                            fontSize: 12,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.normal)),
                  ),
                );
              },
            ),
          ),
          Container(
              height: 0.5,
              margin: const EdgeInsets.only(top: 10),
              color: Colors.white12),
          // ── Feed ─────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _query.snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: kGold));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("🌙",
                              style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            "No posts yet in ${_activeCategory == 'All' ? 'the realm' : _activeCategory}",
                            style: const TextStyle(
                                color: Colors.white38),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _openPostComposer(
                                context),
                            child: const Text(
                                "Be the first to post ›",
                                style: TextStyle(color: kGold)),
                          ),
                        ]),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Container(
                      height: 0.5,
                      color: Colors.white.withOpacity(0.06)),
                  itemBuilder: (_, i) =>
                      _FirestorePostCard(doc: docs[i]),
                );
              },
            ),
          ),
        ]),
      ),
      floatingActionButton: _GlowFab(
        onPressed: () => _openPostComposer(context),
      ),
    );
  }

  void _openPostComposer(BuildContext ctx) {
    Navigator.push(ctx,
        MaterialPageRoute(builder: (_) => const PostComposerPage()));
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: Icon(icon, color: Colors.white54, size: 18),
        ),
      );
}

// Glowing FAB
class _GlowFab extends StatefulWidget {
  final VoidCallback onPressed;
  const _GlowFab({required this.onPressed});
  @override
  State<_GlowFab> createState() => _GlowFabState();
}

class _GlowFabState extends State<_GlowFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _glow;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, __) => GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [kGold, kGoldLight]),
            boxShadow: [
              BoxShadow(
                  color: kGold
                      .withOpacity(0.35 + _glow.value * 0.25),
                  blurRadius: 20 + _glow.value * 14,
                  spreadRadius: 1),
            ],
          ),
          child: const Icon(Icons.edit_outlined,
              color: kNight, size: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  FIRESTORE POST CARD
// ─────────────────────────────────────────────
class _FirestorePostCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _FirestorePostCard({required this.doc});
  @override
  State<_FirestorePostCard> createState() => _FirestorePostCardState();
}

class _FirestorePostCardState extends State<_FirestorePostCard>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  static const _catColors = {
    "Originals":  kCatOC,
    "Plotcraft":  kCatPlot,
    "Artboard":   kCatArt,
    "Chaosboard": kCatMemes,
  };

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _heartScale = Tween<double>(begin: 1.0, end: 1.5)
        .animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut));
    final likes =
        List<String>.from(widget.doc["likes"] ?? []);
    _liked =
        likes.contains(FirebaseAuth.instance.currentUser?.uid);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _liked = !_liked);
    if (_liked) {
      _heartCtrl.forward().then((_) => _heartCtrl.reverse());
    }
    final ref = FirebaseFirestore.instance
        .collection("posts")
        .doc(widget.doc.id);
    if (_liked) {
      await ref.update({
        "likes": FieldValue.arrayUnion([uid])
      });
    } else {
      await ref.update({
        "likes": FieldValue.arrayRemove([uid])
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d        = widget.doc.data();
    final body     = d["body"]     as String? ?? "";
    final username = d["username"] as String? ?? "rebel";
    final avatar   = d["avatar"]   as String? ?? "🌙";
    final category = d["category"] as String? ?? "Lore";
    final photoUrl = d["authorPhotoUrl"] as String?;
    final likes    = List<String>.from(d["likes"] ?? []);
    final comments = d["commentCount"] as int? ?? 0;
    final hashtags = List<String>.from(d["hashtags"] ?? []);
    final catColor = _catColors[category] ?? kGold;
    final ts       = d["createdAt"] as Timestamp?;
    final timeStr  = ts != null ? _timeAgo(ts.toDate()) : "now";
    final imageUrl = d["imageUrl"] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar
        GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => UserProfilePage(
                      userId: d["authorId"] ?? ""))),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                kRebel.withOpacity(0.6),
                kGold.withOpacity(0.6)
              ]),
            ),
            child: photoUrl != null
                ? ClipOval(
                    child: Image.network(photoUrl,
                        fit: BoxFit.cover))
                : Center(
                    child: Text(avatar,
                        style: const TextStyle(fontSize: 18))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => UserProfilePage(
                                userId: d["authorId"] ?? ""))),
                    child: Text("@$username",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                  const Spacer(),
                  Text(timeStr,
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11)),
                ]),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: catColor.withOpacity(0.3)),
                  ),
                  child: Text(category,
                      style: TextStyle(
                          color: catColor,
                          fontSize: 10,
                          letterSpacing: 1)),
                ),
                const SizedBox(height: 8),
                _RichPostBody(body: body),
                if (imageUrl != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200),
                  ),
                ],
                if (hashtags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: hashtags
                        .map((h) => GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          HashtagPage(tag: h))),
                              child: Text("#$h",
                                  style: const TextStyle(
                                      color: kRebelLight,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                // Action row
                Row(children: [
                  _postAction(
                      Icons.chat_bubble_outline,
                      "$comments",
                      Colors.white38,
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CommentsPage(
                                  postId: widget.doc.id)))),
                  const SizedBox(width: 22),
                  _postAction(Icons.repeat, "", Colors.white38, () {}),
                  const SizedBox(width: 22),
                  GestureDetector(
                    onTap: _toggleLike,
                    child: ScaleTransition(
                      scale: _heartScale,
                      child: Row(children: [
                        Icon(
                          _liked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _liked
                              ? kCatMischief
                              : Colors.white38,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text("${likes.length}",
                            style: TextStyle(
                                color: _liked
                                    ? kCatMischief
                                    : Colors.white38,
                                fontSize: 12)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  _postAction(Icons.share_outlined, "",
                      Colors.white38, () {}),
                ]),
              ]),
        ),
      ]),
    );
  }

  Widget _postAction(IconData icon, String label, Color color,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(color: color, fontSize: 12)),
          ],
        ]),
      );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return "${diff.inSeconds}s";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }
}

// ─────────────────────────────────────────────
//  RICH POST BODY
// ─────────────────────────────────────────────
class _RichPostBody extends StatelessWidget {
  final String body;
  const _RichPostBody({required this.body});

  @override
  Widget build(BuildContext context) {
    final spans   = <InlineSpan>[];
    final regex   = RegExp(r'(#\w+|@\w+)');
    int last = 0;
    for (final m in regex.allMatches(body)) {
      if (m.start > last) {
        spans.add(TextSpan(
            text: body.substring(last, m.start),
            style: const TextStyle(
                color: Color(0xDDFFFFFF),
                fontSize: 14,
                height: 1.55)));
      }
      final word  = m.group(0)!;
      final isTag = word.startsWith("#");
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () {
            if (isTag) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HashtagPage(
                          tag: word.substring(1))));
            }
          },
          child: Text(word,
              style: TextStyle(
                  color: isTag ? kRebelLight : kGoldLight,
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w600)),
        ),
      ));
      last = m.end;
    }
    if (last < body.length) {
      spans.add(TextSpan(
          text: body.substring(last),
          style: const TextStyle(
              color: Color(0xDDFFFFFF), fontSize: 14, height: 1.55)));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

// ─────────────────────────────────────────────
//  POST COMPOSER
// ─────────────────────────────────────────────
class PostComposerPage extends StatefulWidget {
  const PostComposerPage({super.key});
  @override
  State<PostComposerPage> createState() => _PostComposerPageState();
}

class _PostComposerPageState extends State<PostComposerPage> {
  final _ctrl    = TextEditingController();
  String _category = "Originals";
  File?  _image;
  bool   _posting  = false;

  static const _categories = ["Originals", "Plotcraft", "Artboard", "Chaosboard"];
  static const _catColors = {
    "Originals":  kCatOC,
    "Plotcraft":  kCatPlot,
    "Artboard":   kCatArt,
    "Chaosboard": kCatMemes,
  };

  List<String> get _extractedHashtags {
    final regex = RegExp(r'#(\w+)');
    return regex
        .allMatches(_ctrl.text)
        .map((m) => m.group(1)!)
        .toList();
  }

  Future<void> _post() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? imgUrl;
      // Only attempt upload if image picked AND Firebase Storage is available
      if (_image != null) {
        imgUrl = await uploadImage(_image!,
            "posts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg");
      }
      await FirebaseFirestore.instance.collection("posts").add({
        "body":           body,
        "authorId":       user.uid,
        "username":       user.displayName ?? "rebel",
        "authorPhotoUrl": user.photoURL,
        "avatar":         "🌙",
        "category":       _category,
        "hashtags":       _extractedHashtags,
        "likes":          [],
        "commentCount":   0,
        "imageUrl":       imgUrl,
        "createdAt":      FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Post error: $e");
    }
    setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: kNight,
      appBar: AppBar(
        backgroundColor: kDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("New Post",
            style: TextStyle(
                color: kGoldLight,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _posting ? null : _post,
              style: TextButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: kNight,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: _posting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: kNight, strokeWidth: 2))
                  : const Text("Post",
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D0820), kNight],
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          kRebel.withOpacity(0.6),
                          kGold.withOpacity(0.6)
                        ]),
                      ),
                      child: user?.photoURL != null
                          ? ClipOval(
                              child: Image.network(user!.photoURL!,
                                  fit: BoxFit.cover))
                          : const Center(
                              child: Text("🌙",
                                  style: TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(width: 12),
                    Text("@${user?.displayName ?? 'rebel'}",
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ctrl,
                    maxLines: null,
                    maxLength: 500,
                    autofocus: true,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, height: 1.6),
                    decoration: InputDecoration(
                      hintText:
                          "What mischief are you up to? Use #hashtags and @mentions...",
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.25),
                          fontSize: 15),
                      border: InputBorder.none,
                      counterStyle: const TextStyle(color: Colors.white24),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_extractedHashtags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: _extractedHashtags
                          .map((h) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: kRebel.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: kRebel.withOpacity(0.3)),
                                ),
                                child: Text("#$h",
                                    style: const TextStyle(
                                        color: kRebelLight, fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  if (_image != null) ...[
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_image!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 200),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _image = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],
                  const Text("Category",
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _categories.map((c) {
                      final color = _catColors[c] ?? kGold;
                      final active = _category == c;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _category = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: active
                                ? color.withOpacity(0.18)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: active
                                    ? color
                                    : Colors.white12),
                          ),
                          child: Text(c,
                              style: TextStyle(
                                  color: active
                                      ? color
                                      : Colors.white38,
                                  fontSize: 13,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                ]),
          ),
        ),
        // Bottom action bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: BoxDecoration(
              color: kDeep,
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(children: [
              _composerAction(Icons.image_outlined, "Photo", () async {
                final f = await pickImage();
                if (f != null) setState(() => _image = f);
              }),
              const SizedBox(width: 16),
              _composerAction(Icons.camera_alt_outlined, "Camera",
                  () async {
                final f = await pickImage(gallery: false);
                if (f != null) setState(() => _image = f);
              }),
              const SizedBox(width: 16),
              _composerAction(Icons.tag, "Hashtag", () {
                _ctrl.text += " #";
                _ctrl.selection = TextSelection.collapsed(
                    offset: _ctrl.text.length);
              }),
              const SizedBox(width: 16),
              _composerAction(Icons.alternate_email, "Mention", () {
                _ctrl.text += " @";
                _ctrl.selection = TextSelection.collapsed(
                    offset: _ctrl.text.length);
              }),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _composerAction(
          IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: kRebelLight, size: 18),
          const SizedBox(width: 4),
          Text(label,
              style:
                  const TextStyle(color: kRebelLight, fontSize: 12)),
        ]),
      );
}

// ─────────────────────────────────────────────
//  HASHTAG PAGE
// ─────────────────────────────────────────────
class HashtagPage extends StatelessWidget {
  final String tag;
  const HashtagPage({required this.tag, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      appBar: AppBar(
        backgroundColor: kDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 16, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("#$tag",
            style: const TextStyle(
                color: kRebelLight, fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("posts")
            .where("hashtags", arrayContains: tag)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text("No posts with this hashtag yet.",
                  style: TextStyle(color: Colors.white38)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => Container(
                height: 0.5,
                color: Colors.white.withOpacity(0.06)),
            itemBuilder: (_, i) =>
                _FirestorePostCard(doc: docs[i]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  COMMENTS PAGE
// ─────────────────────────────────────────────
class CommentsPage extends StatefulWidget {
  final String postId;
  const CommentsPage({required this.postId, super.key});
  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final _ctrl = TextEditingController();

  Future<void> _sendComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user  = FirebaseAuth.instance.currentUser!;
    final batch = FirebaseFirestore.instance.batch();
    final ref   = FirebaseFirestore.instance
        .collection("posts")
        .doc(widget.postId)
        .collection("comments")
        .doc();
    batch.set(ref, {
      "text":      text,
      "authorId":  user.uid,
      "username":  user.displayName ?? "rebel",
      "photoUrl":  user.photoURL,
      "createdAt": FieldValue.serverTimestamp(),
    });
    batch.update(
      FirebaseFirestore.instance
          .collection("posts")
          .doc(widget.postId),
      {"commentCount": FieldValue.increment(1)},
    );
    await batch.commit();
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      appBar: AppBar(
        backgroundColor: kDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 16, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Comments",
            style: TextStyle(
                color: kGoldLight, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection("posts")
                .doc(widget.postId)
                .collection("comments")
                .orderBy("createdAt")
                .snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                kRebel.withOpacity(0.5),
                                kGold.withOpacity(0.5),
                              ]),
                            ),
                            child: d["photoUrl"] != null
                                ? ClipOval(
                                    child: Image.network(
                                        d["photoUrl"],
                                        fit: BoxFit.cover))
                                : const Center(
                                    child: Text("🌙",
                                        style: TextStyle(
                                            fontSize: 14))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "@${d['username'] ?? 'rebel'}",
                                      style: const TextStyle(
                                          color: kGoldLight,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  const SizedBox(height: 2),
                                  _RichPostBody(
                                      body: d["text"] ?? ""),
                                ]),
                          ),
                        ]),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          decoration: BoxDecoration(
            color: kDeep,
            border: Border(
                top: BorderSide(
                    color: Colors.white.withOpacity(0.06))),
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Reply with mischief...",
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                            color: kRebel.withOpacity(0.2))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            const BorderSide(color: kRebel)),
                  ),
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendComment,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [kGold, kGoldLight]),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: kNight, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
//  SEARCH PAGE
// ─────────────────────────────────────────────
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  String _query = "";
  String _tab   = "Posts";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      appBar: AppBar(
        backgroundColor: kDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 16, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Search posts, hashtags, people...",
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3)),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: Row(
            children: ["Posts", "Hashtags", "People"].map((t) =>
              GestureDetector(
                onTap: () => setState(() => _tab = t),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: _tab == t
                        ? kGold.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _tab == t
                            ? kGold
                            : Colors.white12),
                  ),
                  child: Text(t,
                      style: TextStyle(
                          color: _tab == t
                              ? kGoldLight
                              : Colors.white38,
                          fontSize: 13)),
                ),
              )).toList(),
          ),
        ),
        Container(height: 0.5, color: Colors.white12),
        Expanded(
          child: _query.isEmpty
              ? const Center(
                  child: Text(
                      "Start typing to search the realm...",
                      style: TextStyle(color: Colors.white24)))
              : _tab == "Hashtags"
                  ? _HashtagResults(query: _query)
                  : _tab == "People"
                      ? _PeopleResults(query: _query)
                      : _PostResults(query: _query),
        ),
      ]),
    );
  }
}

class _PostResults extends StatelessWidget {
  final String query;
  const _PostResults({required this.query});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("posts")
          .where("hashtags",
              arrayContains: query.replaceAll("#", ""))
          .limit(20)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
              child: Text("No posts found.",
                  style: TextStyle(color: Colors.white38)));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => Container(
              height: 0.5,
              color: Colors.white.withOpacity(0.06)),
          itemBuilder: (_, i) => _FirestorePostCard(doc: docs[i]),
        );
      },
    );
  }
}

class _HashtagResults extends StatelessWidget {
  final String query;
  const _HashtagResults({required this.query});
  @override
  Widget build(BuildContext context) {
    final tag = query.replaceAll("#", "");
    return ListTile(
      leading: const Icon(Icons.tag, color: kRebelLight),
      title: Text("#$tag",
          style: const TextStyle(
              color: kRebelLight, fontWeight: FontWeight.w700)),
      subtitle: const Text("Tap to explore",
          style: TextStyle(color: Colors.white38, fontSize: 12)),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => HashtagPage(tag: tag))),
    );
  }
}

class _PeopleResults extends StatelessWidget {
  final String query;
  const _PeopleResults({required this.query});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .where("username",
              isGreaterThanOrEqualTo: query)
          .where("username",
              isLessThanOrEqualTo: "$query\uf8ff")
          .limit(20)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
              child: Text("No people found.",
                  style: TextStyle(color: Colors.white38)));
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data();
            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    kRebel.withOpacity(0.5),
                    kGold.withOpacity(0.5)
                  ]),
                ),
                child: d["photoUrl"] != null
                    ? ClipOval(
                        child: Image.network(d["photoUrl"],
                            fit: BoxFit.cover))
                    : const Center(
                        child: Text("🌙",
                            style: TextStyle(fontSize: 16))),
              ),
              title: Text("@${d['username'] ?? '?'}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
              subtitle: Text(d["bio"] ?? "",
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 12)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => UserProfilePage(
                          userId: docs[i].id))),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CHAT FEED PAGE  — real-time DM + Groups
// ═══════════════════════════════════════════════════════════
class ChatFeedPage extends StatefulWidget {
  const ChatFeedPage({super.key});
  @override
  State<ChatFeedPage> createState() => _ChatFeedPageState();
}

class _ChatFeedPageState extends State<ChatFeedPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid ?? "";
    return Scaffold(
      backgroundColor: kNight,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              RichText(text: const TextSpan(
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                children: [
                  TextSpan(text: "Myn", style: TextStyle(color: kGoldLight,
                    shadows: [Shadow(color: kGold, blurRadius: 20)])),
                  TextSpan(text: "X ", style: TextStyle(color: kRebelLight,
                    shadows: [Shadow(color: kRebel, blurRadius: 20)])),
                  TextSpan(text: "Chat", style: TextStyle(color: Colors.white70)),
                ],
              )),
              const Spacer(),
              // New DM button
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const NewDMPage())),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kRebel.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: kRebel.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: kRebelLight, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              // New group button
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CreateGroupPage())),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: kGold.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.group_add_outlined,
                      color: kGoldLight, size: 18),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _chatTab("Direct", 0),
              const SizedBox(width: 10),
              _chatTab("Groups", 1),
            ]),
          ),
          const SizedBox(height: 4),
          Container(
              height: 0.5,
              margin: const EdgeInsets.only(top: 8),
              color: Colors.white12),
          Expanded(
            child: _tab == 0
                ? _DMList(myUid: me)
                : _GroupList(myUid: me),
          ),
        ]),
      ),
    );
  }

  Widget _chatTab(String label, int idx) => GestureDetector(
    onTap: () => setState(() => _tab = idx),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: _tab == idx
            ? kRebel.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: _tab == idx ? kRebel : Colors.white12),
      ),
      child: Text(label,
          style: TextStyle(
              color: _tab == idx ? kRebelLight : Colors.white38,
              fontWeight: _tab == idx
                  ? FontWeight.w700
                  : FontWeight.normal,
              fontSize: 13)),
    ),
  );
}

// ── New DM: find user to message ─────────────
class NewDMPage extends StatefulWidget {
  const NewDMPage({super.key});
  @override
  State<NewDMPage> createState() => _NewDMPageState();
}

class _NewDMPageState extends State<NewDMPage> {
  final _ctrl = TextEditingController();
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid ?? "";
    return Scaffold(
      backgroundColor: kNight,
      appBar: AppBar(
        backgroundColor: kDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Search for a rebel...",
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3)),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
      ),
      body: _query.isEmpty
          ? const Center(
              child: Text("Type a username to find someone",
                  style: TextStyle(color: Colors.white38)))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .where("username",
                      isGreaterThanOrEqualTo: _query)
                  .where("username",
                      isLessThanOrEqualTo: "$_query\uf8ff")
                  .limit(20)
                  .snapshots(),
              builder: (_, snap) {
                final docs = snap.data?.docs ?? [];
                final filtered =
                    docs.where((d) => d.id != me).toList();
                if (filtered.isEmpty) {
                  return const Center(
                      child: Text("No rebels found.",
                          style: TextStyle(
                              color: Colors.white38)));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final d    = filtered[i].data();
                    final uid  = filtered[i].id;
                    final name = d["username"] as String? ?? "rebel";
                    final photo = d["photoUrl"] as String?;
                    return ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [
                            kRebel.withOpacity(0.5),
                            kGold.withOpacity(0.5)
                          ]),
                        ),
                        child: photo != null
                            ? ClipOval(
                                child: Image.network(photo,
                                    fit: BoxFit.cover))
                            : const Center(
                                child: Text("🌙",
                                    style: TextStyle(
                                        fontSize: 18))),
                      ),
                      title: Text("@$name",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(d["bio"] ?? "",
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12)),
                      onTap: () async {
                        final chatId =
                            await _getOrCreateDM(me, uid, name, photo);
                        if (!context.mounted) return;
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ChatRoomPage(
                                    chatId: chatId,
                                    isGroup: false,
                                    title: "@$name",
                                    bgImageUrl: "",
                                    otherUserId: uid)));
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  /// Creates or retrieves an existing DM thread between two users
  Future<String> _getOrCreateDM(
      String myUid, String otherUid, String otherName, String? otherPhoto) async {
    final me   = FirebaseAuth.instance.currentUser!;
    final myName = me.displayName ?? "rebel";

    // Check existing DM
    final existing = await FirebaseFirestore.instance
        .collection("dms")
        .where("members", arrayContains: myUid)
        .get();
    for (final doc in existing.docs) {
      final members = List<String>.from(doc["members"] ?? []);
      if (members.contains(otherUid)) return doc.id;
    }
    // Create new DM
    final ref =
        await FirebaseFirestore.instance.collection("dms").add({
      "members":      [myUid, otherUid],
      "memberNames":  {myUid: myName, otherUid: otherName},
      "memberPhotos": {
        myUid:    me.photoURL ?? "",
        otherUid: otherPhoto ?? "",
      },
      "lastMessage":  "",
      "lastAt":       FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
}

// ── DM List ───────────────────────────────────
class _DMList extends StatelessWidget {
  final String myUid;
  const _DMList({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("dms")
          .where("members", arrayContains: myUid)
          .orderBy("lastAt", descending: true)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("💬", style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              const Text("No direct messages yet.",
                  style: TextStyle(color: Colors.white38)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const NewDMPage())),
                child: const Text("Start a conversation ›",
                    style: TextStyle(color: kGold)),
              ),
            ]),
          );
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => Container(
              height: 0.5,
              margin: const EdgeInsets.only(left: 74),
              color: Colors.white.withOpacity(0.06)),
          itemBuilder: (_, i) =>
              _DMTile(doc: docs[i], myUid: myUid),
        );
      },
    );
  }
}

class _DMTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String myUid;
  const _DMTile({required this.doc, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final d       = doc.data();
    final members = List<String>.from(d["members"] ?? []);
    final otherId =
        members.firstWhere((m) => m != myUid, orElse: () => myUid);
    final names  = Map<String, dynamic>.from(d["memberNames"] ?? {});
    final photos = Map<String, dynamic>.from(d["memberPhotos"] ?? {});
    final name   = names[otherId] ?? "rebel";
    final photo  = photos[otherId] as String?;
    final last   = d["lastMessage"] as String? ?? "";
    final unread = (d["unread_$myUid"] as int?) ?? 0;
    final bgUrl  = d["bgImageUrl"] as String?;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatRoomPage(
                  chatId: doc.id,
                  isGroup: false,
                  title: "@$name",
                  bgImageUrl: bgUrl ?? "",
                  otherUserId: otherId))),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  kRebel.withOpacity(0.5),
                  kGold.withOpacity(0.5)
                ]),
              ),
              child: (photo != null && photo.isNotEmpty)
                  ? ClipOval(
                      child: Image.network(photo, fit: BoxFit.cover))
                  : const Center(
                      child: Text("🌙",
                          style: TextStyle(fontSize: 22))),
            ),
            if (unread > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: kGold),
                  child: Center(
                    child: Text("$unread",
                        style: const TextStyle(
                            color: kNight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("@$name",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: unread > 0
                              ? Colors.white60
                              : Colors.white30,
                          fontSize: 13)),
                ]),
          ),
        ]),
      ),
    );
  }
}

// ── Group List ────────────────────────────────
class _GroupList extends StatelessWidget {
  final String myUid;
  const _GroupList({required this.myUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("groups")
          .where("members", arrayContains: myUid)
          .orderBy("lastAt", descending: true)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text("👥", style: TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              const Text("No group chats yet.",
                  style: TextStyle(color: Colors.white38)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const CreateGroupPage())),
                child: const Text("Create a group ›",
                    style: TextStyle(color: kGold)),
              ),
            ]),
          );
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => Container(
              height: 0.5,
              margin: const EdgeInsets.only(left: 74),
              color: Colors.white.withOpacity(0.06)),
          itemBuilder: (_, i) =>
              _GroupTile(doc: docs[i], myUid: myUid),
        );
      },
    );
  }
}

class _GroupTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String myUid;
  const _GroupTile({required this.doc, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final d      = doc.data();
    final name   = d["name"]     as String? ?? "Group";
    final photo  = d["photoUrl"] as String?;
    final bgUrl  = d["bgImageUrl"] as String?;
    final last   = d["lastMessage"] as String? ?? "";
    final unread = (d["unread_$myUid"] as int?) ?? 0;
    final count  = (List<String>.from(d["members"] ?? [])).length;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatRoomPage(
                  chatId: doc.id,
                  isGroup: true,
                  title: name,
                  bgImageUrl: bgUrl ?? "",
                  otherUserId: ""))),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(children: [
          Stack(children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [kRebel, Color(0xFF6D28D9)]),
              ),
              child: (photo != null && photo.isNotEmpty)
                  ? ClipOval(
                      child: Image.network(photo, fit: BoxFit.cover))
                  : const Center(
                      child: Text("👥",
                          style: TextStyle(fontSize: 20))),
            ),
            if (unread > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: kGold),
                  child: Center(
                    child: Text("$unread",
                        style: const TextStyle(
                            color: kNight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(name,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: unread > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14)),
                    const SizedBox(width: 6),
                    Text("$count members",
                        style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 11)),
                  ]),
                  const SizedBox(height: 3),
                  Text(last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: unread > 0
                              ? Colors.white60
                              : Colors.white30,
                          fontSize: 13)),
                ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CHAT ROOM  — real-time messages
// ─────────────────────────────────────────────
class ChatRoomPage extends StatefulWidget {
  final String chatId, title, otherUserId, bgImageUrl;
  final bool isGroup;
  const ChatRoomPage({
    required this.chatId,
    required this.isGroup,
    required this.title,
    required this.otherUserId,
    this.bgImageUrl = "",
    super.key,
  });
  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();
  String? _bgUrl;

  String get _collection => widget.isGroup ? "groups" : "dms";

  @override
  void initState() {
    super.initState();
    _bgUrl =
        widget.bgImageUrl.isNotEmpty ? widget.bgImageUrl : null;
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser!;
    _ctrl.clear();
    final msgRef = FirebaseFirestore.instance
        .collection(_collection)
        .doc(widget.chatId)
        .collection("messages")
        .doc();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(msgRef, {
      "text":        text,
      "senderId":    user.uid,
      "senderName":  user.displayName ?? "rebel",
      "senderPhoto": user.photoURL,
      "createdAt":   FieldValue.serverTimestamp(),
    });
    batch.update(
      FirebaseFirestore.instance
          .collection(_collection)
          .doc(widget.chatId),
      {"lastMessage": text, "lastAt": FieldValue.serverTimestamp()},
    );
    await batch.commit();
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut);
    }
  }

  Future<void> _changeBg() async {
    final f = await pickImage();
    if (f == null) return;
    final url = await uploadImage(f,
        "$_collection/${widget.chatId}/bg_${DateTime.now().millisecondsSinceEpoch}.jpg");
    if (url == null) return;
    await FirebaseFirestore.instance
        .collection(_collection)
        .doc(widget.chatId)
        .update({"bgImageUrl": url});
    setState(() => _bgUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid ?? "";
    return Scaffold(
      backgroundColor: kNight,
      appBar: AppBar(
        backgroundColor: kDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 16, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.wallpaper, color: Colors.white38),
            tooltip: "Change background",
            onPressed: _changeBg,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white38),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(children: [
        if (_bgUrl != null)
          Positioned.fill(
            child: Stack(children: [
              Image.network(_bgUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity),
              Container(color: Colors.black.withOpacity(0.6)),
            ]),
          )
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0515),
                  kNight,
                  Color(0xFF050308)
                ],
              ),
            ),
          ),
        Column(children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection(_collection)
                  .doc(widget.chatId)
                  .collection("messages")
                  .orderBy("createdAt")
                  .snapshots(),
              builder: (_, snap) {
                final docs = snap.data?.docs ?? [];
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d    = docs[i].data();
                    final isMe = d["senderId"] == me;
                    return _MsgBubble(
                      text:        d["text"] ?? "",
                      isMe:        isMe,
                      senderName:  d["senderName"] ?? "",
                      senderPhoto: d["senderPhoto"],
                      showName:    widget.isGroup && !isMe,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color:
                  kDeep.withOpacity(_bgUrl != null ? 0.85 : 1.0),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withOpacity(0.06))),
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Say something mischievous...",
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                              color: kRebel.withOpacity(0.2))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: kRebel)),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [kGold, kGoldLight]),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: kNight, size: 18),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _MsgBubble extends StatelessWidget {
  final String text, senderName;
  final String? senderPhoto;
  final bool isMe, showName;
  const _MsgBubble({
    required this.text,
    required this.isMe,
    required this.senderName,
    this.senderPhoto,
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showName) ...[
            Container(
              width: 28,
              height: 28,
              margin:
                  const EdgeInsets.only(right: 6, bottom: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  kRebel.withOpacity(0.5),
                  kGold.withOpacity(0.5)
                ]),
              ),
              child: (senderPhoto != null &&
                      senderPhoto!.isNotEmpty)
                  ? ClipOval(
                      child: Image.network(senderPhoto!,
                          fit: BoxFit.cover))
                  : const Center(
                      child: Text("🌙",
                          style: TextStyle(fontSize: 10))),
            ),
          ],
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [kRebel, Color(0xFF6D28D9)])
                  : null,
              color: isMe
                  ? null
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(18),
                topRight:    const Radius.circular(18),
                bottomLeft:  Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (showName && !isMe) ...[
                  Text(senderName,
                      style: const TextStyle(
                          color: kGoldLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                ],
                Text(text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CREATE GROUP PAGE
// ─────────────────────────────────────────────
class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});
  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameCtrl = TextEditingController();
  File? _photo;
  File? _bg;
  bool  _creating = false;

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    final user = FirebaseAuth.instance.currentUser!;
    String? photoUrl, bgUrl;
    if (_photo != null) {
      photoUrl = await uploadImage(_photo!,
          "groups/photo_${DateTime.now().millisecondsSinceEpoch}.jpg");
    }
    if (_bg != null) {
      bgUrl = await uploadImage(_bg!,
          "groups/bg_${DateTime.now().millisecondsSinceEpoch}.jpg");
    }
    final ref =
        await FirebaseFirestore.instance.collection("groups").add({
      "name":         name,
      "photoUrl":     photoUrl,
      "bgImageUrl":   bgUrl,
      "members":      [user.uid],
      "memberNames":  {user.uid: user.displayName ?? "rebel"},
      "memberPhotos": {user.uid: user.photoURL ?? ""},
      "createdBy":    user.uid,
      "lastMessage":  "",
      "lastAt":       FieldValue.serverTimestamp(),
    });
    setState(() => _creating = false);
    if (mounted) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ChatRoomPage(
                  chatId: ref.id,
                  isGroup: true,
                  title: name,
                  bgImageUrl: bgUrl ?? "",
                  otherUserId: "")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      appBar: AppBar(
        backgroundColor: kDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("New Group",
            style: TextStyle(
                color: kGoldLight, fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _creating ? null : _create,
              style: TextButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: kNight,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: kNight, strokeWidth: 2))
                  : const Text("Create",
                      style:
                          TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          GestureDetector(
            onTap: () async {
              final f = await pickImage();
              if (f != null) setState(() => _photo = f);
            },
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [kRebel, Color(0xFF6D28D9)]),
              ),
              child: _photo != null
                  ? ClipOval(
                      child:
                          Image.file(_photo!, fit: BoxFit.cover))
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            color: Colors.white70, size: 24),
                        SizedBox(height: 4),
                        Text("Photo",
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 10)),
                      ]),
            ),
          ),
          const SizedBox(height: 8),
          const Text("Group profile picture",
              style:
                  TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Group name",
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: kGold.withOpacity(0.2))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kGold)),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              final f = await pickImage();
              if (f != null) setState(() => _bg = f);
            },
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.04),
                border: Border.all(
                    color: kRebel.withOpacity(0.3)),
                image: _bg != null
                    ? DecorationImage(
                        image: FileImage(_bg!),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: _bg == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wallpaper,
                            color: kRebelLight, size: 28),
                        SizedBox(height: 6),
                        Text("Set chat background",
                            style: TextStyle(
                                color: kRebelLight,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text("Optional",
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11)),
                      ])
                  : Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black38,
                      ),
                      child: const Center(
                        child: Text("Tap to change bg",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12)),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PROFILE PAGE
// ═══════════════════════════════════════════════════════════
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _uploading = false;

  Future<void> _changeAvatar() async {
    final f = await pickImage();
    if (f == null) return;
    setState(() => _uploading = true);
    final user = FirebaseAuth.instance.currentUser!;
    final url  = await uploadImage(f, "avatars/${user.uid}.jpg");
    if (url != null) {
      await user.updatePhotoURL(url);
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "photoUrl": url,
        "username": user.displayName ?? "rebel",
        "uid":      user.uid,
      }, SetOptions(merge: true));
    }
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final user        = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? "MynX Rebel";
    final email       = user?.email ?? "";
    final photoUrl    = user?.photoURL;

    return Scaffold(
      backgroundColor: kNight,
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  const Text("Profile",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showLogoutDialog(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.3)),
                        color: Colors.red.withOpacity(0.07),
                      ),
                      child: const Text("Log Out",
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              letterSpacing: 1)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              Stack(alignment: Alignment.center, children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        LinearGradient(colors: [kGold, kRebel]),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: _uploading
                      ? const CircleAvatar(
                          backgroundColor: kNight,
                          child: CircularProgressIndicator(
                              color: kGold, strokeWidth: 2))
                      : CircleAvatar(
                          backgroundColor: kNight,
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0]
                                          .toUpperCase()
                                      : "M",
                                  style: const TextStyle(
                                      color: kGoldLight,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700))
                              : null),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _changeAvatar,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kGold,
                        border: Border.all(
                            color: kNight, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: kNight, size: 14),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text(displayName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(email,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: kRebel.withOpacity(0.15),
                  border: Border.all(
                      color: kRebel.withOpacity(0.3)),
                ),
                child: const Text("Rebel · MynX",
                    style: TextStyle(
                        color: kRebelLight,
                        fontSize: 11,
                        letterSpacing: 1.5)),
              ),
              const SizedBox(height: 20),
              // Post count from Firestore
              user == null
                  ? const SizedBox()
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("posts")
                          .where("authorId",
                              isEqualTo: user.uid)
                          .snapshots(),
                      builder: (_, snap) {
                        final count =
                            snap.data?.docs.length ?? 0;
                        return Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              _statCol("Posts", "$count"),
                              _divider(),
                              _statCol("Followers", "—"),
                              _divider(),
                              _statCol("Following", "—"),
                            ]);
                      },
                    ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40),
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kGoldLight,
                    side: BorderSide(
                        color: kGold.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    minimumSize:
                        const Size(double.infinity, 0),
                  ),
                  child: const Text("Edit Profile",
                      style: TextStyle(letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 0.5, color: Colors.white12),
            ]),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: user == null
                  ? null
                  : FirebaseFirestore.instance
                      .collection("posts")
                      .where("authorId",
                          isEqualTo: user.uid)
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
              builder: (_, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                          "No posts yet. Share your mischief! 😈",
                          style: TextStyle(
                              color: Colors.white38),
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                return Column(
                    children: docs
                        .map((d) => _FirestorePostCard(doc: d))
                        .toList());
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statCol(String label, String value) =>
      Column(children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 11)),
      ]);

  Widget _divider() => Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: 0.5,
      height: 32,
      color: Colors.white.withOpacity(0.12));

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kDeep,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Leave the Realm?",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text("You sure you wanna log out?",
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: BorderSide(
                            color:
                                Colors.white.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(30)),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await FirebaseAuth.instance.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.red.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(30)),
                      ),
                      child: const Text("Log Out"),
                    ),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  USER PROFILE PAGE
// ─────────────────────────────────────────────
class UserProfilePage extends StatelessWidget {
  final String userId;
  const UserProfilePage({required this.userId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .get(),
        builder: (_, snap) {
          final d        = snap.data?.data() ?? {};
          final username = d["username"] as String? ?? "rebel";
          final photo    = d["photoUrl"]  as String?;
          final bio      = d["bio"]       as String? ?? "";
          return SafeArea(
            child: CustomScrollView(slivers: [
              SliverAppBar(
                backgroundColor: kDeep,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios,
                      size: 16, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text("@$username",
                    style: const TextStyle(
                        color: kGoldLight,
                        fontWeight: FontWeight.w700)),
                actions: [
                  // DM button
                  if (userId !=
                      FirebaseAuth.instance.currentUser?.uid)
                    IconButton(
                      icon: const Icon(Icons.send_outlined,
                          color: kGoldLight, size: 20),
                      onPressed: () async {
                        final me = FirebaseAuth
                            .instance.currentUser!;
                        final myUid = me.uid;
                        // Find or create DM
                        final existing =
                            await FirebaseFirestore.instance
                                .collection("dms")
                                .where("members",
                                    arrayContains: myUid)
                                .get();
                        String? chatId;
                        for (final doc in existing.docs) {
                          final members =
                              List<String>.from(
                                  doc["members"] ?? []);
                          if (members.contains(userId)) {
                            chatId = doc.id;
                            break;
                          }
                        }
                        if (chatId == null) {
                          final ref = await FirebaseFirestore
                              .instance
                              .collection("dms")
                              .add({
                            "members": [myUid, userId],
                            "memberNames": {
                              myUid: me.displayName ?? "rebel",
                              userId: username,
                            },
                            "memberPhotos": {
                              myUid:  me.photoURL ?? "",
                              userId: photo ?? "",
                            },
                            "lastMessage": "",
                            "lastAt":
                                FieldValue.serverTimestamp(),
                          });
                          chatId = ref.id;
                        }
                        if (!context.mounted) return;
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ChatRoomPage(
                                    chatId: chatId!,
                                    isGroup: false,
                                    title: "@$username",
                                    bgImageUrl: "",
                                    otherUserId: userId)));
                      },
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Column(children: [
                  const SizedBox(height: 20),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [kGold, kRebel]),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      backgroundColor: kNight,
                      backgroundImage: photo != null
                          ? NetworkImage(photo)
                          : null,
                      child: photo == null
                          ? Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                  color: kGoldLight,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text("@$username",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40),
                      child: Text(bio,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                      height: 0.5, color: Colors.white12),
                ]),
              ),
              SliverToBoxAdapter(
                child: StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection("posts")
                      .where("authorId", isEqualTo: userId)
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (_, s) {
                    final docs = s.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text("No posts yet.",
                              style: TextStyle(
                                  color: Colors.white38)),
                        ),
                      );
                    }
                    return Column(
                        children: docs
                            .map((d) =>
                                _FirestorePostCard(doc: d))
                            .toList());
                  },
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  PROFILE SETUP SCREEN
// ═══════════════════════════════════════════════════════════
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameCtrl = TextEditingController();
  final _ageCtrl      = TextEditingController();
  final _bioCtrl      = TextEditingController();
  String _gender      = "Male";
  File?  _avatar;
  bool   _saving      = false;

  Future<void> _continue() async {
    final username = _usernameCtrl.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter a username 🌙")));
      return;
    }
    final age = int.tryParse(_ageCtrl.text.trim());
    if (age == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter a valid age 😭")));
      return;
    }
    if (age < 13) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: kDeep,
          title: const Text("Access Denied 😔",
              style: TextStyle(color: kGoldLight)),
          content: Text(
            "You are $age years old.\n\nYou must be at least 13 to use this app.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("OK", style: TextStyle(color: kGold)),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser!;
    String? photoUrl;
    if (_avatar != null) {
      photoUrl = await uploadImage(
          _avatar!, "avatars/${user.uid}.jpg");
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);
    }
    await user.updateDisplayName(username);
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .set({
      "uid":       user.uid,
      "username":  username,
      "bio":       _bioCtrl.text.trim(),
      "gender":    _gender,
      "age":       age,
      "photoUrl":  photoUrl ?? user.photoURL ?? "",
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    setState(() => _saving = false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      body: Stack(children: [
        const ParticleBackground(),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: kGold.withOpacity(0.25)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x33C9A84C), blurRadius: 30)
                ],
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Complete Profile",
                        style: TextStyle(
                            fontSize: 22,
                            color: kGoldLight,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Set up your realm identity",
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            letterSpacing: 1)),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        final f = await pickImage();
                        if (f != null)
                          setState(() => _avatar = f);
                      },
                      child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                    colors: [kGold, kRebel]),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: CircleAvatar(
                                backgroundColor: kDeep,
                                backgroundImage: _avatar != null
                                    ? FileImage(_avatar!)
                                    : null,
                                child: _avatar == null
                                    ? const Icon(Icons.person,
                                        color: Colors.white38,
                                        size: 36)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: kGold,
                                  border: Border.all(
                                      color: kNight, width: 2),
                                ),
                                child: const Icon(
                                    Icons.camera_alt,
                                    color: kNight,
                                    size: 13),
                              ),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 8),
                    const Text("Tap to add profile photo",
                        style: TextStyle(
                            color: Colors.white24,
                            fontSize: 11)),
                    const SizedBox(height: 22),
                    _field(_usernameCtrl, "Username", false),
                    const SizedBox(height: 12),
                    _field(_bioCtrl, "Bio (optional)", false),
                    const SizedBox(height: 12),
                    _field(_ageCtrl, "Age", false,
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      dropdownColor: kDeep,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: kGold.withOpacity(0.2))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: kGold)),
                      ),
                      items: [
                        "Male",
                        "Female",
                        "Non-binary",
                        "Prefer not to say",
                        "Other"
                      ]
                          .map((g) => DropdownMenuItem(
                              value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _gender = v!),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(30)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2))
                            : const Text("Enter the Realm",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    bool obscure, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: kGold.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kGold)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  LORE INTRO SCREEN — 4 animated scenes then login
// ═══════════════════════════════════════════════════════════
class LoreIntroScreen extends StatefulWidget {
  const LoreIntroScreen({super.key});

  @override
  State<LoreIntroScreen> createState() => _LoreIntroScreenState();
}

class _LoreIntroScreenState extends State<LoreIntroScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalScenes = 4;
  late AnimationController _autoController;

  @override
  void initState() {
    super.initState();
    _autoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (_currentPage < _totalScenes - 1) {
            _nextScene();
            _autoController.reset();
            _autoController.forward();
          }
        }
      });
    _autoController.forward();
  }

  @override
  void dispose() {
    _autoController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextScene() {
    if (_currentPage < _totalScenes - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToLogin() {
    _autoController.stop();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MynxHome(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      body: Stack(
        children: [
          // Particle bg only shown on scenes 2/3 (kingdom has its own image)
          if (_currentPage > 0) const ParticleBackground(),

          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              // ── SCENE 1: Kingdom bg image ──
              _LoreSceneKingdom(
                chapterLabel: "Chapter I",
                title: "The Golden\nKingdom",
                body: "Once, a just wizard ruled the realm\nwith wisdom and grace —\nand all was well.",
              ),
              // ── SCENE 2: Shadow Falls ──
              _LoreScene(
                chapterLabel: "Chapter II",
                title: "Shadow\nFalls",
                body: "But wicked officials seized power —\ncrushing the people beneath\niron chains and silence.",
                titleColor: const Color(0xFFEF4444),
                titleShadowColor: const Color(0xAAEF4444),
                bodyColor: const Color(0xCCFFC8C8),
                bgColors: const [Color(0xFF1A0505), kNight],
                dividerColor: const Color(0xFFEF4444),
              ),
              // ── SCENE 3: Rebellion ──
              _LoreSceneWithMoon(
                chapterLabel: "Chapter III",
                title: "The\nRebellion",
                body: "So a few brave souls chose mischief\nover silence — and became something\nthe kingdom feared.",
                titleColor: kRebelLight,
                titleShadowColor: kRebel,
                bodyColor: const Color(0xCCC8C0FF),
                bgColors: const [Color(0xFF0D0520), kNight],
                dividerColor: kRebelLight,
              ),
              // ── SCENE 4: Final logo ──
              _LoreSceneFinal(onEnter: _goToLogin),
            ],
          ),

          // Skip button
          if (_currentPage < _totalScenes - 1)
            Positioned(
              top: 52, right: 20,
              child: GestureDetector(
                onTap: () {
                  _autoController.stop();
                  _pageController.animateToPage(
                    _totalScenes - 1,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                  );
                },
                child: _outlineChip("Skip ›"),
              ),
            ),

          // Dot indicators
          if (_currentPage < _totalScenes - 1)
            Positioned(
              bottom: 38, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalScenes, (i) {
                  final active = i == _currentPage;
                  return GestureDetector(
                    onTap: () {
                      _autoController.stop();
                      _pageController.animateToPage(i,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? kGold : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // Next button
          if (_currentPage < _totalScenes - 1)
            Positioned(
              bottom: 26, right: 20,
              child: GestureDetector(
                onTap: () {
                  _autoController.stop();
                  _nextScene();
                },
                child: _outlineChip("Next ›"),
              ),
            ),
        ],
      ),
    );
  }

  Widget _outlineChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: kRebelLight.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: kRebelLight, fontSize: 12, letterSpacing: 2)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  LORE SCENE KINGDOM — Chapter I with image background
// ═══════════════════════════════════════════════════════════
class _LoreSceneKingdom extends StatefulWidget {
  final String chapterLabel, title, body;

  const _LoreSceneKingdom({
    required this.chapterLabel,
    required this.title,
    required this.body,
  });

  @override
  State<_LoreSceneKingdom> createState() => _LoreSceneKingdomState();
}

class _LoreSceneKingdomState extends State<_LoreSceneKingdom>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _parallax;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    // image drifts upward slightly as it enters — cinematic parallax
    _parallax = Tween<double>(begin: 18.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: kingdom artwork with parallax zoom-in ──
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _parallax.value),
            child: Transform.scale(
              // slight zoom-out as it enters, lands at 1.0
              scale: 1.0 + (_parallax.value * 0.003),
              child: Image.asset(
                'assets/images/kingdom_bg.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),

        // ── Layer 2: dark radial overlay — center is clearer, edges dark ──
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0.1),
              radius: 1.1,
              colors: [
                Color(0x44000000), // very light center tint
                Color(0xCC050508), // heavy dark at edges
              ],
            ),
          ),
        ),

        // ── Layer 3: bottom fog — blends image into night ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 260,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xFF050508),
                  Color(0xBB050508),
                  Color(0x55050508),
                  Colors.transparent,
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
        ),

        // ── Layer 4: top vignette ──
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC050508),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // ── Layer 5: warm golden tint over the image (matches kGold palette) ──
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 1.3,
              colors: [
                kGold.withOpacity(0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),

        // ── Layer 6: animated firefly / dust specks ──
        const _FireflyOverlay(),

        // ── Layer 7: text content ──
        FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SceneLabel(widget.chapterLabel),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kGoldLight,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                        shadows: [
                          Shadow(color: kGold, blurRadius: 40),
                          Shadow(color: kGold, blurRadius: 80),
                        ],
                      ),
                    ),
                    const _GoldDivider(color: kGold),
                    Text(
                      widget.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Color(0xCCFFF0C8),
                        fontSize: 16,
                        height: 1.8,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 16),
                          Shadow(color: Colors.black, blurRadius: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  FIREFLY OVERLAY — animated gold light specks
//  mimics the glowing orbs already in the artwork
// ─────────────────────────────────────────────
class _FireflyOverlay extends StatefulWidget {
  const _FireflyOverlay();

  @override
  State<_FireflyOverlay> createState() => _FireflyOverlayState();
}

class _FireflyOverlayState extends State<_FireflyOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _FireflyPainter(_ctrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _FireflyPainter extends CustomPainter {
  final double progress;
  final Random _rng = Random(7); // fixed seed = stable positions

  _FireflyPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 32; i++) {
      final baseX = _rng.nextDouble() * size.width;
      final baseY = _rng.nextDouble() * size.height;

      // gentle upward drift + horizontal sway
      final drift = (progress * size.height * 0.20 + i * 45) % size.height;
      final sway = sin(progress * pi * 2 + i * 1.3) * 20;
      final x = (baseX + sway).clamp(0.0, size.width);
      final y = (baseY - drift + size.height) % size.height;

      // pulse brightness in and out
      final pulse = 0.3 + 0.7 * sin(progress * pi * 2 * 1.8 + i * 0.9).abs();
      final radius = (0.6 + _rng.nextDouble() * 2.0) * pulse;

      // soft outer halo
      canvas.drawCircle(
        Offset(x, y),
        radius * 5,
        Paint()
          ..color = kGold.withOpacity(0.05 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // bright core dot
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = kGoldLight.withOpacity(0.6 * pulse),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────
//  LORE SCENE — chapters 2 (Shadow Falls)
// ─────────────────────────────────────────────
class _LoreScene extends StatefulWidget {
  final String chapterLabel, title, body;
  final Color titleColor, titleShadowColor, bodyColor, dividerColor;
  final List<Color> bgColors;

  const _LoreScene({
    required this.chapterLabel,
    required this.title,
    required this.body,
    required this.titleColor,
    required this.titleShadowColor,
    required this.bodyColor,
    required this.bgColors,
    required this.dividerColor,
  });

  @override
  State<_LoreScene> createState() => _LoreSceneState();
}

class _LoreSceneState extends State<_LoreScene>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.2,
          colors: widget.bgColors,
        ),
      ),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SceneLabel(widget.chapterLabel),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.titleColor,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      shadows: [Shadow(color: widget.titleShadowColor, blurRadius: 40)],
                    ),
                  ),
                  _GoldDivider(color: widget.dividerColor),
                  Text(
                    widget.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: widget.bodyColor,
                      fontSize: 16,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LORE SCENE WITH MOON — chapter 3
// ─────────────────────────────────────────────
class _LoreSceneWithMoon extends StatefulWidget {
  final String chapterLabel, title, body;
  final Color titleColor, titleShadowColor, bodyColor, dividerColor;
  final List<Color> bgColors;

  const _LoreSceneWithMoon({
    required this.chapterLabel,
    required this.title,
    required this.body,
    required this.titleColor,
    required this.titleShadowColor,
    required this.bodyColor,
    required this.bgColors,
    required this.dividerColor,
  });

  @override
  State<_LoreSceneWithMoon> createState() => _LoreSceneWithMoonState();
}

class _LoreSceneWithMoonState extends State<_LoreSceneWithMoon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _moonFloat;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _moonFloat = Tween<double>(begin: 0, end: -12)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.2,
          colors: widget.bgColors,
        ),
      ),
      child: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _moonFloat.value),
                    child: const Text("🌙", style: TextStyle(fontSize: 52)),
                  ),
                ),
                const SizedBox(height: 24),
                _SceneLabel(widget.chapterLabel),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.titleColor,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    shadows: [Shadow(color: widget.titleShadowColor, blurRadius: 40)],
                  ),
                ),
                _GoldDivider(color: widget.dividerColor),
                Text(
                  widget.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: widget.bodyColor,
                    fontSize: 16,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LORE SCENE FINAL — logo reveal + enter button
// ─────────────────────────────────────────────
class _LoreSceneFinal extends StatefulWidget {
  final VoidCallback onEnter;
  const _LoreSceneFinal({required this.onEnter});

  @override
  State<_LoreSceneFinal> createState() => _LoreSceneFinalState();
}

class _LoreSceneFinalState extends State<_LoreSceneFinal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.2,
          colors: [Color(0xFF100A20), kNight],
        ),
      ),
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 76,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      shadows: [Shadow(color: kGold, blurRadius: 40)],
                    ),
                    children: [
                      TextSpan(text: "Myn", style: TextStyle(color: kGoldLight)),
                      TextSpan(
                        text: "X",
                        style: TextStyle(
                          color: kRebelLight,
                          shadows: [Shadow(color: kRebel, blurRadius: 30)],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "WHERE MISCHIEF BEGINS",
                  style: TextStyle(color: kRebelLight, fontSize: 11, letterSpacing: 5),
                ),
                const SizedBox(height: 32),
                Container(
                  width: 120, height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, kGold, kRebelLight, kGold, Colors.transparent],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: widget.onEnter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kGoldLight, kGold]),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66C9A84C), blurRadius: 30),
                      ],
                    ),
                    child: const Text(
                      "Enter the Realm",
                      style: TextStyle(
                        color: kNight,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED SCENE HELPERS
// ─────────────────────────────────────────────
class _SceneLabel extends StatelessWidget {
  final String text;
  const _SceneLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(color: kGold, fontSize: 11, letterSpacing: 6),
      );
}

class _GoldDivider extends StatelessWidget {
  final Color color;
  const _GoldDivider({required this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Container(
          width: 80, height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, color, Colors.transparent],
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
//  MYNX HOME (LOGIN SCREEN)
// ═══════════════════════════════════════════════════════════
class MynxHome extends StatefulWidget {
  const MynxHome({super.key});
  @override
  State<MynxHome> createState() => _MynxHomeState();
}

class _MynxHomeState extends State<MynxHome>
    with TickerProviderStateMixin {
  late AnimationController _glow, _shimmer, _entry;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Offset _mouse = const Offset(0, 0);
  bool   _signingIn = false;

  @override
  void initState() {
    super.initState();
    _glow    = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _shimmer = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _entry   = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade    = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _slide   = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entry, curve: Curves.easeOut));
    _entry.forward();
  }

  @override
  void dispose() {
    _glow.dispose();
    _shimmer.dispose();
    _entry.dispose();
    super.dispose();
  }

  void _goMain() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.displayName == null || user.displayName!.isEmpty) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              const ProfileSetupScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration:
              const Duration(milliseconds: 600),
        ),
        (r) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration:
              const Duration(milliseconds: 600),
        ),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: MouseRegion(
      onHover: (e) => setState(() => _mouse = e.position),
      child: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D0820),
                kNight,
                Color(0xFF050308)
              ],
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: 0,
          right: 0,
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  kRebel.withOpacity(0.10),
                  Colors.transparent
                ],
                radius: 0.9,
              ),
            ),
          ),
        ),
        Positioned(
          left: _mouse.dx - 60,
          top:  _mouse.dy - 60,
          child: IgnorePointer(
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Color(0x33C9A84C),
                  Colors.transparent
                ]),
              ),
            ),
          ),
        ),
        const ParticleBackground(),
        ..._runes(),
        FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("🌙",
                        style: TextStyle(
                            fontSize: 32,
                            shadows: [
                              Shadow(
                                  color: kRebelLight,
                                  blurRadius: 20)
                            ])),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _shimmer,
                      builder: (_, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4),
                                children: [
                                  TextSpan(
                                      text: "Myn",
                                      style: TextStyle(
                                          color: kGoldLight,
                                          shadows: [
                                            Shadow(
                                                color: kGold,
                                                blurRadius: 40)
                                          ])),
                                  TextSpan(
                                      text: "X",
                                      style: TextStyle(
                                          color: kRebelLight,
                                          shadows: [
                                            Shadow(
                                                color: kRebel,
                                                blurRadius: 30)
                                          ])),
                                ],
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (r) =>
                                  LinearGradient(
                                begin: Alignment(
                                    -1 + _shimmer.value * 2,
                                    0),
                                end: Alignment(
                                    1 + _shimmer.value * 2, 0),
                                colors: const [
                                  Colors.transparent,
                                  Color(0xFFFFF3B0),
                                  Colors.white,
                                  Color(0xFFFFF3B0),
                                  Colors.transparent,
                                ],
                                stops: const [
                                  0.0,
                                  0.35,
                                  0.5,
                                  0.65,
                                  1.0
                                ],
                              ).createShader(r),
                              blendMode: BlendMode.srcATop,
                              child: const Text("MynX",
                                  style: TextStyle(
                                      fontSize: 64,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                      color: kGoldLight)),
                            ),
                          ]),
                    ),
                    const SizedBox(height: 6),
                    const Text("WHERE MISCHIEF BEGINS",
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 5,
                            color: kRebelLight)),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 24),
                      child: Container(
                        width: 100,
                        height: 1,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            kGold,
                            kRebelLight,
                            kGold,
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                    // Google Sign-In button with loading state
                    _signingIn
                        ? Container(
                            width: 270,
                            padding: const EdgeInsets.symmetric(
                                vertical: 15),
                            decoration: BoxDecoration(
                              color: const Color(0xFF140F23),
                              borderRadius:
                                  BorderRadius.circular(8),
                              border: Border.all(
                                  color: kRebel.withOpacity(0.4)),
                            ),
                            child: const Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                          color: kRebelLight,
                                          strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text("Entering the Realm...",
                                    style: TextStyle(
                                        color: kRebelLight,
                                        fontSize: 14)),
                              ],
                            ),
                          )
                        : _btn(
                            Icons.g_mobiledata,
                            "Continue with Google",
                            kRebel.withOpacity(0.4),
                            kRebelLight,
                            const Color(0xFF140F23),
                            () async {
                              setState(() => _signingIn = true);
                              try {
                                await signInWithGoogle();
                                _goMain();
                              } catch (e) {
                                debugPrint("$e");
                                setState(
                                    () => _signingIn = false);
                              }
                            }),
                    const SizedBox(height: 14),
                    _btn(
                        Icons.gavel_outlined,
                        "Agreement",
                        kGold.withOpacity(0.3),
                        kGoldLight,
                        const Color(0xFF0F0A19),
                        _agreement),
                    const SizedBox(height: 14),
                    _chiefBtn(),
                    const SizedBox(height: 36),
                    GestureDetector(
                      onTap: _assist,
                      child: const Text("Need Assistance?",
                          style: TextStyle(
                              color: Color(0x55C4B5FD),
                              fontSize: 13,
                              letterSpacing: 2)),
                    ),
                  ]),
            ),
          ),
        ),
      ]),
    ),
  );

  Widget _btn(IconData ic, String lb, Color bc, Color tc,
          Color bg, VoidCallback ot) =>
      GestureDetector(
        onTap: ot,
        child: Container(
          width: 270,
          padding: const EdgeInsets.symmetric(
              vertical: 15, horizontal: 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bc),
            boxShadow: [
              BoxShadow(
                  color: bc.withOpacity(0.12), blurRadius: 20)
            ],
          ),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ic, color: tc.withOpacity(0.8), size: 20),
                const SizedBox(width: 10),
                Text(lb,
                    style: TextStyle(
                        color: tc,
                        fontSize: 15,
                        letterSpacing: 0.5)),
              ]),
        ),
      );

  Widget _chiefBtn() => AnimatedBuilder(
    animation: _glow,
    builder: (_, __) => GestureDetector(
      onTap: _chief,
      child: Container(
        width: 270,
        padding: const EdgeInsets.symmetric(
            vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [
                Color(0xFFB8860B),
                kGold,
                kGoldLight,
                kGold
              ],
              stops: [0, 0.4, 0.7, 1]),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: const Color(0x66C9A84C),
                blurRadius: 20 + _glow.value * 25)
          ],
        ),
        child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_unread,
                  color: kNight, size: 20),
              SizedBox(width: 10),
              Text("Message from Mynx Chief",
                  style: TextStyle(
                      color: kNight,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5)),
            ]),
      ),
    ),
  );

  List<Widget> _runes() {
    const c = Color(0x33C9A84C);
    const s = 50.0, w = 1.0;
    return [
      Positioned(
        top: 20,
        left: 20,
        child: Container(
          width: s,
          height: s,
          decoration: const BoxDecoration(
              border: Border(
                  top:  BorderSide(color: c, width: w),
                  left: BorderSide(color: c, width: w))),
        ),
      ),
      Positioned(
        top: 20,
        right: 20,
        child: Container(
          width: s,
          height: s,
          decoration: const BoxDecoration(
              border: Border(
                  top:   BorderSide(color: c, width: w),
                  right: BorderSide(color: c, width: w))),
        ),
      ),
      Positioned(
        bottom: 20,
        left: 20,
        child: Container(
          width: s,
          height: s,
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: c, width: w),
                  left:   BorderSide(color: c, width: w))),
        ),
      ),
      Positioned(
        bottom: 20,
        right: 20,
        child: Container(
          width: s,
          height: s,
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: c, width: w),
                  right:  BorderSide(color: c, width: w))),
        ),
      ),
    ];
  }

  void _chief() => showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kDeep,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66C9A84C),
                blurRadius: 30,
                spreadRadius: 2)
          ],
          border:
              Border.all(color: const Color(0x33C9A84C)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite, color: kGold, size: 40),
          const SizedBox(height: 15),
          const Text("You finally showed up~",
              style:
                  TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 10),
          const Text("Welcome to MynX ✨",
              style: TextStyle(
                  color: kGoldLight,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: kGold, blurRadius: 20)
                  ])),
          const SizedBox(height: 10),
          const Text(
            "You took your time.... I was starting to think you'd never come~.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Continue",
                style: TextStyle(color: kGold)),
          ),
        ]),
      ),
    ),
  );

  void _assist() => showDialog(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kDeep,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(
                color: Color(0x66C9A84C),
                blurRadius: 30,
                spreadRadius: 2)
          ],
          border:
              Border.all(color: const Color(0x33C9A84C)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset("assets/icons/phone.png", height: 40),
          const SizedBox(height: 12),
          const Text("Need Assistance?",
              style: TextStyle(
                  color: kGoldLight,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            "Join our Discord server and create a support ticket 💬",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 30, vertical: 12),
            ),
            onPressed: () async {
              final u =
                  Uri.parse("https://discord.gg/3EMDqeYGe");
              if (await canLaunchUrl(u)) launchUrl(u);
            },
            child: const Text("Open Discord"),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close",
                style: TextStyle(color: Colors.white54)),
          ),
        ]),
      ),
    ),
  );

  void _agreement() => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: kDeep,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28)),
        border: Border.all(color: kGold.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 24),
        const Text("⚖️", style: TextStyle(fontSize: 36)),
        const SizedBox(height: 12),
        const Text("Realm Agreement",
            style: TextStyle(
                color: kGoldLight,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        _agreeBtn(
            Icons.privacy_tip_outlined,
            "Privacy Policy",
            "How we handle your realm data",
            kRebelLight,
            "https://www.example.com/privacy"),
        const SizedBox(height: 12),
        _agreeBtn(
            Icons.article_outlined,
            "Terms of Service",
            "The rules of the realm",
            kGoldLight,
            "https://www.example.com/terms"),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text("Close",
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  letterSpacing: 1)),
        ),
      ]),
    ),
  );

  Widget _agreeBtn(IconData ic, String lb, String sub,
          Color col, String url) =>
      GestureDetector(
        onTap: () async {
          final u = Uri.parse(url);
          if (await canLaunchUrl(u)) {
            launchUrl(u, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: col.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: col.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(ic, color: col, size: 22),
            const SizedBox(width: 14),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lb,
                      style: TextStyle(
                          color: col,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  Text(sub,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ]),
            const Spacer(),
            Icon(Icons.open_in_new,
                color: col.withOpacity(0.5), size: 16),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
//  PARTICLE BACKGROUND
// ═══════════════════════════════════════════════════════════
class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});
  @override
  State<ParticleBackground> createState() => _ParticleBgState();
}

class _ParticleBgState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 25))
      ..repeat();
  }
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => CustomPaint(
        painter: ParticlePainter(_c.value), size: Size.infinite),
  );
}

class ParticlePainter extends CustomPainter {
  final double progress;
  final Random _r = Random(42);
  ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 50; i++) {
      final x  = _r.nextDouble() * size.width;
      final by = _r.nextDouble() * size.height;
      final y  = (by + progress * 260) % size.height;
      final r  = _r.nextDouble() * 2.0 + 0.3;
      final p  = Paint()
        ..color = i % 3 != 0
            ? kGold.withOpacity(0.09)
            : kRebel.withOpacity(0.09);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;

// ═══════════════════════════════════════════════════════════
//  ROLEPLAY TOOLS PAGE  — dice, coin, rp utilities
// ═══════════════════════════════════════════════════════════
class RpToolsPage extends StatefulWidget {
  const RpToolsPage({super.key});
  @override
  State<RpToolsPage> createState() => _RpToolsPageState();
}

class _RpToolsPageState extends State<RpToolsPage> {
  final Random _rng = Random();
  String _diceResult  = "—";
  String _coinResult  = "—";
  String _promptResult = "—";
  int    _diceMax     = 20;
  int    _diceCount   = 1;

  static const _rpPrompts = [
    "Two strangers meet during a storm with no shelter in sight.",
    "A letter arrives from someone who died three years ago.",
    "Your character discovers they've been lied to their whole life.",
    "A deal is offered — power at an unbearable price.",
    "The villain asks your character for help. Genuinely.",
    "Someone from the past returns. The timing couldn't be worse.",
    "Your character must choose between loyalty and the truth.",
    "A forbidden secret slips out at the worst possible moment.",
    "The map leads somewhere that shouldn't exist.",
    "An ally betrays your character — but for understandable reasons.",
    "Magic fails at the critical moment.",
    "Your character is mistaken for someone dangerous.",
    "A child asks a question your character can't answer.",
    "The enemy offers a truce. It might be real.",
    "Your character wakes up somewhere they don't recognise.",
  ];

  void _rollDice() {
    final results = List.generate(_diceCount, (_) => _rng.nextInt(_diceMax) + 1);
    final total   = results.fold(0, (a, b) => a + b);
    setState(() => _diceResult = _diceCount == 1
        ? "${results[0]}"
        : "${results.join(' + ')} = $total");
  }

  void _flipCoin() {
    setState(() => _coinResult = _rng.nextBool() ? "Heads ☀️" : "Tails 🌙");
  }

  void _getPrompt() {
    setState(() => _promptResult = _rpPrompts[_rng.nextInt(_rpPrompts.length)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNight,
      appBar: AppBar(
        backgroundColor: kDeep, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.white70),
          onPressed: () => Navigator.pop(context)),
        title: RichText(text: const TextSpan(
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          children: [
            TextSpan(text: "RP ", style: TextStyle(color: kGoldLight)),
            TextSpan(text: "Tools", style: TextStyle(color: kRebelLight)),
          ],
        )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Dice Roller ──────────────────────────
          _sectionHeader("🎲", "Dice Roller", kCatPlot),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCatPlot.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCatPlot.withOpacity(0.25))),
            child: Column(children: [
              // Result display
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: kDeep, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kCatPlot.withOpacity(0.3))),
                child: Text(_diceResult,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kRebelLight, fontSize: 36, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 16),
              // Dice count
              Row(children: [
                const Text("Dice:", style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 12),
                ...[1, 2, 3, 4, 5].map((n) => GestureDetector(
                  onTap: () => setState(() => _diceCount = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _diceCount == n ? kCatPlot.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _diceCount == n ? kCatPlot : Colors.white12)),
                    child: Center(child: Text("$n", style: TextStyle(
                      color: _diceCount == n ? kRebelLight : Colors.white38, fontSize: 13, fontWeight: FontWeight.w700)))))),
              ]),
              const SizedBox(height: 12),
              // Die type
              Row(children: [
                const Text("Type:", style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(width: 12),
                ...[4, 6, 8, 10, 12, 20, 100].map((n) => GestureDetector(
                  onTap: () => setState(() => _diceMax = n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _diceMax == n ? kCatPlot.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _diceMax == n ? kCatPlot : Colors.white12)),
                    child: Text("d$n", style: TextStyle(
                      color: _diceMax == n ? kRebelLight : Colors.white38, fontSize: 11, fontWeight: FontWeight.w700))))),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _rollDice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCatPlot, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text("Roll ${_diceCount}d$_diceMax", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Coin Flip ────────────────────────────
          _sectionHeader("🪙", "Coin Flip", kCatArt),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCatArt.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCatArt.withOpacity(0.25))),
            child: Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(color: kDeep, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kCatArt.withOpacity(0.3))),
                child: Text(_coinResult, textAlign: TextAlign.center,
                  style: const TextStyle(color: kGoldLight, fontSize: 22, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 14),
              ElevatedButton(
                onPressed: _flipCoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCatArt, foregroundColor: kNight,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Flip", style: TextStyle(fontWeight: FontWeight.bold))),
            ]),
          ),

          const SizedBox(height: 20),

          // ── RP Prompt Generator ──────────────────
          _sectionHeader("✨", "Plot Spark", kCatOC),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kCatOC.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCatOC.withOpacity(0.25))),
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: kDeep, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kCatOC.withOpacity(0.3))),
                child: Text(
                  _promptResult == "—" ? "Tap below to spark a plot idea..." : _promptResult,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _promptResult == "—" ? Colors.white24 : Colors.white,
                    fontSize: 15, height: 1.6,
                    fontStyle: _promptResult == "—" ? FontStyle.normal : FontStyle.italic))),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: _getPrompt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCatOC, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Spark a Plot ✨", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Number Picker (random NPC trait) ────
          _sectionHeader("🎴", "Character Trait Draw", kCatMemes),
          const SizedBox(height: 12),
          _TraitDrawWidget(),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String emoji, String title, Color color) =>
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ]);
}

class _TraitDrawWidget extends StatefulWidget {
  @override
  State<_TraitDrawWidget> createState() => _TraitDrawWidgetState();
}

class _TraitDrawWidgetState extends State<_TraitDrawWidget> {
  final Random _rng = Random();
  Map<String, String>? _traits;

  static const _personalities = ["Reckless","Calculating","Gentle","Cold","Charismatic","Paranoid","Loyal","Deceptive","Idealistic","Cynical","Impulsive","Methodical","Empathetic","Ruthless","Whimsical"];
  static const _flaws         = ["Trusts too easily","Lies habitually","Can't ask for help","Holds grudges","Overconfident","Isolates when hurt","Speaks before thinking","Obsesses over the past","Terrified of failure","Jealous of others"];
  static const _motivations   = ["Revenge","Redemption","Power","Love","Freedom","Knowledge","Survival","Belonging","Legacy","Justice","Peace","Proving themselves","Protecting someone","Finding the truth"];
  static const _secrets       = ["Has a hidden identity","Betrayed someone they loved","Is not who they claim to be","Has done something unforgivable","Is running from their past","Knows something dangerous","Is working against the group","Made a deal they regret"];

  void _draw() {
    setState(() => _traits = {
      "Personality": _personalities[_rng.nextInt(_personalities.length)],
      "Flaw":        _flaws[_rng.nextInt(_flaws.length)],
      "Motivation":  _motivations[_rng.nextInt(_motivations.length)],
      "Secret":      _secrets[_rng.nextInt(_secrets.length)],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCatMemes.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCatMemes.withOpacity(0.25))),
      child: Column(children: [
        if (_traits != null) ...[
          ..._traits!.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kCatMemes.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Text(e.key, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(child: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4))),
            ]))),
          const SizedBox(height: 8),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text("Draw traits for your character or NPC", textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 13))),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _draw,
          style: ElevatedButton.styleFrom(
            backgroundColor: kCatMemes, foregroundColor: kNight,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text("Draw Traits 🎴", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
      ]),
    );
  }
}
}
