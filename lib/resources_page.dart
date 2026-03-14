import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;

import 'config/api_config.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage>
    with AutomaticKeepAliveClientMixin {
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> videos = [];

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      if (token == null) {
        if (!mounted) return;

        setState(() {
          hasError = true;
          errorMessage = "Session expired. Please login again.";
          isLoading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse(ApiConfig.tutorialVideosEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"token": token}),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to load videos");
      }

      final data = jsonDecode(response.body);
      debugPrint("Tutorial Videos Response: $data");
      if (!mounted) return;
      setState(() {
        videos = List<Map<String, dynamic>>.from(data["videos"] ?? []);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMessage = "Unable to load resources. Please try again.";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(body: _buildBody());
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return _buildErrorView();
    }

    if (videos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchVideos,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          return _VideoCard(video: videos[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.video_library_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No tutorials available yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Training resources will appear here once they are released.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(errorMessage ?? "Something went wrong"),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchVideos,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatefulWidget {
  final Map<String, dynamic> video;

  const _VideoCard({required this.video});

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  late final bool hasAccess;
  WebViewController? _controller;
  Map<String, dynamic> uiConfig = {};
  bool uiLoaded = false;
  bool _playInline = false;

  Future<void> fetchUIConfig(String screen) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("auth_token");

      final url = "${ApiConfig.uiConfigEndpoint}?screen=$screen&token=$token";

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        setState(() {
          uiConfig = data["config"];
          uiLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("UI CONFIG ERROR: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUIConfig("resources");

    hasAccess = widget.video["has_access"] == 1;

    if (hasAccess) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadHtmlString(_wistiaHtml(widget.video["wistia_id"]));
    }
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  String _wistiaHtml(String id) =>
      '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<script src="https://fast.wistia.com/assets/external/E-v1.js" async></script>
<style>
html, body {
  margin: 0;
  background: black;
}
.wistia_embed {
  width: 100%;
  height: 100%;
}
</style>
</head>
<body>

<div class="wistia_embed wistia_async_$id
  controlsVisibleOnLoad=true
  fullscreenButton=true
  videoFoam=true
  muted=false
  playbar=true">
</div>

<script>
window._wq = window._wq || [];
_wq.push({
  id: "$id",
  onReady: function(video) {
    video.pause();
  }
});
</script>

</body>
</html>
''';

  @override
  Widget build(BuildContext context) {
    final bool hasAccess = widget.video["has_access"] == 1;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  hasAccess && _controller != null
                      ? WebViewWidget(controller: _controller!)
                      : Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                        ),

                  if (hasAccess && !_playInline)
                    Positioned.fill(
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.35),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _playInline = true;
                            });
                          },
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (!hasAccess)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showLockedDialog(context),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.6),
                          child: const Center(
                            child: Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          ListTile(
            title: Text(widget.video["title"] ?? "Tutorial"),
            subtitle: Text(widget.video["description"] ?? ""),
          ),
        ],
      ),
    );
  }

  void _showLockedDialog(BuildContext context) {
    if (!uiLoaded) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(uiConfig["locked_title"] ?? ""),
        content: Text(uiConfig["locked_message"] ?? ""),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(uiConfig["locked_close"] ?? "Close"),
          ),
        ],
      ),
    );
  }
}
