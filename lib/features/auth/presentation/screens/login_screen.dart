import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../application/auth_controller.dart';

// ── Palette ──────────────────────────────────────────────────────────────────
abstract final class _C {
  static const primaryDark  = Color(0xFF0F5D43);
  static const primary      = Color(0xFF1F6D50);
  static const primaryBtn   = Color(0xFF146B4A);
  static const textMain     = Color(0xFF20272F);
  static const textSub      = Color(0xFF6B7280);
  static const textFoot     = Color(0xFF747A80);
  static const tagline      = Color(0xFF126548);
  static const forgot       = Color(0xFF116B49);
  static const inputBorder  = Color(0xFFD5DDDA);
  static const inputFocus   = Color(0xFF1F5A43);
  static const inputHint    = Color(0xFFA4ADB8);
  static const error        = Color(0xFFDC3545);
  static const hillBack     = Color(0xFF79B99D);
  static const hillMid      = Color(0xFF378267);
  static const hillFront    = Color(0xFF0F5D43);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();

  bool _obscure      = true;
  bool _rememberMe   = true;
  bool _submitting   = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// Accepts either an email address or a WildGuard username. If the value
  /// contains `@` it must look like a valid email; otherwise it is treated as a
  /// username and only needs to be non-empty.
  String? _validateEmail(String? v) {
    final identifier = v?.trim() ?? '';
    if (identifier.isEmpty) return 'Email or username is required.';
    if (identifier.contains('@') &&
        !RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(identifier)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() => _submitting = true);
    final failure = await ref.read(authControllerProvider.notifier).signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _errorMsg   = failure?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final hPad = w < 370 ? 22.0 : w > 420 ? 30.0 : 28.0;
    // Hero occupies the top portion; the white panel fills the rest.
    final heroH = (h * 0.44).clamp(320.0, 420.0);
    const overlap = 34.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        // Let Scaffold resize the body when keyboard opens (default behavior)
        resizeToAvoidBottomInset: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final minH = constraints.maxHeight;
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minH),
                child: IntrinsicHeight(
                  child: Stack(
                    children: [
                      // ── Hero (behind status bar) ──────────
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _WildGuardHero(height: heroH),
                      ),
                      // ── White panel overlapping hero ─
                      Padding(
                        padding: EdgeInsets.only(top: heroH - overlap),
                        child: _LoginPanel(
                          hPad: hPad,
                          bottomInset: mq.padding.bottom,
                          formKey: _formKey,
                          emailCtrl: _emailCtrl,
                          passwordCtrl: _passwordCtrl,
                          obscure: _obscure,
                          rememberMe: _rememberMe,
                          submitting: _submitting,
                          errorMsg: _errorMsg,
                          validateEmail: _validateEmail,
                          validatePassword: _validatePassword,
                          onToggleObscure: () => setState(() => _obscure = !_obscure),
                          onToggleRemember: (v) => setState(() => _rememberMe = v ?? true),
                          onSubmit: _submit,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

class _WildGuardHero extends StatelessWidget {
  const _WildGuardHero({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Sky-toned fill so no white can ever show behind the artwork.
          const ColoredBox(color: Color(0xFF9ACEDA)),
          Image.asset(
            'assets/images/login_background.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          // Subtle gradient: transparent → dark-green at bottom
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x440F5D43)],
                stops: [0.55, 1.0],
              ),
            ),
          ),
          // Logo — clear of the status bar / notch, centered in hero
          Positioned(
            top: top + 12,
            left: 0,
            right: 0,
            bottom: 18,
            child: Align(
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/wildguard_logo.png',
                width: 128,
                height: 128,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── White panel ───────────────────────────────────────────────────────────────

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.hPad,
    required this.bottomInset,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.rememberMe,
    required this.submitting,
    required this.errorMsg,
    required this.validateEmail,
    required this.validatePassword,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onSubmit,
  });

  final double hPad;
  final double bottomInset;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool rememberMe;
  final bool submitting;
  final String? errorMsg;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePassword;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Form content — compact so everything fits without scrolling.
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  const Text(
                    'WILDGUARD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.5,
                      color: _C.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Smart Wildlife Conservation & Monitoring',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _C.textSub,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Error banner
                  if (errorMsg != null) ...[
                    _ErrorBanner(message: errorMsg!),
                    const SizedBox(height: 12),
                  ],

                  // Email or username
                  const _FieldLabel('Email or Username'),
                  const SizedBox(height: 7),
                  _AuthTextField(
                    controller: emailCtrl,
                    hint: 'Email or username',
                    prefixIcon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    enabled: !submitting,
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 8),

                  // Password
                  const _FieldLabel('Password'),
                  const SizedBox(height: 7),
                  _AuthTextField(
                    controller: passwordCtrl,
                    hint: 'Enter your password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    enabled: !submitting,
                    onFieldSubmitted: (_) => onSubmit(),
                    validator: validatePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: const Color(0xFF6B7280),
                      ),
                      onPressed: onToggleObscure,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Remember me / Forgot password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: rememberMe,
                                onChanged:
                                    submitting ? null : onToggleRemember,
                                activeColor: _C.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Remember me',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _C.textMain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Builder(builder: (ctx) {
                        return TextButton(
                          onPressed: submitting
                              ? null
                              : () => ctx.push(AppRoutes.forgotPassword),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _C.forgot,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Sign In
                  _PrimarySignInButton(
                    onPressed: submitting ? null : onSubmit,
                    loading: submitting,
                  ),
                ],
              ),
            ),

            // Flexible gap pushes the footer + hills to the bottom.
            const Spacer(),

            // Footer text
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                children: const [
                  Text(
                    'Authorized personnel only',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _C.textFoot),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Conserve  •  Track  •  Protect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.7,
                      color: _C.tagline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Decorative hills (full-bleed, behind the gesture bar)
            _ConservationFooter(bottomInset: bottomInset),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _C.textMain,
        ),
      );
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final bool obscureText;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  static const _r = 14.0;

  InputDecoration get _dec => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.inputHint, fontSize: 15),
        prefixIcon: Icon(prefixIcon, size: 20, color: const Color(0xFF6B7280)),
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_r),
          borderSide: const BorderSide(color: _C.inputBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_r),
          borderSide: const BorderSide(color: _C.inputBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_r),
          borderSide: const BorderSide(color: _C.inputFocus, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_r),
          borderSide: const BorderSide(color: _C.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_r),
          borderSide: const BorderSide(color: _C.error, width: 1.8),
        ),
      );

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        enabled: enabled,
        obscureText: obscureText,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: _C.textMain),
        decoration: _dec,
      );
}

