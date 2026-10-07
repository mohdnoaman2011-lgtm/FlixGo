// FlixGo — Flutter UI with real downloads.
// Usage: flutter create flixgo, then replace lib/main.dart with this file.
// Add path_provider to pubspec.yaml; see README.md.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const FlixGoApp());

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

/// Parses user text into an http(s) Uri (adds https:// when missing).
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
    'sub': 'الصق رابط الفيديو وسنجهّزه لك بالجودة التي تريدها.',
    'ph': 'الصق الرابط هنا', 'paste': 'لصق', 'video': '🎬 فيديو',
    'audio': '🎧 صوت فقط', 'go': 'ابدأ التحميل', 'dl': 'التحميلات',
    'newDl': 'تحميل جديد', 'none': 'لم يُكتشف رابط بعد',
    'found': 'تم اكتشاف: ', 'bad': 'الرابط غير مدعوم', 'ql': 'الجودة',
    'qa': 'جودة الصوت (MP3)', 'need': 'الصق رابطاً صالحاً أولاً',
    'started': 'بدأ التحميل ✓', 'done': 'اكتمل: ', 'vT': 'فيديو',
    'aT': 'مقطع صوتي', 'from': ' من ', 'vK': 'فيديو', 'aK': 'صوت',
    'mb': ' ميغابايت', 'ok': 'تم ✓',
    'empty': 'لا توجد تحميلات بعد.\nالصق رابطاً وابدأ.',
    'l0': 'ملفاتك تظهر هنا.',
    'failed': 'فشل التحميل: ',
    'saved': 'تم الحفظ في المعرض ✓',
    'saveFail': 'تم التحميل لكن تعذّر الحفظ في المعرض',
  },
  'en': {
    'h1': 'Download what you love\nin one tap',
    'sub': "Paste a video link and we'll prepare it in the quality you want.",
    'ph': 'Paste the link here', 'paste': 'Paste', 'video': '🎬 Video',
    'audio': '🎧 Audio only', 'go': 'Start download', 'dl': 'Downloads',
    'newDl': 'New download', 'none': 'No link detected yet',
    'found': 'Detected: ', 'bad': 'Unsupported link', 'ql': 'Quality',
    'qa': 'Audio quality (MP3)', 'need': 'Paste a valid link first',
    'started': 'Download started ✓', 'done': 'Finished: ', 'vT': 'Video',
    'aT': 'Audio clip', 'from': ' from ', 'vK': 'Video', 'aK': 'Audio',
    'mb': ' MB', 'ok': 'Done ✓',
    'empty': 'No downloads yet.\nPaste a link to start.',
    'l0': 'Your files show up here.',
    'failed': 'Download failed: ',
    'saved': 'Saved to gallery ✓',
    'saveFail': 'Downloaded, but saving to gallery failed',
  },
};

class Item {
  final Plat p;
  final bool audio;
  final String q;
  double pr = 0;
  bool downloading = true;
  String? filePath;
  String? error;
  int? bytes;
  Item(this.p, this.audio, this.q);
}

/// Connects the UI to a real download/resolver server.
///
/// The server receives a social-media URL and returns a direct media URL.
/// Configure it with:
/// flutter run --dart-define=FLIXGO_API_BASE_URL=https://your-api.example.com
class DownloadService {
  static const apiBaseUrl = String.fromEnvironment(
    'FLIXGO_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8787',
  );

  static const _media = MethodChannel('flixgo/media');

  static String _mime(String path, bool audio) {
    final ext = path.split('.').last.toLowerCase();
    const types = {
      'mp4': 'video/mp4',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
    };
    return types[ext] ?? (audio ? 'audio/mpeg' : 'video/mp4');
  }

  /// Copies the downloaded file into the phone gallery / music library.
  static Future<void> saveToGallery(String path, bool audio) async {
    await _media.invokeMethod<String>('saveToGallery', {
      'path': path,
      'name': path.split('/').last,
      'mime': _mime(path, audio),
      'audio': audio,
    });
  }

