// Compleanni in Home, come sul sito: la festa per chi compie gli anni oggi (coriandoli, auguri ricevuti,
// «Fallo sapere») e la carta «Oggi compie gli anni» con il tasto «Fai gli auguri». I dati li dà /app/v1/compleanni.
import 'dart:math';

import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../schermate/naviga.dart';
import '../tema.dart';
import 'faccia.dart';

const _colori = [Color(0xFFE0663A), Color(0xFFF0B445), Color(0xFFFBE3C4), Color(0xFFD94F7A), Color(0xFF5FC4B8), Color(0xFF9A7BEA)];

class FestaCompleanni extends StatefulWidget {
  const FestaCompleanni({super.key, this.dati});

  /// solo per le anteprime dei test: dati già pronti, niente rete
  final Map<String, dynamic>? dati;

  @override
  State<FestaCompleanni> createState() => FestaCompleanniState();
}

class FestaCompleanniState extends State<FestaCompleanni> {
  Map<String, dynamic>? _d;
  final _fatti = <int>{};

  @override
  void initState() {
    super.initState();
    _d = widget.dati;
    if (_d == null) aggiorna();
  }

  Future<void> aggiorna() async {
    try {
      final d = await stato.api.compleanni();
      if (mounted) setState(() => _d = d);
    } on ErroreApi {
      // senza rete la festa semplicemente non si vede
    }
  }

  Future<void> _auguri(int id) async {
    setState(() => _fatti.add(id));
    try {
      final msg = await stato.api.auguri(id);
      if (mounted) messaggio(context, msg);
    } on ErroreApi catch (e) {
      if (!mounted) return;
      setState(() => _fatti.remove(id));
      messaggio(context, e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final mio = d['mio'] as Map<String, dynamic>?;
    final amici = (d['amici'] as List? ?? []).cast<Map<String, dynamic>>();
    if (mio == null && amici.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mio != null) _CartaFesta(mio: mio, onPubblico: aggiorna),
        if (amici.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(color: superficie, borderRadius: BorderRadius.circular(16), border: Border.all(color: linea)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cake_outlined, color: oro, size: 20),
                    SizedBox(width: 8),
                    Text('Oggi compie gli anni', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final a in amici) _riga(a),
              ],
            ),
          ),
      ],
    );
  }

  Widget _riga(Map<String, dynamic> a) {
    final id = (a['id'] as num?)?.toInt() ?? 0;
    final fatto = a['fatto'] == true || _fatti.contains(id);
    final f = Faccia(a);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => apriUtente(context, f.username),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: oro),
                        child: FotoProfilo(faccia: f, lato: 38),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: terracotta, border: Border.all(color: superficie, width: 2)),
                          child: const Icon(Icons.cake_rounded, size: 11, color: bianco),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('@${f.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muto, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          fatto
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 18, color: Color(0xFF7FD6A6)),
                    SizedBox(width: 4),
                    Text('Auguri fatti', style: TextStyle(color: Color(0xFF7FD6A6), fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                )
              : _TastoAuguri(onTap: () => _auguri(id)),
        ],
      ),
    );
  }
}

/// Tasto «Auguri» con una piccola esplosione di coriandoli quando lo tocchi.
class _TastoAuguri extends StatefulWidget {
  const _TastoAuguri({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TastoAuguri> createState() => _TastoAuguriState();
}

class _TastoAuguriState extends State<_TastoAuguri> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _Scoppio(_a),
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: terracotta,
        foregroundColor: bianco,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        visualDensity: VisualDensity.compact,
      ),
      onPressed: () {
        _a.forward(from: 0).whenComplete(widget.onTap);
      },
      icon: const Icon(Icons.cake_outlined, size: 17),
      label: const Text('Auguri!'),
    ),
  );
}

class _Scoppio extends CustomPainter {
  _Scoppio(this.a) : super(repaint: a);

  final Animation<double> a;
  static final _dir = List.generate(16, (i) => (i * 2 * pi / 16) + (i.isEven ? .2 : -.1));

  @override
  void paint(Canvas canvas, Size size) {
    final t = a.value;
    if (t == 0 || t == 1) return;
    final c = size.center(Offset.zero);
    final p = Paint();
    for (var i = 0; i < _dir.length; i++) {
      final dist = 18 + 46 * Curves.easeOut.transform(t) * (i.isEven ? 1 : .75);
      p.color = _colori[i % _colori.length].withValues(alpha: 1 - t);
      final o = c + Offset(cos(_dir[i]) * dist, sin(_dir[i]) * dist - 14 * t);
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(t * 6 + i);
      canvas.drawRect(const Rect.fromLTWH(-3.5, -1.8, 7, 3.6), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Scoppio old) => false;
}

/// La festa per chi compie gli anni: sfumature calde, torta che salta, coriandoli che cadono.
class _CartaFesta extends StatefulWidget {
  const _CartaFesta({required this.mio, required this.onPubblico});

  final Map<String, dynamic> mio;
  final Future<void> Function() onPubblico;

  @override
  State<_CartaFesta> createState() => _CartaFestaState();
}

class _CartaFestaState extends State<_CartaFesta> with TickerProviderStateMixin {
  late final _coriandoli = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final _torta = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  var _seme = 1;
  bool _invio = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) _coriandoli.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _coriandoli.dispose();
    _torta.dispose();
    super.dispose();
  }

  void _ancora() => setState(() {
    _seme++;
    _coriandoli.forward(from: 0);
  });

