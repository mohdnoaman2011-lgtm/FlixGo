// FlixGo — in-app media player (audio + video).
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'main.dart';

class Track {
  final String title, subtitle, uri, mime, thumb;
  final bool audio;
  const Track({
    required this.title,
    required this.subtitle,
    required this.uri,
    required this.mime,
    required this.thumb,
    required this.audio,
  });
}

class PlayerPage extends StatefulWidget {
  final List<Track> tracks;
  final int start;
  final Pal pal;
  final bool ar;
  const PlayerPage({
    super.key,
    required this.tracks,
    required this.start,
    required this.pal,
    required this.ar,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  VideoPlayerController? _ctl;
  late int index;
  bool loading = true;
  String? error;
  bool controls = true;
  bool landscape = false;
  bool repeat = false;
  bool dragging = false;
  double dragValue = 0;
  double speed = 1.0;
  Timer? _hide;
  Timer? _hintTimer;
  String? _hint;
  int _loadSeq = 0;
  bool _handledEnd = false;
  double _tapX = 0;

  Pal get c => widget.pal;
  Track get track => widget.tracks[index];
  bool get isAudio => track.audio;
  Color get fg => isAudio ? c.ink : Colors.white;
  String s(String ar, String en) => widget.ar ? ar : en;

  @override
  void initState() {
    super.initState();
    index = widget.start.clamp(0, widget.tracks.length - 1).toInt();
    WidgetsBinding.instance.addObserver(this);
    DownloadService.keepScreenOn(true);
    if (isAudio) {
      SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.portraitUp]);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hide?.cancel();
    _hintTimer?.cancel();
    _ctl?.removeListener(_onTick);
    _ctl?.dispose();
    DownloadService.keepScreenOn(false);
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !isAudio) {
      _ctl?.pause();
    }
  }

