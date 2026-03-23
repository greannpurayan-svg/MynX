import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart'; // needed for kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:ui';

// 🔥 NEW IMPORTS
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

 await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MynxApp());
}

// 🔥 GOOGLE SIGN-IN FUNCTION (FIXED FOR WEB)
Future<UserCredential> signInWithGoogle() async {
  if (kIsWeb) {
    // 🌐 WEB VERSION
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();

    googleProvider.setCustomParameters({
      "prompt": "select_account",
    });

    return await FirebaseAuth.instance.signInWithPopup(googleProvider);
  } else {
    // 📱 ANDROID / IOS VERSION
    final GoogleSignIn googleSignIn = GoogleSignIn();

    await googleSignIn.signOut(); // force account picker

    final GoogleSignInAccount? googleUser =
        await googleSignIn.signIn();

    if (googleUser == null) {
      throw Exception("Sign in aborted");
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await FirebaseAuth.instance
        .signInWithCredential(credential);
  }
}
class MynxApp extends StatelessWidget {
  const MynxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: StreamBuilder<User?>(
  stream: FirebaseAuth.instance.authStateChanges(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasData) {
      return const HomePage(); // 👈 logged in
    }

    return const MynxHome(); // 👈 not logged in
  },
),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("WELCOME 😈"),
      ),
    );
  }
}


class MynxHome extends StatefulWidget {
  const MynxHome({super.key});

  @override
  State<MynxHome> createState() => _MynxHomeState();
}

class _MynxHomeState extends State<MynxHome>
    with TickerProviderStateMixin {

  late AnimationController glowController;
  late AnimationController shimmerController;

  Offset mouse = const Offset(0, 0);

  @override
  void initState() {
    super.initState();

    glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    glowController.dispose();
    shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MouseRegion(
        onHover: (event) {
          setState(() {
            mouse = event.position;
          });
        },
        child: Stack(
          children: [

            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A0A0A),
                    Color(0xFF16131F),
                    Color(0xFF050505),
                  ],
                ),
              ),
            ),

            Positioned(
              left: mouse.dx - 60,
              top: mouse.dy - 60,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x55FFC857),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const ParticleBackground(),

            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  AnimatedBuilder(
                    animation: shimmerController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [

                          Text(
                            "MynX",
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: Color(0xFFFFC857),
                              shadows: [
                                Shadow(
                                  color: Color(0xAAFFC857),
                                  blurRadius: 40,
                                ),
                              ],
                            ),
                          ),

                          ShaderMask(
                            shaderCallback: (rect) {
                              return LinearGradient(
                                begin: Alignment(-1 + shimmerController.value * 2, 0),
                                end: Alignment(1 + shimmerController.value * 2, 0),
                                colors: const [
                                  Colors.transparent,
                                  Color(0xFFFFF3B0),
                                  Colors.white,
                                  Color(0xFFFFF3B0),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.srcATop,
                            child: const Text(
                              "MynX",
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color: Color(0xFFFFC857),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "Where Mischief Begins",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 70),

                  // 🔥 GOOGLE BUTTON NOW WORKS
                  glassButton(
                    icon: Icons.g_mobiledata,
                    text: "Continue with Google",
                  ),

                  const SizedBox(height: 20),

                  glassButton(
                    icon: Icons.email,
                    text: "Sign up with Email",
                  ),

                  const SizedBox(height: 20),

                  glowLoginButton(),

                  const SizedBox(height: 35),

                 TextButton(
  onPressed: () {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A), // SAME AS YOUR OTHER CARD
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0x66FFC857), // SAME GLOW 🔥
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: const Color(0x33FFC857),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
  'assets/icons/phone.png',
  height: 40,
),


              const SizedBox(height: 12),

              const Text(
                "Need Assistance?",
                style: TextStyle(
                  color: Color(0xFFFFC857),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Join our Discord server and create a support ticket 💬",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC857),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  final url = Uri.parse("https://discord.gg/3EMDqeYGe");
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: const Text("Open Discord"),
              ),

              const SizedBox(height: 10),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
  child: const Text(
    "Need Assistance?",
    style: TextStyle(color: Colors.white54),
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

   void openDiscord() async {
  final url = Uri.parse("https://discord.gg/3EMDqeYGe");

  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    throw 'Could not launch Discord';
  }
}

  Widget glassButton({required IconData icon, required String text}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 270,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
            ),
          ),
          child: ElevatedButton.icon(
            icon: Icon(icon, color: Colors.white70),
            label: Text(text),

            // 🔥 THIS IS THE MAGIC
          onPressed: () async {

  if (text == "Continue with Google") {
  try {
    print("CLICKED GOOGLE BUTTON");

    final user = await signInWithGoogle();

    print("SUCCESS LOGIN: ${user.user?.email}");

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(),
      ),
    );

  } catch (e) {
    print("ERROR DURING GOOGLE SIGN IN: $e");
  }
}
  else if (text == "Sign up with Email") {
    print("EMAIL CLICKED ✉️");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmailSignUpScreen(),
      ),
    );
  }

},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget glowLoginButton() {
    return AnimatedBuilder(
      animation: glowController,
      builder: (context, child) {

        double glow = 20 + (glowController.value * 25);

        return Container(
          width: 270,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: const Color(0x66FFC857),
                blurRadius: glow,
              )
            ],
          ),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.mark_email_unread),
            label: const Text("Message from Mynx Chief"),
           onPressed: () {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: const Color(0x66FFC857),
              blurRadius: 30,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            const Icon(Icons.favorite, color: Color(0xFFFFC857), size: 40),

            const SizedBox(height: 15),

            const Text(
              "You finally showed up~",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),

            const SizedBox(height: 10),

            const Text(
              "Welcome to MynX ✨",
              style: TextStyle(
                color: Color(0xFFFFC857),
                fontSize: 20,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: Color(0xAAFFC857), blurRadius: 20)
                ],
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "You took your time.... I was starting to think you'd never come~.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 20),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Continue",
                style: TextStyle(color: Color(0xFFFFC857)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
},

            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC857),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        );
      },
    );
  }
}

