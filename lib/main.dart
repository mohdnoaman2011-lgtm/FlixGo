// FlixGo — Flutter UI with real downloads.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const FlixGoApp());
}

class Pal {
  final Color bg, bg2, card, ink, mute, line, pink, aqua, amber, vio;
  const Pal(this.bg, this.bg2, this.card, this.ink, this.mute, this.line,
      this.pink, this.aqua, this.amber, this.vio);
}

const darkPal = Pal(Color(0xFF130E2B), Color(0xFF1D1542), Color(0xFF241B52),
    Color(0xFFF4F0FF), Color(0xFFA79FD0), Color(0xFF352A70), Color(0xFFFF6B9A),
    Color(0xFF2DD4BF), Color(0xFFFFB84D), Color(0xFF8F78FF));
const lightPal = Pal(Color(0xFFF6F3FF), Color(0xFFEBE6FF), Color(0xFFFFFFFF),
    Color(0xFF1D1640), Color(0xFF6F6894), Color(0xFFDDD6F7), Color(0xFFFF4F84),
    Color(0xFF12B5A2), Color(0xFFF59E0B), Color(0xFF6D4AFF));

/// Transparent system bars (full-screen look) with icons matching the theme.
SystemUiOverlayStyle overlayFor(bool darkBg) => SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
      statusBarIconBrightness: darkBg ? Brightness.light : Brightness.dark,
      statusBarBrightness: darkBg ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness:
          darkBg ? Brightness.light : Brightness.dark,
    );

class Plat {
  final String ar, en;
  final List<String> hosts;
  final Color c;
  final IconData icon;
  const Plat(this.ar, this.en, this.hosts, this.c, this.icon);
}

const platforms = [
  Plat('يوتيوب', 'YouTube', ['youtube.com', 'youtu.be'], Color(0xFFFF3B3B),
      Icons.play_arrow_rounded),
  Plat('إنستغرام', 'Instagram', ['instagram.com'], Color(0xFFD946EF),
      Icons.camera_alt_rounded),
  Plat('تيك توك', 'TikTok', ['tiktok.com'], Color(0xFF06B6D4),
      Icons.music_note_rounded),
  Plat('منصة X', 'X', ['x.com', 'twitter.com'], Color(0xFF6D4AFF),
      Icons.close_rounded),
  Plat('فيسبوك', 'Facebook', ['facebook.com', 'fb.com', 'fb.watch'],
      Color(0xFF3B82F6), Icons.thumb_up_alt_rounded),
];

/// Parses one piece of text into an http(s) Uri (adds https:// when missing).
Uri? parseLink(String text) {
  final s = text.trim();
  if (s.isEmpty || s.contains(RegExp(r'\s'))) return null;
  final u = Uri.tryParse(s.contains('://') ? s : 'https://$s');
  if (u == null || u.host.isEmpty) return null;
  if (u.scheme != 'http' && u.scheme != 'https') return null;
  return u;
}

/// Matches the link's real host (not just any text inside the URL).
Plat? detectPlatform(Uri? u) {
  if (u == null) return null;
  final host = u.host.toLowerCase();
  for (final p in platforms) {
    for (final h in p.hosts) {
      if (host == h || host.endsWith('.$h')) return p;
    }
  }
  return null;
}

/// Finds every supported link inside a pasted text (separated by spaces/lines).
List<Uri> extractLinks(String text) {
  final out = <Uri>[];
  for (final part in text.split(RegExp(r'\s+'))) {
    final u = parseLink(part);
    if (u == null || detectPlatform(u) == null) continue;
    if (out.any((x) => x.toString() == u.toString())) continue;
    out.add(u);
  }
  return out;
}