  static Future<String> download({
    required String sourceUrl,
    required String quality,
    required bool audio,
    required void Function(double progress) onProgress,
  }) async {
    final api = Uri.parse('$apiBaseUrl/api/download');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    File? target;
    try {
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
      final directory = await getApplicationDocumentsDirectory();
      final downloads = Directory('${directory.path}/FlixGo/Downloads');
      await downloads.create(recursive: true);
      final file = File('${downloads.path}/$fileName');
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
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total * 100);
        }
      } finally {
        await sink.close();
      }
      onProgress(100);
      return file.path;
    } catch (_) {
      final partial = target;
      if (partial != null && partial.existsSync()) partial.deleteSync();
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

class FlixGoApp extends StatelessWidget {
  const FlixGoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FlixGo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Tajawal'),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool ar = true, dark = true, audio = false, err = false;
  int tab = 0, vq = 1, aq = 1;
  final url = TextEditingController();
  final items = <Item>[];

  Pal get c => dark ? darkPal : lightPal;
  String t(String k) => tr[ar ? 'ar' : 'en']![k]!;
  String pn(Plat p) => ar ? p.ar : p.en;
  Plat? get plat => detectPlatform(parseLink(url.text));

  String title(Item i) => '${t(i.audio ? 'aT' : 'vT')}${t('from')}${pn(i.p)}';
  String size(Item i) => i.bytes == null
      ? '—'
      : '${(i.bytes! / 1048576).toStringAsFixed(1)}${t('mb')}';

  @override
  void dispose() {
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

  Future<void> paste() async {
    final d = await Clipboard.getData('text/plain');
    if (!mounted) return;
    final txt = (d?.text ?? '').trim();
    if (txt.isEmpty) {
      toast(t('need'));
      return;
    }
    setState(() => url.text = txt);
  }

  Future<void> start() async {
    final p = plat;
    if (p == null) {
      setState(() => err = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => err = false);
      });
      toast(t('need'));
      return;
    }

    final sourceUrl = parseLink(url.text)?.toString() ?? url.text.trim();
    final qq = audio ? qa[aq] : qv[vq];
    final it = Item(p, audio, audio ? '${qq[0]} kbps' : qq[0]);
    setState(() {
      items.insert(0, it);
      url.clear();
      tab = 1;
    });
    toast(t('started'));

    try {
      final path = await DownloadService.download(
        sourceUrl: sourceUrl,
        quality: it.q,
        audio: it.audio,
        onProgress: (value) {
          if (mounted) setState(() => it.pr = value.clamp(0, 100).toDouble());
        },
      );
      final bytes = await File(path).length();
      var saved = false;
      try {
        await DownloadService.saveToGallery(path, it.audio);
        saved = true;
        await File(path).delete();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        it.pr = 100;
        it.downloading = false;
        it.filePath = path;
        it.bytes = bytes;
      });
      toast(saved ? t('saved') : t('saveFail'));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        it.downloading = false;
        it.error = e.toString().replaceFirst('Exception: ', '');
      });
      toast('${t('failed')}${it.error}');
    }
  }

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
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
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

  Widget downloadPage() {
    final p = plat;
    final qs = audio ? qa : qv;
    final sel = audio ? aq : vq;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 110),
      children: [
        Text(t('h1'),
            style: TextStyle(
                color: c.ink,
                fontSize: 28,
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
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.url,
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
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: p?.c ?? c.line),
              ),
              const SizedBox(width: 8),
              Text(
                  p != null
                      ? '${t('found')}${pn(p)}'
                      : url.text.isEmpty
                          ? t('none')
                          : t('bad'),
                  style: TextStyle(color: c.mute, fontSize: 13)),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        Container(
          height: 54,
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
            height: 58,
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
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget card(Item i) {
    final done = i.filePath != null;
    final failed = i.error != null;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: failed ? c.pink : c.line, width: 1.5)),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [i.p.c, c.vio])),
          child: Icon(i.audio ? Icons.music_note_rounded : i.p.icon,
              color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title(i),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${t(i.audio ? 'aK' : 'vK')} · ${i.q} · ${size(i)}',
                style: TextStyle(color: c.mute, fontSize: 12.5)),
            const SizedBox(height: 8),
            if (failed)
              Text(i.error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.pink, fontSize: 11.5))
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                    value: done ? 1 : (i.pr > 0 ? i.pr / 100 : null),
                    minHeight: 7,
                    backgroundColor: c.bg2,
                    color: c.aqua),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(failed ? '!' : done ? t('ok') : '${i.pr.floor()}%',
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
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 110),
      children: [
        Text(t('dl'),
            style: TextStyle(
                color: c.ink, fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
            n == 0
                ? t('l0')
                : ar
                    ? '$n ملف في هذه الجلسة'
                    : '$n file${n == 1 ? '' : 's'} this session',
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
              Text(label,
                  style: TextStyle(
                      color: tab == i ? c.vio : c.mute,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
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
        left: 18,
        right: 18,
        bottom: 14,
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
  Widget build(BuildContext context) => Directionality(
        textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: c.bg,
          body: Container(
            decoration: BoxDecoration(
                gradient: RadialGradient(
                    center: const Alignment(.7, -1.1),
                    radius: 1.3,
                    colors: [c.bg2, c.bg])),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Stack(children: [
                    Column(children: [
                      header(),
                      Expanded(child: tab == 0 ? downloadPage() : listPage()),
                    ]),
                    nav(),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}