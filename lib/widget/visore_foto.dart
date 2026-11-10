// Visore delle foto a tutto schermo, «wouuu»: si apre dalla foto toccata (Hero), sfondo con la stessa foto
// sfocata e scurita, doppio tocco per ingrandire, pizzico, trascini giù per chiudere, titolo e Condividi.
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../tema.dart';

class VisoreFoto extends StatefulWidget {
  const VisoreFoto({super.key, required this.url, this.titolo, this.sottotitolo, this.tondo = false});

  final String url;
  final String? titolo, sottotitolo;

  /// foto profilo: entra dal cerchio e si apre quadrata
  final bool tondo;

  @override
  State<VisoreFoto> createState() => _VisoreFotoState();
}

class _VisoreFotoState extends State<VisoreFoto> with SingleTickerProviderStateMixin {
  final _zoom = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  Animation<Matrix4>? _verso;
  TapDownDetails? _tocco;
  double _giu = 0; // trascinamento verso il basso per chiudere
  bool _comandi = true;

  bool get _ingrandita => _zoom.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_verso != null) _zoom.value = _verso!.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _doppioTocco() {
    final fine = _ingrandita
        ? Matrix4.identity()
        : (() {
            final p = _tocco?.localPosition ?? Offset.zero;
            return Matrix4.identity()
              ..translateByDouble(-p.dx * 1.5, -p.dy * 1.5, 0, 1)
              ..scaleByDouble(2.5, 2.5, 1, 1);
          })();
    _verso = Matrix4Tween(begin: _zoom.value, end: fine).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final avanzamento = (_giu.abs() / 300).clamp(0.0, 1.0);
    final img = CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.contain,
      placeholder: (_, _) => const Center(child: CircularProgressIndicator(color: terracotta)),
      errorWidget: (_, _, _) => const Center(
        child: Text('Foto non disponibile', style: TextStyle(color: bianco, fontFamily: 'Inter')),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // sfondo: la stessa foto sfocata e scurita, che sfuma mentre trascini per chiudere
          Opacity(
            opacity: 1 - avanzamento * .9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: CachedNetworkImage(imageUrl: widget.url, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox()),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC0B0807), Color(0x99120D0B), Color(0xE60B0807)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // la foto
          GestureDetector(
            onTap: () => setState(() => _comandi = !_comandi),
            onDoubleTapDown: (d) => _tocco = d,
            onDoubleTap: _doppioTocco,
            onVerticalDragUpdate: _ingrandita ? null : (d) => setState(() => _giu += d.delta.dy),
            onVerticalDragEnd: _ingrandita
                ? null
                : (d) {
                    if (_giu.abs() > 120 || (d.primaryVelocity ?? 0).abs() > 900) {
                      Navigator.of(context).maybePop();
                    } else {
                      setState(() => _giu = 0);
                    }
                  },
            child: Transform.translate(
              offset: Offset(0, _giu),
              child: Transform.scale(
                scale: 1 - avanzamento * .15,
                child: InteractiveViewer(
                  transformationController: _zoom,
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Hero(
                      tag: 'foto-${widget.url}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(widget.tondo ? 24 : 14),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .55), blurRadius: 40, offset: const Offset(0, 18))],
                            ),
                            child: img,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // comandi: chiudi e condividi in alto, titolo in basso
          AnimatedOpacity(
            opacity: _comandi && _giu == 0 ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: !_comandi,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          _tasto(Icons.close_rounded, 'Chiudi', () => Navigator.of(context).maybePop()),
                          const Spacer(),
                          _tasto(Icons.ios_share_rounded, 'Condividi', () => SharePlus.instance.share(ShareParams(uri: Uri.parse(widget.url)))),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (widget.titolo != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                        child: Column(
                          children: [
                            Text(
                              widget.titolo!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: bianco, fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            if (widget.sottotitolo != null) ...[
                              const SizedBox(height: 2),
                              Text(widget.sottotitolo!, style: const TextStyle(color: Color(0xFFCDBCAE), fontFamily: 'Inter', fontSize: 13.5)),
                            ],
                            const SizedBox(height: 10),
                            const Text(
                              'Doppio tocco per ingrandire · trascina giù per chiudere',
                              style: TextStyle(color: Color(0x99F6EDE4), fontFamily: 'Inter', fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tasto(IconData ico, String nome, VoidCallback f) => Tooltip(
    message: nome,
    child: ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: .12),
          child: InkWell(
            onTap: f,
            child: SizedBox(width: 44, height: 44, child: Icon(ico, color: bianco, size: 22)),
          ),
        ),
      ),
    ),
  );
}