String fmtDur(int s) {
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

const qv = [
  ['360p', 'صغير', 'Small'],
  ['720p', 'HD', 'HD'],
  ['1080p', 'Full HD', 'Full HD'],
  ['4K', 'فائقة', 'Ultra'],
];
const qa = [
  ['128', 'kbps', 'kbps'],
  ['192', 'kbps', 'kbps'],
  ['320', 'kbps', 'kbps'],
];

const tr = {
  'ar': {
    'h1': 'حمّل ما يعجبك\nبضغطة واحدة',
    'sub': 'الصق رابطاً أو عدة روابط (كل رابط في سطر) وسنجهّزها لك.',
    'ph': 'الصق الرابط هنا', 'paste': 'لصق', 'video': '🎬 فيديو',
    'audio': '🎧 صوت فقط', 'go': 'ابدأ التحميل', 'dl': 'التحميلات',
    'newDl': 'تحميل جديد', 'none': 'لم يُكتشف رابط بعد',
    'found': 'تم اكتشاف: ', 'bad': 'الرابط غير مدعوم', 'ql': 'الجودة',
    'qa': 'جودة الصوت (MP3)', 'need': 'الصق رابطاً صالحاً أولاً',
    'started': 'بدأ التحميل ✓', 'vT': 'فيديو',
    'aT': 'مقطع صوتي', 'from': ' من ', 'vK': 'فيديو', 'aK': 'صوت',
    'mb': ' ميغابايت', 'ok': 'تم ✓',
    'empty': 'لا توجد تحميلات بعد.\nالصق رابطاً وابدأ.',
    'l0': 'ملفاتك تظهر هنا.',
    'failed': 'فشل التحميل: ',
    'saved': 'تم الحفظ في المعرض ✓',
    'saveFail': 'تعذّر الحفظ في المعرض',
    'queued': 'في الانتظار',
    'canceled': 'أُلغي التحميل',
    'delQ': 'حذف الملف من الهاتف؟',
    'yes': 'حذف',
    'no': 'إلغاء',
    'delFail': 'تعذّر حذف الملف',
    'openFail': 'لا يوجد تطبيق لفتح الملف',
    'loadingInfo': 'جارٍ جلب معلومات الفيديو…',
  },
  'en': {
    'h1': 'Download what you love\nin one tap',
    'sub': 'Paste one link or several (one per line) and we will prepare them.',
    'ph': 'Paste the link here', 'paste': 'Paste', 'video': '🎬 Video',
    'audio': '🎧 Audio only', 'go': 'Start download', 'dl': 'Downloads',
    'newDl': 'New download', 'none': 'No link detected yet',
    'found': 'Detected: ', 'bad': 'Unsupported link', 'ql': 'Quality',
    'qa': 'Audio quality (MP3)', 'need': 'Paste a valid link first',
    'started': 'Download started ✓', 'vT': 'Video',
    'aT': 'Audio clip', 'from': ' from ', 'vK': 'Video', 'aK': 'Audio',
    'mb': ' MB', 'ok': 'Done ✓',
    'empty': 'No downloads yet.\nPaste a link to start.',
    'l0': 'Your files show up here.',
    'failed': 'Download failed: ',
    'saved': 'Saved to gallery ✓',
    'saveFail': 'Could not save to gallery',
    'queued': 'Waiting in queue',
    'canceled': 'Download canceled',
    'delQ': 'Delete the file from your phone?',
    'yes': 'Delete',
    'no': 'Cancel',
    'delFail': 'Could not delete the file',
    'openFail': 'No app can open this file',
    'loadingInfo': 'Fetching video info…',
  },
};

enum St { queued, running, done, failed, cancelled }

class Item {
  final int id;
  final Plat p;
  final bool audio;
  final String q;
  final String sourceUrl;
  St st = St.queued;
  double pr = 0;
  String title = '';
  String thumb = '';
  String mime = '';
  String? mediaUri;
  String? error;
  int? bytes;
  CancelToken? token;

  Item({
    required this.id,
    required this.p,
    required this.audio,
    required this.q,
    required this.sourceUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pi': platforms.indexOf(p),
        'audio': audio,
        'q': q,
        'src': sourceUrl,
        'title': title,
        'thumb': thumb,
        'mime': mime,
        'uri': mediaUri,
        'bytes': bytes,
      };

  factory Item.fromJson(Map<String, dynamic> j) {
    final it = Item(
      id: (j['id'] as num).toInt(),
      p: platforms[(j['pi'] as num).toInt()],
      audio: j['audio'] == true,
      q: j['q'] as String,
      sourceUrl: j['src'] as String,
    );
    it.st = St.done;
    it.pr = 100;
    it.title = (j['title'] as String?) ?? '';
    it.thumb = (j['thumb'] as String?) ?? '';
    it.mime = (j['mime'] as String?) ?? '';
    it.mediaUri = j['uri'] as String?;
    it.bytes = (j['bytes'] as num?)?.toInt();
    return it;
  }
}

class CancelToken {
  bool cancelled = false;
  HttpClient? _client;
  void cancel() {
    cancelled = true;
    _client?.close(force: true);
  }
}

class CancelledException implements Exception {
  const CancelledException();
}

class DownloadResult {
  final String path, name, title;
  const DownloadResult(this.path, this.name, this.title);
}

/// Connects the UI to the download server.
/// Configure with:
/// flutter run --dart-define=FLIXGO_API_BASE_URL=https://your-api.example.com
class DownloadService {
  static const apiBaseUrl = String.fromEnvironment(
    'FLIXGO_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8787',
  );

  static const _media = MethodChannel('flixgo/media');

  static String mimeOf(String name, bool audio) {
    final ext = name.split('.').last.toLowerCase();
    const types = {
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
    };
    return types[ext] ?? (audio ? 'audio/mpeg' : 'video/mp4');
  }

  static Future<String?> saveToGallery(
      String path, String name, bool audio) async {
    return _media.invokeMethod<String>('saveToGallery', {
      'path': path,
      'name': name,
      'mime': mimeOf(name, audio),
      'audio': audio,
    });
  }

  static Future<bool> _call(String method, Map<String, dynamic> args) async {
    try {
      return (await _media.invokeMethod<bool>(method, args)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> open(String uri, String mime) =>
      _call('open', {'uri': uri, 'mime': mime});
  static Future<bool> share(String uri, String mime) =>
      _call('share', {'uri': uri, 'mime': mime});
  static Future<bool> delete(String uri) => _call('delete', {'uri': uri});

  /// Keeps the screen awake while the in-app player is open.
  static Future<void> keepScreenOn(bool on) async {
    try {
      await _media.invokeMethod<bool>('keepScreenOn', {'on': on});
    } catch (_) {}
  }

  /// Returns true when unsure, so history is never wiped by a failed check.
  static Future<bool> exists(String uri) async {
    try {
      return (await _media.invokeMethod<bool>('exists', {'uri': uri})) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<Map<String, dynamic>> info(String sourceUrl) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(Uri.parse('$apiBaseUrl/api/info'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'url': sourceUrl}));
      final res = await req.close().timeout(const Duration(seconds: 45));
      final body = await utf8.decoder.bind(res).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(_serverMessage(body, res.statusCode));
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  static Future<DownloadResult> download({
    required String sourceUrl,
    required String quality,
    required bool audio,
    required CancelToken token,
    required void Function(double progress) onProgress,
  }) async {
    final api = Uri.parse('$apiBaseUrl/api/download');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    token._client = client;
    File? target;
    try {
      if (token.cancelled) throw const CancelledException();
      final request = await client.postUrl(api);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'url': sourceUrl,
        'quality': quality,
        'audioOnly': audio,
      }));
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_serverMessage(body, response.statusCode));
      }

      final payload = jsonDecode(body) as Map<String, dynamic>;
      final directUrl = payload['downloadUrl'] as String?;
      if (directUrl == null || directUrl.isEmpty) {
        throw Exception('The server did not return downloadUrl');
      }

      final fileName = _safeName(
        (payload['fileName'] as String?) ??
            'flixgo_${DateTime.now().millisecondsSinceEpoch}.${audio ? 'mp3' : 'mp4'}',
      );
      final title = (payload['title'] as String?) ?? '';
      final directory = await getApplicationDocumentsDirectory();
      final downloads = Directory('${directory.path}/FlixGo/Downloads');
      await downloads.create(recursive: true);
      final dot = fileName.lastIndexOf('.');
      final ext = dot >= 0 ? fileName.substring(dot) : '';
      // Unique temp name so two downloads with the same title never clash.
      final file = File(
          '${downloads.path}/${DateTime.now().microsecondsSinceEpoch}$ext');
      target = file;

      final mediaRequest = await client.getUrl(Uri.parse(directUrl));
      final mediaResponse = await mediaRequest.close();
      if (mediaResponse.statusCode < 200 || mediaResponse.statusCode >= 300) {
        throw Exception('Media server returned ${mediaResponse.statusCode}');
      }
      final total = mediaResponse.contentLength;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in mediaResponse) {
          if (token.cancelled) throw const CancelledException();
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total * 100);
        }
      } finally {
        await sink.close();
      }
      onProgress(100);
      return DownloadResult(file.path, fileName, title);
    } catch (_) {
      final partial = target;
      if (partial != null && partial.existsSync()) partial.deleteSync();
      if (token.cancelled) throw const CancelledException();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static String _serverMessage(String body, int status) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['error'] ?? json['message'] ?? 'HTTP $status').toString();
    } catch (_) {
      return 'HTTP $status';
    }
  }

  static String _safeName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
    return cleaned.trim().isEmpty ? 'flixgo_download.bin' : cleaned.trim();
  }
}