  Future<void> _faiSapere() async {
    setState(() => _invio = true);
    try {
      final msg = await stato.api.compleannoPubblico(true);
      if (!mounted) return;
      messaggio(context, msg);
      _ancora();
      await widget.onPubblico();
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mio = widget.mio;
    final n = (mio['auguri'] as num?)?.toInt() ?? 0;
    final chi = (mio['chi'] as List? ?? []).cast<Map<String, dynamic>>().map(Faccia.new).toList();
    final pubblico = mio['pubblico'] == true;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x73F0B445)),
        gradient: const RadialGradient(
          center: Alignment(0, -1.2),
          radius: 1.3,
          colors: [Color(0xFF5A3A1C), Color(0xFF2A1C16), Color(0xFF3A1A22)],
          stops: [0, .55, 1],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66E0663A), blurRadius: 40, offset: Offset(0, 18), spreadRadius: -24)],
      ),
      child: CustomPaint(
        foregroundPainter: _Coriandoli(_coriandoli, _seme),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 14),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _torta,
                builder: (_, figlio) {
                  final t = _torta.value;
                  final salto = t < .4 ? sin(t / .4 * pi) : 0.0;
                  return Transform.translate(
                    offset: Offset(0, -8 * salto),
                    child: Transform.rotate(angle: (t < .4 ? sin(t / .4 * 2 * pi) : 0) * .1, child: figlio),
                  );
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [terracottaScura, terracotta, Color(0xFFE98C3A)]),
                    boxShadow: [
                      BoxShadow(color: Color(0x24F0B445), spreadRadius: 8),
                      BoxShadow(color: Color(0x99E0663A), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -10),
                    ],
                  ),
                  child: const Icon(Icons.cake_rounded, size: 38, color: bianco),
                ),
              ),
              const SizedBox(height: 14),
              const Text('OGGI È IL TUO GIORNO', style: TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Buon compleanno, '),
                    TextSpan(
                      text: '${mio['nome']}',
                      style: TextStyle(
                        foreground: Paint()
                          ..shader = const LinearGradient(colors: [terracotta, Color(0xFFF0B445), Color(0xFFD94F7A)])
                              .createShader(const Rect.fromLTWH(0, 0, 160, 40)),
                      ),
                    ),
                    const TextSpan(text: '!'),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -.6),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tutta triburba festeggia con te. Che sia un anno pieno di vicini belli e quartieri vivi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: testo2, fontSize: 14.5, height: 1.45),
              ),
              if (n > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                  decoration: BoxDecoration(color: const Color(0x38000000), borderRadius: BorderRadius.circular(99), border: Border.all(color: linea)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < chi.length; i++)
                        Align(
                          widthFactor: i == 0 ? 1 : .7,
                          child: Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: superficie, width: 2)),
                            child: FotoProfilo(faccia: chi[i], lato: 26),
                          ),
                        ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          n == 1 && chi.isNotEmpty ? '${chi.first.nome} ti ha fatto gli auguri' : '$n vicini ti hanno fatto gli auguri',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (pubblico) ...[
                const SizedBox(height: 10),
                const Text('I tuoi vicini lo sanno: gli auguri arrivano qui.', style: TextStyle(color: oro, fontWeight: FontWeight.w600, fontSize: 13.5)),
              ],
              if (!pubblico) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(12), border: Border.all(color: linea2)),
                  child: Column(
                    children: [
                      const Text('Il tuo compleanno è privato. Vuoi che i vicini ti facciano gli auguri?',
                          textAlign: TextAlign.center, style: TextStyle(color: testo2, fontSize: 13.5)),
                      const SizedBox(height: 10),
                      BottoneCaldo(testo: 'Fallo sapere', icona: Icons.cake_outlined, occupato: _invio, onPressed: _faiSapere),
                    ],
                  ),
                ),
              ],
              TextButton.icon(
                onPressed: _ancora,
                style: TextButton.styleFrom(foregroundColor: muto),
                icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                label: const Text('Ancora coriandoli'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Coriandoli extends CustomPainter {
  _Coriandoli(this.a, this.seme) : super(repaint: a);

  final Animation<double> a;
  final int seme;

  @override
  void paint(Canvas canvas, Size size) {
    final t = a.value;
    if (t == 0 || t == 1) return;
    final r = Random(seme);
    final p = Paint();
    final sec = t * 4.2 * 60; // passi da 1/60 di secondo, come sul sito
    for (var i = 0; i < 120; i++) {
      final x0 = size.width * (.15 + r.nextDouble() * .7);
      final y0 = size.height * .3 + r.nextDouble() * 30;
      final vx = (r.nextDouble() - .5) * 9;
      final vy = -(5 + r.nextDouble() * 8);
      final giro = (r.nextDouble() - .5) * .3;
      final lato = 5 + r.nextDouble() * 6;
      final tondo = r.nextDouble() < .3;
      // stessa fisica del sito: gravità 0.22, attrito 0.99 sull'orizzontale
      final attrito = (1 - pow(.99, sec)) / .01;
      final x = x0 + vx * attrito;
      final y = y0 + vy * sec + .11 * sec * sec;
      if (y > size.height + 20) continue;
      p.color = _colori[i % _colori.length].withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(r.nextDouble() * pi + giro * sec);
      if (tondo) {
        canvas.drawCircle(Offset.zero, lato / 2.4, p);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: lato, height: lato / 2), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Coriandoli old) => old.seme != seme;
}
