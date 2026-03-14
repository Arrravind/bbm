import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WistiaPlayerPage extends StatefulWidget {
  const WistiaPlayerPage({super.key});

  @override
  State<WistiaPlayerPage> createState() => _WistiaPlayerPageState();
}

class _WistiaPlayerPageState extends State<WistiaPlayerPage>
    with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();

    // Background animation
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    // WebView controller
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadHtmlString(_wistiaHtml);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  static const String _wistiaHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://fast.wistia.com/assets/external/E-v1.js" async></script>
  <style>
    html, body {
      margin: 0;
      background: transparent;
    }
    .wistia_embed {
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>
  <div class="wistia_embed wistia_async_95jn8b7cnd
    playerColor=ED4799
    smallPlayButton=true
    controlsVisibleOnLoad=true
    fullscreenButton=true
    videoFoam=true">
  </div>
</body>
</html>
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFFEFA7BF),
                    const Color(0xFFF7C1D9),
                    _bgController.value,
                  )!,
                  Color.lerp(
                    const Color(0xFFF7C1D9),
                    const Color(0xFFEFA7BF),
                    _bgController.value,
                  )!,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Elite Plan Walkthrough",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "See how artists get 4–5 confirmed bookings monthly",
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // VIDEO
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: WebViewWidget(controller: _controller),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _highlight("🎯 Targeted Tamil Nadu leads"),
                  _highlight("📈 Proven campaign structure"),
                  _highlight("🤝 End-to-end support"),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _highlight(String text) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        );
      },
    );
  }
}