  // ---------- loading ----------
  Future<void> _load() async {
    final seq = ++_loadSeq;
    final old = _ctl;
    old?.removeListener(_onTick);
    if (!mounted) return;
    setState(() {
      _ctl = null;
      loading = true;
      error = null;
      _handledEnd = false;
      controls = true;
    });
    if (old != null) {
      await WidgetsBinding.instance.endOfFrame;
      await old.dispose();
    }
    if (!mounted || seq != _loadSeq) return;
    final t = track;
    final ctl = t.uri.startsWith('content://')
        ? VideoPlayerController.contentUri(Uri.parse(t.uri))
        : VideoPlayerController.file(File(t.uri));
    try {
      await ctl.initialize();
      if (!mounted || seq != _loadSeq) {
        await ctl.dispose();
        return;
      }
      await ctl.setPlaybackSpeed(speed);
      await ctl.setLooping(repeat);
      ctl.addListener(_onTick);
      setState(() {
        _ctl = ctl;
        loading = false;
      });
      await ctl.play();
      _scheduleHide();
    } catch (e) {
      try {
        await ctl.dispose();
      } catch (_) {}
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  void _onTick() {
    final v = _ctl?.value;
    if (v == null || !mounted) return;
    if (v.hasError && error == null) {
      setState(() => error = v.errorDescription ?? 'Playback error');
      return;
    }
    if (!repeat &&
        !_handledEnd &&
        v.duration > Duration.zero &&
        v.position >= v.duration &&
        !v.isPlaying) {
      _handledEnd = true;
      if (index < widget.tracks.length - 1) {
        _go(1);
      } else {
        setState(() => controls = true);
      }
      return;
    }
    setState(() {});
  }

  void _go(int d) {
    final n = index + d;
    if (n < 0 || n >= widget.tracks.length) return;
    index = n;
    _load();
  }

  // ---------- controls ----------
  void _scheduleHide() {
    _hide?.cancel();
    if (isAudio) return;
    final ctl = _ctl;
    if (ctl == null || !ctl.value.isPlaying) return;
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && !dragging) setState(() => controls = false);
    });
  }

  void _showHint(String text) {
    _hintTimer?.cancel();
    setState(() => _hint = text);
    _hintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _hint = null);
    });
  }

  Future<void> _toggle() async {
    final ctl = _ctl;
    if (ctl == null) return;
    if (ctl.value.isPlaying) {
      await ctl.pause();
    } else {
      final v = ctl.value;
      if (v.duration > Duration.zero && v.position >= v.duration) {
        await ctl.seekTo(Duration.zero);
      }
      _handledEnd = false;
      await ctl.play();
    }
    _scheduleHide();
    if (mounted) setState(() {});
  }

  Future<void> _seekBy(int sec) async {
    final ctl = _ctl;
    if (ctl == null) return;
    final dur = ctl.value.duration;
    var target = ctl.value.position + Duration(seconds: sec);
    if (target < Duration.zero) target = Duration.zero;
    if (target > dur) target = dur;
    await ctl.seekTo(target);
    _handledEnd = false;
    if (mounted) _showHint(sec > 0 ? '+$sec' : '$sec');
  }

  Future<void> _cycleSpeed() async {
    final i = speeds.indexOf(speed);
    final next = speeds[(i + 1) % speeds.length];
    speed = next;
    await _ctl?.setPlaybackSpeed(next);
    if (mounted) setState(() {});
  }

  Future<void> _toggleRepeat() async {
    repeat = !repeat;
    await _ctl?.setLooping(repeat);
    if (mounted) setState(() {});
  }

  Future<void> _toggleFullscreen() async {
    landscape = !landscape;
    if (landscape) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
  }

  // ---------- shared widgets ----------
  Widget _ib(IconData icon, VoidCallback? f, {double size = 28, Color? color}) =>
      IconButton(
        onPressed: f,
        iconSize: size,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        color: color ?? fg,
        disabledColor: fg.withAlpha(60),
        icon: Icon(icon),
      );

  Widget _seekBar() {
    final ctl = _ctl;
    final dur = ctl?.value.duration ?? Duration.zero;
    final pos = ctl?.value.position ?? Duration.zero;
    final maxMs = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
    final raw = dragging ? dragValue : pos.inMilliseconds.toDouble();
    final value = raw.clamp(0.0, maxMs).toDouble();
    final timeStyle = TextStyle(color: fg.withAlpha(190), fontSize: 12.5);
    return Column(children: [
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          activeTrackColor: c.aqua,
          inactiveTrackColor: fg.withAlpha(50),
          thumbColor: c.aqua,
          overlayColor: c.aqua.withAlpha(40),
        ),
        child: Slider(
          value: value,
          min: 0,
          max: maxMs,
          onChangeStart: (v) => setState(() {
            dragging = true;
            dragValue = v;
          }),
          onChanged: ctl == null ? null : (v) => setState(() => dragValue = v),
          onChangeEnd: (v) async {
            await _ctl?.seekTo(Duration(milliseconds: v.round()));
            _handledEnd = false;
            if (mounted) setState(() => dragging = false);
            _scheduleHide();
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(fmtDur(Duration(milliseconds: value.round()).inSeconds),
              style: timeStyle),
          Text(fmtDur(dur.inSeconds), style: timeStyle),
        ]),
      ),
    ]);
  }

  Widget _transport({required double big}) {
    final playing = _ctl?.value.isPlaying ?? false;
    final hasPrev = index > 0;
    final hasNext = index < widget.tracks.length - 1;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _ib(Icons.skip_previous_rounded, hasPrev ? () => _go(-1) : null,
          size: 34),
      _ib(Icons.replay_10_rounded, () => _seekBy(-10), size: 34),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: _toggle,
        child: Container(
          width: big,
          height: big,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [c.pink, c.amber]),
              boxShadow: [
                BoxShadow(
                    color: c.pink.withAlpha(90),
                    blurRadius: 24,
                    offset: const Offset(0, 8))
              ]),
          child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: big * .55),
        ),
      ),
      const SizedBox(width: 6),
      _ib(Icons.forward_10_rounded, () => _seekBy(10), size: 34),
      _ib(Icons.skip_next_rounded, hasNext ? () => _go(1) : null, size: 34),
    ]);
  }

  Widget _utils({required bool video}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
          onTap: _cycleSpeed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
                color: fg.withAlpha(28),
                borderRadius: BorderRadius.circular(99)),
            child: Text('${speed}x',
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        Row(children: [
          _ib(repeat ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              _toggleRepeat,
              size: 24, color: repeat ? c.aqua : null),
          if (video)
            _ib(
                landscape
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                _toggleFullscreen,
                size: 28),
        ]),
      ]),
    );
  }

  Widget _errorView() => Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, color: c.pink, size: 40),
        const SizedBox(height: 10),
        Text(s('تعذّر تشغيل هذا الملف', 'Could not play this file'),
            style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => DownloadService.open(track.uri, track.mime),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
                color: fg.withAlpha(28),
                borderRadius: BorderRadius.circular(99)),
            child: Text(s('فتح بتطبيق آخر', 'Open with another app'),
                style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
          ),
        ),
      ]);

  // ---------- audio ----------
  Widget _artwork(double size) {
    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(colors: [c.vio, c.pink])),
          child: Icon(Icons.music_note_rounded,
              color: Colors.white, size: size * .38),
        );
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: c.vio.withAlpha(90),
                blurRadius: 40,
                offset: const Offset(0, 18))
          ]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          width: size,
          height: size,
          child: track.thumb.isEmpty
              ? fallback()
              : Image.network(track.thumb,
                  fit: BoxFit.cover, errorBuilder: (ctx, e, st) => fallback()),
        ),
      ),
    );
  }

  Widget _audioBody() {
    final mq = MediaQuery.of(context);
    final art = math
        .min(mq.size.width - 96, mq.size.height * 0.36)
        .clamp(120.0, 320.0)
        .toDouble();
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.bg2, c.bg])),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Row(children: [
              _ib(Icons.keyboard_arrow_down_rounded,
                  () => Navigator.of(context).pop(),
                  size: 34),
              const Spacer(),
              if (widget.tracks.length > 1)
                Text('${index + 1} / ${widget.tracks.length}',
                    style: TextStyle(
                        color: c.mute, fontWeight: FontWeight.w700)),
              const SizedBox(width: 12),
            ]),
            const Spacer(),
            _artwork(art),
            const SizedBox(height: 26),
            Text(track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.ink, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(track.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.mute, fontSize: 14)),
            const Spacer(),
            if (error != null)
              _errorView()
            else if (_ctl == null)
              CircularProgressIndicator(color: c.aqua)
            else ...[
              _seekBar(),
              const SizedBox(height: 8),
              _transport(big: 72),
              const SizedBox(height: 14),
              _utils(video: false),
            ],
            const SizedBox(height: 18),
          ]),
        ),
      ),
    );
  }

  // ---------- video ----------
  Widget _videoOverlay() {
    final ctl = _ctl;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xB3000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xCC000000),
          ],
          stops: [0, .28, .6, 1],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          Row(children: [
            _ib(Icons.arrow_back_rounded, () => Navigator.of(context).pop(),
                size: 26),
            const SizedBox(width: 4),
            Expanded(
              child: Text(track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
          ]),
          Expanded(
            child: Center(
              child: ctl == null
                  ? const SizedBox.shrink()
                  : _transport(big: 68),
            ),
          ),
          if (ctl != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(children: [
                _seekBar(),
                _utils(video: true),
              ]),
            ),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }

  Widget _videoBody() {
    final ctl = _ctl;
    final ratio = (ctl != null && ctl.value.aspectRatio > 0)
        ? ctl.value.aspectRatio
        : 16 / 9;
    final showOverlay = controls || ctl == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => controls = !controls);
        if (controls) _scheduleHide();
      },
      onDoubleTapDown: (d) => _tapX = d.globalPosition.dx,
      onDoubleTap: () {
        final w = MediaQuery.of(context).size.width;
        _seekBy(_tapX < w / 2 ? -10 : 10);
      },
      child: Stack(children: [
        Positioned.fill(
          child: Center(
            child: ctl == null
                ? (error != null
                    ? _errorView()
                    : CircularProgressIndicator(color: c.aqua))
                : AspectRatio(aspectRatio: ratio, child: VideoPlayer(ctl)),
          ),
        ),
        if (ctl != null && ctl.value.isBuffering)
          const IgnorePointer(
            child: Center(
                child: CircularProgressIndicator(color: Colors.white)),
          ),
        if (ctl != null && error != null) Center(child: _errorView()),
        if (_hint != null)
          IgnorePointer(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_hint!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: showOverlay ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !showOverlay,
              child: _videoOverlay(),
            ),
          ),
        ),
      ]),
    );
  }

     @override
  Widget build(BuildContext context) {
    final darkBg = !isAudio || c.bg.computeLuminance() < 0.5;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(darkBg),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor: isAudio ? c.bg : Colors.black,
          body: isAudio ? _audioBody() : _videoBody(),
        ),
      ),
    );
  }