
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } else {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const WebApp(),
    );
  }
}

class WebApp extends StatefulWidget {
  const WebApp({super.key});

  @override
  State<WebApp> createState() => _WebAppState();
}

class _WebAppState extends State<WebApp> {
  bool isLoading = true;
  int progress = 0;
  bool showControls = false;
  bool noInternet = false;
  Timer? _hideTimer;
  Timer? _recheckTimer;
  bool hideWebViewOnError = false;
  static const int _retryInterval = 4;
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            setState(() => progress = value);
          },
          onPageStarted: (url) {
            setState(() {
              isLoading = true;
              progress = 0;
            });
          },
          onPageFinished: (url) async {
            setState(() => isLoading = false);
            setState(() => noInternet = false);
            _cancelRecheck();
            setState(() => hideWebViewOnError = false);

            // إخفاء الهيدر والفوتر لو موجودين
            await controller.runJavaScript("""
              try {
                var header = document.querySelector('header');
                if(header) header.style.display = 'none';

                var footer = document.querySelector('footer');
                if(footer) footer.style.display = 'none';
              } catch(e) {}
            """);
          },
          onWebResourceError: (error) {
            setState(() {
              isLoading = false;
              noInternet = true;
              hideWebViewOnError = true;
            });
            _startRecheck();
            controller.loadHtmlString(
              '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"/><style>html,body{height:100%;margin:0;background:#000}</style></head><body></body></html>',
            );
          },
          onNavigationRequest: (request) {
            if (!request.url.startsWith("https://casa.study")) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setBackgroundColor(const Color(0xFF000000))
      ..loadRequest(Uri.parse("https://casa.study/"));

    _checkInternet();
  }

  Future<void> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('casa.study').timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        if (mounted) setState(() => noInternet = false);
        _cancelRecheck();
      } else {
        if (mounted) setState(() => noInternet = true);
        _startRecheck();
      }
    } catch (_) {
      if (mounted) setState(() => noInternet = true);
      _startRecheck();
    }
  }

  void _startRecheck() {
    _recheckTimer?.cancel();
    _recheckTimer = Timer.periodic(const Duration(seconds: _retryInterval), (_) async {
      await _checkInternet();
      if (!noInternet) {
        hideWebViewOnError = false;
        controller.loadRequest(Uri.parse('https://casa.study/'));
      }
    });
  }

  void _cancelRecheck() {
    _recheckTimer?.cancel();
    _recheckTimer = null;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _recheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await controller.canGoBack()) {
          controller.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
        onLongPress: () {
          setState(() => showControls = true);
          _hideTimer?.cancel();
          _hideTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => showControls = false);
          });
        },
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: hideWebViewOnError,
              child: AnimatedOpacity(
                opacity: hideWebViewOnError ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: WebViewWidget(controller: controller),
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: progress < 100 ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 100) / 100,
                  minHeight: 2,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),

            IgnorePointer(
              ignoring: !isLoading,
              child: AnimatedOpacity(
                opacity: isLoading ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              right: 24,
              bottom: 24,
              child: IgnorePointer(
                ignoring: !showControls,
                child: AnimatedOpacity(
                  opacity: showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () async {
                            if (await controller.canGoBack()) {
                              controller.goBack();
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () {
                            _checkInternet();
                            if (noInternet) {
                              return;
                            }
                            hideWebViewOnError = false;
                            controller.loadRequest(Uri.parse('https://casa.study/'));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.white),
                          onPressed: () async {
                            if (await controller.canGoForward()) {
                              controller.goForward();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: noInternet
                  ? Positioned.fill(
                      child: Stack(
                        children: [
                          // Banner top
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              color: Colors.black.withValues(alpha: 0.85),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'محاولة إعادة الاتصال كل $_retryInterval ثوانٍ...',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Dim background
                          Positioned.fill(
                            child: Container(color: Colors.black.withValues(alpha: 0.92)),
                          ),
                          // Center card
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: 280,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 8)),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.asset(
                                        'assets/icon.png',
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'لا يوجد إنترنت',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'تأكد من الاتصال بالشبكة ثم حاول مرة أخرى',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          _checkInternet();
                                          if (!noInternet) {
                                            controller.loadRequest(Uri.parse('https://casa.study/'));
                                          }
                                        },
                                        child: const Text('إعادة المحاولة'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