// (rest unchanged)

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  final pages = const [
    Center(child: Text("Home Feed")),
    Center(child: Text("Messages")),
    Center(child: Text("Profile")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        currentIndex: index,
        selectedItemColor: const Color(0xFFFFC857),
        unselectedItemColor: Colors.white54,
        onTap: (i) {
          setState(() {
            index = i;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return CustomPaint(
          painter: ParticlePainter(controller.value),
          size: Size.infinite,
        );
      },
    );
  }
  }

class ParticlePainter extends CustomPainter {
  final double progress;
  final Random random = Random();

  ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06);

    for (int i = 0; i < 40; i++) {
      double x = random.nextDouble() * size.width;
      double y = (random.nextDouble() * size.height + progress * 250) % size.height;

      canvas.drawCircle(
        Offset(x, y),
        random.nextDouble() * 2.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> signUp() async {
    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );

    } catch (e) {
      print("SIGN UP ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup failed 😭")),
      );
    }

    setState(() => loading = false);
  }
   @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: Stack(
      children: [

        // 🌌 BACKGROUND
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0A0A0A),
                Color(0xFF16131F),
                Color(0xFF050505),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        const ParticleBackground(),

        // 💎 GLASS CARD
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    const Text(
                      "MynX",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFC857),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Create Account",
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 25),

                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Email",
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Password",
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    ElevatedButton(
                      onPressed: loading ? null : signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC857),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: loading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text("Sign Up"),
                    ),

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
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );

    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Login Failed 😭"),
          content: const Text("Invalid email or password"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const Text(
                "Login",
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFFFC857),
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Email",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Password",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              ElevatedButton(
                onPressed: loading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC857),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text("Log In"),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final usernameController = TextEditingController();
  final ageController = TextEditingController();

  String selectedGender = "Male";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const Text(
                "Complete Profile",
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFFFFC857),
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Username",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Age",
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: selectedGender,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
               items: [
               "Male",
               "Female",
               "Non-binary",
               "Prefer not to say",
               "Other"
               ].map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedGender = value!;
                  });
                },
              ),

              const SizedBox(height: 25),

              ElevatedButton(
               onPressed: () {
  int? age = int.tryParse(ageController.text);

  if (age == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please enter a valid age 😭")),
    );
    return;
  }

 if (age < 13) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Access Denied 😔"),
      content: Text(
        "You are $age years old.\n\nYou must be at least 13 to use this app.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        ),
      ],
    ),
  );
  return;
}

  // ✅ Passed validation → go to Home
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => const HomeScreen(),
    ),
  );
},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC857),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text("Continue"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



