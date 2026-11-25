import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app_toast.dart';
import 'dashboard_page.dart';
import 'app_input_formatters.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  static const Color navyPrimary = Color(0xFF0B2853);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color inputBorder = Color(0xFFCBD5E1);
  static const Color subtitleSlate = Color(0xFF475569);

  static const String apiBaseUrl =
      'https://paint-shop-backend-52ro.onrender.com/api';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isEmpty) {
      AppToast.showWarning(
        context,
        title: 'Invalid Username',
        message: 'Please enter your username.',
      );
      return;
    }

    if (username.contains(' ')) {
      AppToast.showWarning(
        context,
        title: 'Invalid Username',
        message: 'Username cannot contain spaces. Enter exact username.',
      );
      return;
    }

    if (password.isEmpty) {
      AppToast.showWarning(
        context,
        title: 'Invalid Password',
        message: 'Please enter your password.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'identifier': username,
              'username': username,
              'email': username,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final dynamic decoded = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 &&
          decoded is Map &&
          decoded['success'] == true &&
          decoded['token'] != null) {
        final String token = decoded['token'].toString();

        final Map<String, dynamic>? user = decoded['user'] is Map
            ? Map<String, dynamic>.from(decoded['user'])
            : null;

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              token: token,
              currentUser: user,
              showWelcomeToast: true,
            ),
          ),
        );

        return;
      }

      String message = 'Incorrect username or password';

      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }

      AppToast.showError(context, title: 'Login Failed', message: message);
    } catch (e) {
      if (!mounted) return;

      AppToast.showError(
        context,
        title: 'Connection Error',
        message:
            'Could not connect to server: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final totalW = size.width;
    final totalH = size.height;

    final isDesktop = totalW >= 820;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isDesktop
          ? _buildDesktopLayout(totalW, totalH)
          : _buildMobileLayout(totalW, totalH),
    );
  }

  Widget _buildDesktopLayout(double totalW, double totalH) {
    final heroWidth = totalW * 0.62;
    final rightPanelLeft = totalW * 0.555;

    return Stack(
      key: const ValueKey('desktop_login'),
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: heroWidth,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/login_hero_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, _, _) =>
                    Container(color: const Color(0xFFF8FAFC)),
              ),
              Positioned(
                left: heroWidth * 0.055,
                width: heroWidth * 0.49,
                top: totalH * 0.06,
                bottom: totalH * 0.25,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: _buildHeroBrandingContent(),
                ),
              ),
            ],
          ),
        ),

        Positioned(
          left: rightPanelLeft,
          right: 0,
          top: 0,
          bottom: 0,
          child: CustomPaint(
            painter: _CurvedDividerPanelPainter(
              navyColor: navyPrimary,
              goldColor: accentAmber,
              panelColor: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 58, right: 44),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: SingleChildScrollView(child: _buildLoginForm()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(double totalW, double totalH) {
    final heroHeight = (totalH * 0.34).clamp(210.0, 290.0);

    return SafeArea(
      key: const ValueKey('mobile_login'),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: totalH - MediaQuery.paddingOf(context).vertical,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: heroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/login_hero_bg.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) =>
                          Container(color: const Color(0xFFF1F5F9)),
                    ),

                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.95),
                            Colors.white.withValues(alpha: 0.78),
                            Colors.white.withValues(alpha: 0.10),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),

                    Positioned(
                      left: 18,
                      top: 16,
                      bottom: 34,
                      width: (totalW * 0.56).clamp(180.0, 260.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _buildMobileHeroBranding(),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 30,
                      child: CustomPaint(
                        painter: _MobileBottomWavePainter(
                          navyColor: navyPrimary,
                          goldColor: accentAmber,
                          panelColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _buildLoginForm(compact: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeroBranding() {
    return SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 44,
                height: 24,
                child: CustomPaint(
                  painter: _BrandHouseRoofPainter(
                    navyColor: navyPrimary,
                    goldColor: accentAmber,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  children: [
                    TextSpan(
                      text: 'Paint ',
                      style: TextStyle(color: navyPrimary),
                    ),
                    TextSpan(
                      text: 'Shop',
                      style: TextStyle(color: accentAmber),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Add Color',
            style: TextStyle(
              color: navyPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const Text(
            'to Your Life',
            style: TextStyle(
              color: accentAmber,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Premium Paints • Beautiful Homes',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBrandingContent() {
    return SizedBox(
      width: 410,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 62,
            child: CustomPaint(
              painter: _BrandHouseRoofPainter(
                navyColor: navyPrimary,
                goldColor: accentAmber,
              ),
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.05,
              ),
              children: [
                TextSpan(
                  text: 'Paint ',
                  style: TextStyle(color: navyPrimary),
                ),
                TextSpan(
                  text: 'Shop',
                  style: TextStyle(color: accentAmber),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '———  Color Your World  ———',
            style: TextStyle(
              color: navyPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Add Color',
            style: TextStyle(
              color: navyPrimary,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.05,
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'to ',
                style: TextStyle(
                  color: navyPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              Text(
                'Your Life',
                style: TextStyle(
                  color: accentAmber,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 190,
            height: 8,
            child: CustomPaint(
              painter: _BrushUnderlinePainter(color: accentAmber),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Premium Paints  •  Beautiful Homes  •  Better Tomorrow',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFeatureBadge(Icons.verified_user_outlined, 'High\nQuality'),
              _buildFeatureBadge(Icons.palette_outlined, 'Wide\nRange'),
              _buildFeatureBadge(Icons.local_offer_outlined, 'Best\nPrice'),
              _buildFeatureBadge(Icons.support_agent_outlined, '24/7\nSupport'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            border: Border.all(color: navyPrimary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: navyPrimary.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 21, color: navyPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm({bool compact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: compact ? 64 : 78,
          height: compact ? 44 : 54,
          child: CustomPaint(
            painter: _PaintRollerLogoPainter(color: navyPrimary),
          ),
        ),
        SizedBox(height: compact ? 6 : 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: compact ? 26 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            children: const [
              TextSpan(
                text: 'Login ',
                style: TextStyle(color: navyPrimary),
              ),
              TextSpan(
                text: 'Account',
                style: TextStyle(color: accentAmber),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Welcome back! Please login to your account',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: subtitleSlate,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: compact ? 20 : 26),

        // USERNAME FIELD - EMAIL OPTION REMOVED
        _buildSplitIconField(
          controller: _usernameController,
          hintText: 'Username',
          prefixIcon: Icons.person_rounded,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.text,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) {
            FocusScope.of(context).requestFocus(_passwordFocusNode);
          },
        ),

        const SizedBox(height: 14),

        // PASSWORD FIELD
        _buildSplitIconField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          textInputAction: TextInputAction.done,
          hintText: 'Password',
          prefixIcon: Icons.lock_rounded,
          obscureText: _obscurePassword,
          onSubmitted: (_) => _login(),
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 19,
              color: const Color(0xFF64748B),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () {
              setState(() {
                _rememberMe = !_rememberMe;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) {
                        setState(() {
                          _rememberMe = v ?? true;
                        });
                      },
                      activeColor: navyPrimary,
                      side: const BorderSide(color: navyPrimary, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Remember Me',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: compact ? 18 : 22),

        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: navyPrimary,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: navyPrimary.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 19, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSplitIconField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    List<TextInputFormatter>? inputFormatters,
    bool autocorrect = true,
    bool enableSuggestions = true,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: inputBorder, width: 1.1),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Icon(prefixIcon, size: 19, color: navyPrimary),
          ),
          Container(width: 1, height: 22, color: const Color(0xFFE2E8F0)),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textInputAction: textInputAction,
              keyboardType: keyboardType,
              obscureText: obscureText,
              onSubmitted: onSubmitted,
              inputFormatters: [
                const NoLeadingSpaceFormatter(),
                ...?inputFormatters,
              ],
              autocorrect: autocorrect,
              enableSuggestions: enableSuggestions,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: suffixIcon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// MOBILE BOTTOM WAVE PAINTER

class _MobileBottomWavePainter extends CustomPainter {
  final Color navyColor;
  final Color goldColor;
  final Color panelColor;

  const _MobileBottomWavePainter({
    required this.navyColor,
    required this.goldColor,
    required this.panelColor,
  });

  Path _wavePath(Size size, double yOffset) {
    final w = size.width;
    final h = size.height;

    return Path()
      ..moveTo(0, h * 0.48 + yOffset)
      ..cubicTo(
        w * 0.30,
        yOffset,
        w * 0.70,
        h * 0.85 + yOffset,
        w,
        h * 0.35 + yOffset,
      )
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_wavePath(size, -6), Paint()..color = navyColor);

    canvas.drawPath(_wavePath(size, 0), Paint()..color = goldColor);

    canvas.drawPath(_wavePath(size, 5), Paint()..color = panelColor);
  }

  @override
  bool shouldRepaint(covariant _MobileBottomWavePainter oldDelegate) =>
      oldDelegate.navyColor != navyColor ||
      oldDelegate.goldColor != goldColor ||
      oldDelegate.panelColor != panelColor;
}

// BRAND HOUSE ROOF PAINTER

class _BrandHouseRoofPainter extends CustomPainter {
  final Color navyColor;
  final Color goldColor;

  const _BrandHouseRoofPainter({
    required this.navyColor,
    required this.goldColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.height / 62.0).clamp(0.35, 1.5);

    canvas.save();
    canvas.scale(scale, scale);

    final cx = (size.width / scale) * 0.5;

    final roofPaint = Paint()
      ..color = goldColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final roofPath = Path()
      ..moveTo(cx - 56, 46)
      ..lineTo(cx, 10)
      ..lineTo(cx + 56, 46);

    canvas.drawPath(roofPath, roofPaint);

    final winPaint = Paint()..color = navyColor;

    const winSize = 8.0;
    const gap = 2.8;

    final wx = cx - winSize - gap / 2;
    const wy = 28.0;

    canvas.drawRect(Rect.fromLTWH(wx, wy, winSize, winSize), winPaint);

    canvas.drawRect(
      Rect.fromLTWH(wx + winSize + gap, wy, winSize, winSize),
      winPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(wx, wy + winSize + gap, winSize, winSize),
      winPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(wx + winSize + gap, wy + winSize + gap, winSize, winSize),
      winPaint,
    );

    canvas.save();
    canvas.translate(cx + 32, 27);
    canvas.rotate(-0.62);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -4.5, 19, 8.5),
        const Radius.circular(2),
      ),
      winPaint,
    );

    final arm = Path()
      ..moveTo(9, 0)
      ..lineTo(13, 0)
      ..lineTo(13, 9)
      ..lineTo(3, 9)
      ..lineTo(3, 19);

    canvas.drawPath(
      arm,
      Paint()
        ..color = navyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandHouseRoofPainter oldDelegate) =>
      oldDelegate.navyColor != navyColor || oldDelegate.goldColor != goldColor;
}

// BRUSH UNDERLINE PAINTER

class _BrushUnderlinePainter extends CustomPainter {
  final Color color;

  const _BrushUnderlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(4, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.45,
        0,
        size.width - 4,
        size.height * 0.55,
      )
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.42,
        4,
        size.height * 0.72,
      );

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BrushUnderlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

// CURVED DIVIDER PANEL PAINTER

class _CurvedDividerPanelPainter extends CustomPainter {
  final Color navyColor;
  final Color goldColor;
  final Color panelColor;

  const _CurvedDividerPanelPainter({
    required this.navyColor,
    required this.goldColor,
    required this.panelColor,
  });

  Path _buildCurvePanelPath(Size size, double offset) {
    final w = size.width;
    final h = size.height;

    final startX = 48.0 + offset;
    final midLeftX = 8.0 + offset;
    final endX = 44.0 + offset;

    return Path()
      ..moveTo(startX, 0)
      ..cubicTo(midLeftX - 8, h * 0.30, midLeftX + 4, h * 0.72, endX, h)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _buildCurvePanelPath(size, -12),
      Paint()..color = navyColor,
    );

    canvas.drawPath(_buildCurvePanelPath(size, 2), Paint()..color = goldColor);

    canvas.drawPath(
      _buildCurvePanelPath(size, 14),
      Paint()..color = panelColor,
    );
  }

  @override
  bool shouldRepaint(covariant _CurvedDividerPanelPainter oldDelegate) {
    return oldDelegate.navyColor != navyColor ||
        oldDelegate.goldColor != goldColor ||
        oldDelegate.panelColor != panelColor;
  }
}

// PAINT ROLLER LOGO PAINTER

class _PaintRollerLogoPainter extends CustomPainter {
  final Color color;

  const _PaintRollerLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.height / 54.0).clamp(0.5, 1.5);

    canvas.save();
    canvas.translate(size.width * 0.52, size.height * 0.44);
    canvas.scale(scale, scale);
    canvas.rotate(-0.46);

    final fillPaint = Paint()..color = color;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final splash = Path()
      ..moveTo(-18, -8)
      ..lineTo(-34, -5)
      ..lineTo(-24, -1)
      ..lineTo(-37, 4)
      ..lineTo(-18, 7)
      ..close();

    canvas.drawPath(splash, fillPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -9, 34, 15),
        const Radius.circular(3.5),
      ),
      fillPaint,
    );

    final arm = Path()
      ..moveTo(16, -1.5)
      ..lineTo(23, -1.5)
      ..lineTo(23, 12)
      ..lineTo(4, 12)
      ..lineTo(4, 19);

    canvas.drawPath(arm, strokePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.5, 18, 7, 16),
        const Radius.circular(3),
      ),
      fillPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PaintRollerLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