/// Keeps finished downloads between app launches (a small JSON file).
class HistoryStore {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/flixgo_history.json');
  }

  static Future<List<Item>> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return [];
      final data = jsonDecode(await f.readAsString());
      final out = <Item>[];
      for (final e in (data as List)) {
        try {
          out.add(Item.fromJson(e as Map<String, dynamic>));
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(List<Item> items) async {
    try {
      final done = items
          .where((i) => i.st == St.done && i.mediaUri != null)
          .take(100)
          .map((i) => i.toJson())
          .toList();
      await (await _file()).writeAsString(jsonEncode(done));
    } catch (_) {}
  }
}

class FlixGoApp extends StatelessWidget {
  const FlixGoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FlixGo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Tajawal'),
        // Keeps the layout intact even with a very large/small system font.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  static const maxActive = 2;

  bool ar = true, dark = true, audio = false, err = false;
  int tab = 0, vq = 1, aq = 1;
  final url = TextEditingController();
  final items = <Item>[];
  int _nextId = DateTime.now().millisecondsSinceEpoch;

  // Link preview state
  Timer? _debounce;
  int _previewSeq = 0;
  String? previewUrl;
  Map<String, dynamic>? preview;
  bool previewLoading = false;

  Pal get c => dark ? darkPal : lightPal;
  String t(String k) => tr[ar ? 'ar' : 'en']![k]!;
  String pn(Plat p) => ar ? p.ar : p.en;
  List<Uri> get links => extractLinks(url.text);

  // ---------- responsive helpers ----------
  /// Width of the content column (phones: full width, big screens: 600).
  double get contentW {
    final w = MediaQuery.sizeOf(context).width;
    return w > 600 ? 600.0 : w;
  }

  /// Scale factor for headline sizes (small phones shrink, big ones grow).
  double get k => (contentW / 390).clamp(0.88, 1.15).toDouble();

  /// Side padding that adapts to the screen width.
  double get pad => contentW < 360 ? 14.0 : (contentW < 600 ? 18.0 : 24.0);

  /// Height of the system gesture/navigation bar at the bottom.
  double get bottomInset => MediaQuery.viewPaddingOf(context).bottom;

  String displayTitle(Item i) => i.title.isNotEmpty
      ? i.title
      : '${t(i.audio ? 'aT' : 'vT')}${t('from')}${pn(i.p)}';
  String size(Item i) =>
      '${((i.bytes ?? 0) / 1048576).toStringAsFixed(1)}${t('mb')}';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    url.dispose();
    super.dispose();
  }

  void toast(String m) {
    final s = ScaffoldMessenger.of(context);
    s.hideCurrentSnackBar();
    s.showSnackBar(SnackBar(
      content: Text(m,
          style: TextStyle(color: c.bg, fontWeight: FontWeight.w700)),
      backgroundColor: c.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ---------- history ----------
  Future<void> _loadHistory() async {
    final saved = await HistoryStore.load();
    final alive = <Item>[];
    for (final i in saved) {
      final u = i.mediaUri;
      if (u != null && await DownloadService.exists(u)) alive.add(i);
    }
    if (!mounted) return;
    setState(() => items.addAll(alive));
    if (alive.length != saved.length) _persist();
  }

  void _persist() {
    HistoryStore.save(items);
  }

  // ---------- link preview ----------
  void _onUrlChanged() {
    final ls = links;
    if (ls.length == 1 && ls.first.toString() == previewUrl) {
      setState(() {});
      return;
    }
    _debounce?.cancel();
    final seq = ++_previewSeq;
    if (ls.length != 1) {
      setState(() {
        preview = null;
        previewLoading = false;
        previewUrl = null;
      });
      return;
    }
    final u = ls.first.toString();
    setState(() {
      preview = null;
      previewLoading = true;
      previewUrl = u;
    });
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _loadPreview(u, seq);
    });
  }

  Future<void> _loadPreview(String u, int seq) async {
    try {
      final info = await DownloadService.info(u);
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        preview = info;
        previewLoading = false;
      });
    } catch (_) {
      if (!mounted || seq != _previewSeq) return;
      setState(() {
        preview = null;
        previewLoading = false;
      });
    }
  }

  Future<void> paste() async {
    final d = await Clipboard.getData('text/plain');
    if (!mounted) return;
    final txt = (d?.text ?? '').trim();
    if (txt.isEmpty) {
      toast(t('need'));
      return;
    }
    url.text = txt;
    _onUrlChanged();
  }

  // ---------- download queue ----------
  void start() {
    final ls = links;
    if (ls.isEmpty) {
      setState(() => err = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => err = false);
      });
      toast(t('need'));
      return;
    }

    final qq = audio ? qa[aq] : qv[vq];
    final q = audio ? '${qq[0]} kbps' : qq[0];
    final pv = ls.length == 1 ? preview : null;
    final created = <Item>[];
    for (final u in ls) {
      final it = Item(
        id: _nextId++,
        p: detectPlatform(u)!,
        audio: audio,
        q: q,
        sourceUrl: u.toString(),
      );
      if (pv != null) {
        it.title = (pv['title'] ?? '').toString();
        it.thumb = (pv['thumbnail'] ?? '').toString();
      }
      created.add(it);
    }

    _debounce?.cancel();
    _previewSeq++;
    setState(() {
      items.insertAll(0, created);
      url.clear();
      preview = null;
      previewLoading = false;
      previewUrl = null;
      tab = 1;
    });
    toast(t('started'));
    _pump();
  }

  void _pump() {
    if (!mounted) return;
    var running = items.where((i) => i.st == St.running).length;
    final queued = items.where((i) => i.st == St.queued).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final it in queued) {
      if (running >= maxActive) break;
      running++;
      _run(it);
    }
  }

  Future<void> _run(Item it) async {
    final token = CancelToken();
    setState(() {
      it.st = St.running;
      it.pr = 0;
      it.error = null;
      it.token = token;
    });
    try {
      final r = await DownloadService.download(
        sourceUrl: it.sourceUrl,
        quality: it.q,
        audio: it.audio,
        token: token,
        onProgress: (value) {
          if (mounted) setState(() => it.pr = value.clamp(0, 100).toDouble());
        },
      );
      final bytes = await File(r.path).length();
      String? uri;
      try {
        uri = await DownloadService.saveToGallery(r.path, r.name, it.audio);
      } catch (_) {}
      try {
        await File(r.path).delete();
      } catch (_) {}
      if (uri == null) throw Exception(t('saveFail'));
      if (!mounted) return;
      setState(() {
        it.st = St.done;
        it.pr = 100;
        it.bytes = bytes;
        it.mediaUri = uri;
        it.mime = DownloadService.mimeOf(r.name, it.audio);
        if (it.title.isEmpty && r.title.isNotEmpty) it.title = r.title;
        it.token = null;
      });
      _persist();
      toast(t('saved'));
    } on CancelledException {
      if (!mounted) return;
      setState(() {
        it.st = St.cancelled;
        it.token = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        it.st = St.failed;
        it.error = e.toString().replaceFirst('Exception: ', '');
        it.token = null;
      });
      toast('${t('failed')}${it.error}');
    } finally {
      _pump();
    }
  }

  void cancel(Item i) {
    if (i.st == St.running) {
      i.token?.cancel();
    } else if (i.st == St.queued) {
      setState(() => i.st = St.cancelled);
    }
  }

  void retry(Item i) {
    setState(() {
      i.st = St.queued;
      i.error = null;
      i.pr = 0;
    });
    _pump();
  }

  void removeItem(Item i) {
    setState(() => items.remove(i));
    _persist();
  }

  String _mimeOf(Item i) =>
      i.mime.isNotEmpty ? i.mime : (i.audio ? 'audio/mpeg' : 'video/mp4');

  /// Opens the built-in player on the tapped file (playlist = same kind).
  void playItem(Item i) {
    final same = items
        .where((x) =>
            x.st == St.done && x.mediaUri != null && x.audio == i.audio)
        .toList();
    final idx = same.indexOf(i);
    if (idx < 0) return;
    final tracks = [
      for (final x in same)
        Track(
          title: displayTitle(x),
          subtitle: '${pn(x.p)} · ${x.q}',
          uri: x.mediaUri!,
          mime: _mimeOf(x),
          thumb: x.thumb,
          audio: x.audio,
        ),
    ];
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          PlayerPage(tracks: tracks, start: idx, pal: c, ar: ar),
    ));
  }

  Future<void> openExternal(Item i) async {
    final u = i.mediaUri;
    if (u == null) return;
    final ok = await DownloadService.open(u, _mimeOf(i));
    if (!ok && mounted) toast(t('openFail'));
  }

  Future<void> shareItem(Item i) async {
    final u = i.mediaUri;
    if (u == null) return;
    final ok = await DownloadService.share(u, _mimeOf(i));
    if (!ok && mounted) toast(t('openFail'));
  }

  Future<void> deleteItem(Item i) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: c.card,
          title: Text(t('delQ'),
              style: TextStyle(
                  color: c.ink, fontSize: 16, fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('no'), style: TextStyle(color: c.mute))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('yes'), style: TextStyle(color: c.pink))),
          ],
        ),
      ),
    );
    if (yes != true || !mounted) return;
    final u = i.mediaUri;
    if (u != null) {
      final deleted = await DownloadService.delete(u);
      if (!deleted && await DownloadService.exists(u)) {
        if (mounted) toast(t('delFail'));
        return;
      }
    }
    if (!mounted) return;
    removeItem(i);
  }

  // ---------- widgets ----------
  Widget sq(Widget ch, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.line, width: 1.5)),
          child: ch,
        ),
      );

  Widget header() => Padding(
        padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [c.pink, c.vio])),
            child: const Icon(Icons.graphic_eq_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text('FlixGo',
              style: TextStyle(
                  color: c.ink, fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          sq(
              Text(ar ? 'EN' : 'ع',
                  style: TextStyle(
                      color: c.ink, fontWeight: FontWeight.w800, fontSize: 13)),
              () => setState(() => ar = !ar)),
          const SizedBox(width: 8),
          sq(
              Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: c.ink, size: 19),
              () => setState(() => dark = !dark)),
        ]),
      );

  Widget seg(String k, bool a) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => audio = a),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: audio == a ? Colors.white : c.mute),
              child: Text(t(k)),
            ),
          ),
        ),
      );

  Widget previewCard() {
    if (previewLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.aqua)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t('loadingInfo'),
                style: TextStyle(color: c.mute, fontSize: 13)),
          ),
        ]),
      );
    }
    final pv = preview;
    if (pv == null) return const SizedBox.shrink();
    final title = (pv['title'] ?? '').toString();
    final thumbUrl = (pv['thumbnail'] ?? '').toString();
    final by = (pv['uploader'] ?? '').toString();
    final dur = (pv['duration'] as num?)?.toInt() ?? 0;
    final meta = [by, if (dur > 0) fmtDur(dur)].where((s) => s.isNotEmpty);
    Widget ph() => Container(
        color: c.bg2, child: Icon(Icons.movie_rounded, color: c.mute));
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line, width: 1.5)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 96 * k,
            height: 60 * k,
            child: thumbUrl.isEmpty
                ? ph()
                : Image.network(thumbUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) => ph()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title.isEmpty ? '—' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(meta.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.mute, fontSize: 12)),
              ]),
        ),
      ]),
    );
  }

  Widget downloadPage() {
    final ls = links;
    final qs = audio ? qa : qv;
    final sel = audio ? aq : vq;
    final single = ls.length == 1 ? detectPlatform(ls.first) : null;
    final label = ls.isEmpty
        ? (url.text.trim().isEmpty ? t('none') : t('bad'))
        : ls.length == 1
            ? '${t('found')}${pn(single!)}'
            : (ar ? '${ls.length} روابط جاهزة' : '${ls.length} links ready');
    final dot = single?.c ?? (ls.isNotEmpty ? c.aqua : c.line);
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 22, pad, 110 + bottomInset),
      children: [
        Text(t('h1'),
            style: TextStyle(
                color: c.ink,
                fontSize: 28 * k,
                fontWeight: FontWeight.w800,
                height: 1.25)),
        const SizedBox(height: 6),
        Text(t('sub'), style: TextStyle(color: c.mute, fontSize: 14)),
        const SizedBox(height: 22),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: err ? c.pink : c.line, width: 1.5)),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: url,
                  onChanged: (_) => _onUrlChanged(),
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 4,
                  textDirection: url.text.isEmpty ? null : TextDirection.ltr,
                  style: TextStyle(color: c.ink, fontSize: 15),
                  decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: t('ph'),
                      hintStyle: TextStyle(color: c.mute)),
                ),
              ),
              GestureDetector(
                onTap: paste,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                      color: c.bg2, borderRadius: BorderRadius.circular(12)),
                  child: Text(t('paste'),
                      style: TextStyle(
                          color: c.vio, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: TextStyle(color: c.mute, fontSize: 13)),
              ),
            ]),
          ]),
        ),
        previewCard(),
        const SizedBox(height: 18),
        Container(
          height: 54 * k,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: c.bg2, borderRadius: BorderRadius.circular(18)),
          child: Stack(children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional(audio ? 1 : -1, 0),
              child: FractionallySizedBox(
                widthFactor: .5,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: [c.vio, c.pink])),
                ),
              ),
            ),
            Row(children: [seg('video', false), seg('audio', true)]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Text(audio ? t('qa') : t('ql'),
              style: TextStyle(
                  color: c.ink, fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Wrap(spacing: 9, runSpacing: 9, children: [
          for (var i = 0; i < qs.length; i++)
            GestureDetector(
              onTap: () => setState(() {
                if (audio) {
                  aq = i;
                } else {
                  vq = i;
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                    color: sel == i ? c.aqua.withAlpha(40) : c.card,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: sel == i ? c.aqua : c.line, width: 1.5)),
                child: Text.rich(TextSpan(
                    text: qs[i][0],
                    style: TextStyle(
                        color: c.ink,
                        fontWeight:
                            sel == i ? FontWeight.w700 : FontWeight.w500),
                    children: [
                      TextSpan(
                          text: '  ${qs[i][ar ? 1 : 2]}',
                          style: TextStyle(
                              color: c.mute,
                              fontSize: 12,
                              fontWeight: FontWeight.w400))
                    ])),
              ),
            ),
        ]),
        const SizedBox(height: 26),
        GestureDetector(
          onTap: start,
          child: Container(
            height: 58 * k,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(colors: [c.pink, c.amber]),
                boxShadow: [
                  BoxShadow(
                      color: c.pink.withAlpha(100),
                      blurRadius: 26,
                      offset: const Offset(0, 10))
                ]),
            child: Text(t('go'),
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17 * k,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget iconBox(Item i) => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [i.p.c, c.vio])),
        child: Icon(i.audio ? Icons.music_note_rounded : i.p.icon,
            color: Colors.white),
      );

  Widget thumbRaw(Item i) {
    if (i.thumb.isEmpty) return iconBox(i);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 54,
        height: 54,
        child: Image.network(i.thumb,
            fit: BoxFit.cover, errorBuilder: (ctx, e, st) => iconBox(i)),
      ),
    );
  }

  /// Thumbnail; for finished files it shows a play badge and opens the player.
  Widget thumbBox(Item i) {
    final base = thumbRaw(i);
    if (i.st != St.done) return base;
    return GestureDetector(
      onTap: () => playItem(i),
      child: Stack(alignment: Alignment.center, children: [
        base,
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
              color: Colors.black54, shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow_rounded,
              color: Colors.white, size: 18),
        ),
      ]),
    );
  }

  Widget act(IconData icon, VoidCallback f, {Color? color}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: f,
        child: Container(
          width: 36,
          height: 30,
          margin: const EdgeInsetsDirectional.only(end: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: c.bg2, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color ?? c.ink),
        ),
      );

  List<Widget> acts(Item i) {
    if (i.st == St.done) {
      return [
        act(Icons.play_circle_outline_rounded, () => playItem(i),
            color: c.aqua),
        act(Icons.share_rounded, () => shareItem(i)),
        act(Icons.open_in_new_rounded, () => openExternal(i)),
        act(Icons.delete_outline_rounded, () => deleteItem(i), color: c.pink),
      ];
    }
    if (i.st == St.failed || i.st == St.cancelled) {
      return [
        act(Icons.refresh_rounded, () => retry(i)),
        act(Icons.delete_outline_rounded, () => removeItem(i), color: c.pink),
      ];
    }
    return [act(Icons.close_rounded, () => cancel(i), color: c.pink)];
  }

  Widget card(Item i) {
    final failed = i.st == St.failed;
    final running = i.st == St.running;
    final queued = i.st == St.queued;
    final done = i.st == St.done;
    final canceled = i.st == St.cancelled;
    final mid = <String>[
      pn(i.p),
      t(i.audio ? 'aK' : 'vK'),
      i.q,
      if (i.bytes != null) size(i),
    ];
    String status;
    if (failed) {
      status = '!';
    } else if (done) {
      status = t('ok');
    } else if (running) {
      status = '${i.pr.floor()}%';
    } else if (queued) {
      status = '…';
    } else {
      status = '—';
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: failed ? c.pink : c.line, width: 1.5)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        thumbBox(i),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(displayTitle(i),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(mid.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.mute, fontSize: 12.5)),
            const SizedBox(height: 8),
            if (failed) ...[
              Text(i.error ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.pink, fontSize: 11.5)),
              const SizedBox(height: 8),
            ] else if (running) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                    value: i.pr > 0 ? i.pr / 100 : null,
                    minHeight: 7,
                    backgroundColor: c.bg2,
                    color: c.aqua),
              ),
              const SizedBox(height: 8),
            ] else if (queued) ...[
              Text(t('queued'),
                  style: TextStyle(color: c.mute, fontSize: 12)),
              const SizedBox(height: 8),
            ] else if (canceled) ...[
              Text(t('canceled'),
                  style: TextStyle(color: c.mute, fontSize: 12)),
              const SizedBox(height: 8),
            ],
            // Wrap: buttons drop to a second line on narrow phones.
            Wrap(runSpacing: 6, children: acts(i)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(status,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: failed ? c.pink : done ? c.aqua : c.ink,
                  fontSize: 13,
                  fontWeight: done || failed ? FontWeight.w700 : FontWeight.w400)),
        ),
      ]),
    );
  }

  Widget listPage() {
    final n = items.length;
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 22, pad, 110 + bottomInset),
      children: [
        Text(t('dl'),
            style: TextStyle(
                color: c.ink, fontSize: 28 * k, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
            n == 0
                ? t('l0')
                : ar
                    ? '$n ملف'
                    : '$n file${n == 1 ? '' : 's'}',
            style: TextStyle(color: c.mute, fontSize: 14)),
        if (n == 0)
          Padding(
            padding: const EdgeInsets.only(top: 70),
            child: Column(children: [
              Icon(Icons.inbox_rounded, size: 54, color: c.mute),
              const SizedBox(height: 10),
              Text(t('empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.mute, height: 1.5)),
            ]),
          ),
        for (final i in items) card(i),
      ],
    );
  }

  Widget navBtn(int i, String label, int badge) => Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
                color: tab == i ? c.bg2 : Colors.transparent,
                borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: tab == i ? c.vio : c.mute,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
              if (badge > 0)
                Container(
                  margin: const EdgeInsetsDirectional.only(start: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: c.pink, borderRadius: BorderRadius.circular(9)),
                  child: Text('$badge',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                ),
            ]),
          ),
        ),
      );

  Widget nav() => Positioned(
        left: pad,
        right: pad,
        bottom: 14 + bottomInset,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.line, width: 1.5),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x40140A3C),
                    blurRadius: 30,
                    offset: Offset(0, 12))
              ]),
          child: Row(children: [
            navBtn(0, t('newDl'), 0),
            navBtn(1, t('dl'), items.length),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(dark),
      child: Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: c.bg,
          body: Container(
            decoration: BoxDecoration(
                gradient: RadialGradient(
                    center: const Alignment(.7, -1.1),
                    radius: 1.3,
                    colors: [c.bg2, c.bg])),
            // bottom: false -> the background reaches the very bottom edge.
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Stack(children: [
                    Column(children: [
                      header(),
                      Expanded(child: tab == 0 ? downloadPage() : listPage()),
                    ]),
                    if (!keyboard) nav(),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}