class _PrimarySignInButton extends StatelessWidget {
  const _PrimarySignInButton({required this.onPressed, this.loading = false});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.primaryBtn,
            disabledBackgroundColor: _C.primaryBtn.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SIGN IN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                  ],
                ),
        ),
      );
}

class _ConservationFooter extends StatelessWidget {
  const _ConservationFooter({this.bottomInset = 0});
  final double bottomInset;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34 + bottomInset,
        child: CustomPaint(painter: _LandscapePainter()),
      );
}

class _LandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()..style = PaintingStyle.fill;

    // Back hill
    p.color = _C.hillBack;
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.52)
        ..quadraticBezierTo(w * 0.22, h * 0.08, w * 0.48, h * 0.38)
        ..quadraticBezierTo(w * 0.72, h * 0.65, w, h * 0.33)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      p,
    );

    // Mid hill
    p.color = _C.hillMid;
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.72)
        ..quadraticBezierTo(w * 0.28, h * 0.28, w * 0.52, h * 0.56)
        ..quadraticBezierTo(w * 0.76, h * 0.82, w, h * 0.52)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      p,
    );

    // Front hill
    p.color = _C.hillFront;
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.88)
        ..quadraticBezierTo(w * 0.32, h * 0.48, w * 0.56, h * 0.76)
        ..quadraticBezierTo(w * 0.82, h * 1.02, w, h * 0.70)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _C.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: _C.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: _C.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}
