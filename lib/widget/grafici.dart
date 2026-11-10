// Grafici semplici del pannello admin, come sul sito: barre per giorno (una o due serie), linea del totale,
// classifiche a barre orizzontali. Colori del tema: terracotta e oro.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';

/// Serie per giorno dal server: {"2026-11-01": 3, ...} → valori in ordine di data.
List<MapEntry<String, double>> serieDa(Object? j) {
  if (j is! Map) return const [];
  final e = j.entries.map((x) => MapEntry('${x.key}', (x.value is num) ? (x.value as num).toDouble() : double.tryParse('${x.value}') ?? 0)).toList();
  e.sort((a, b) => a.key.compareTo(b.key));
  return e;
}

/// «2026-11-09» → «9/11»
String giornoBreve(String g) {
  final p = g.split('-');
  return p.length == 3 ? '${int.tryParse(p[2]) ?? p[2]}/${int.tryParse(p[1]) ?? p[1]}' : g;
}

/// Legenda a pallini.
class Legenda extends StatelessWidget {
  const Legenda(this.voci, {super.key});

  final List<(String, Color)> voci;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 6,
    children: [
      for (final (t, c) in voci)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(t, style: const TextStyle(color: testo2, fontSize: 12.5)),
          ],
        ),
    ],
  );
}

/// Barre per giorno: una serie (terracotta) o due affiancate (terracotta e oro).
class GraficoBarre extends StatelessWidget {
  const GraficoBarre({super.key, required this.a, this.b, this.altezza = 150});

  final List<MapEntry<String, double>> a;
  final List<MapEntry<String, double>>? b;
  final double altezza;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: altezza,
    width: double.infinity,
    child: CustomPaint(painter: _Barre(a, b)),
  );
}

class _Barre extends CustomPainter {
  _Barre(this.a, this.b);

  final List<MapEntry<String, double>> a;
  final List<MapEntry<String, double>>? b;

  @override
  void paint(Canvas canvas, Size size) {
    if (a.isEmpty) return;
    const sotto = 18.0, sopra = 14.0;
    final h = size.height - sotto - sopra;
    final massimo = math.max(1.0, [...a.map((e) => e.value), ...?b?.map((e) => e.value)].fold<double>(0, math.max));
    _griglia(canvas, size, sopra, h, massimo);
    final n = a.length;
    final passo = size.width / n;
    final due = b != null;
    final larga = math.max(1.5, passo * (due ? .36 : .62));
    for (var i = 0; i < n; i++) {
      final x = i * passo + (passo - (due ? larga * 2 + 1 : larga)) / 2;
      _barra(canvas, x, sopra + h, larga, h * a[i].value / massimo, terracotta);
      if (due && i < b!.length) _barra(canvas, x + larga + 1, sopra + h, larga, h * b![i].value / massimo, oro);
    }
    _date(canvas, size, a.map((e) => e.key).toList(), passo);
  }

  @override
  bool shouldRepaint(covariant _Barre old) => old.a != a || old.b != b;
}

void _barra(Canvas c, double x, double base, double larga, double alta, Color colore) {
  if (alta <= 0) return;
  c.drawRRect(
    RRect.fromRectAndCorners(Rect.fromLTWH(x, base - alta, larga, alta), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
    Paint()..color = colore,
  );
}

void _griglia(Canvas c, Size s, double sopra, double h, double massimo) {
  final p = Paint()
    ..color = linea2
    ..strokeWidth = 1;
  for (final f in [0.0, .5, 1.0]) {
    final y = sopra + h * (1 - f);
    c.drawLine(Offset(0, y), Offset(s.width, y), p);
    if (f > 0) _scrivi(c, (massimo * f).round().toString(), Offset(0, y - 13), 10);
  }
}

void _date(Canvas c, Size s, List<String> giorni, double passo) {
  if (giorni.isEmpty) return;
  final ogni = math.max(1, (giorni.length / 5).ceil());
  for (var i = 0; i < giorni.length; i += ogni) {
    _scrivi(c, giornoBreve(giorni[i]), Offset(i * passo, s.height - 14), 10);
  }
}

void _scrivi(Canvas c, String t, Offset o, double misura) {
  final tp = TextPainter(
    text: TextSpan(text: t, style: TextStyle(color: muto, fontSize: misura, fontFamily: 'Inter')),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, o);
}

/// Linea del totale nel tempo, con area sfumata sotto.
class GraficoLinea extends StatelessWidget {
  const GraficoLinea({super.key, required this.serie, this.altezza = 140});

  final List<MapEntry<String, double>> serie;
  final double altezza;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: altezza,
    width: double.infinity,
    child: CustomPaint(painter: _Linea(serie)),
  );
}

class _Linea extends CustomPainter {
  _Linea(this.s);

  final List<MapEntry<String, double>> s;

  @override
  void paint(Canvas canvas, Size size) {
    if (s.isEmpty) return;
    const sotto = 18.0, sopra = 14.0;
    final h = size.height - sotto - sopra;
    final massimo = math.max(1.0, s.map((e) => e.value).fold<double>(0, math.max));
    _griglia(canvas, size, sopra, h, massimo);
    final passo = s.length > 1 ? size.width / (s.length - 1) : size.width;
    final punti = [for (var i = 0; i < s.length; i++) Offset(i * passo, sopra + h * (1 - s[i].value / massimo))];
    final linea = Path()..moveTo(punti.first.dx, punti.first.dy);
    for (final p in punti.skip(1)) {
      linea.lineTo(p.dx, p.dy);
    }
    final area = Path.from(linea)
      ..lineTo(punti.last.dx, sopra + h)
      ..lineTo(punti.first.dx, sopra + h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [terracotta.withValues(alpha: .35), terracotta.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, sopra, size.width, h)),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..color = terracotta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(punti.last, 3.5, Paint()..color = oro);
    final passoDate = s.length > 1 ? size.width / s.length : size.width;
    _date(canvas, size, s.map((e) => e.key).toList(), passoDate);
  }

  @override
  bool shouldRepaint(covariant _Linea old) => old.s != s;
}

/// Classifica a barre orizzontali: [{nome, n}] (n può arrivare come testo).
class Classifica extends StatelessWidget {
  const Classifica({super.key, required this.righe, this.nomi = const {}, this.vuoto = 'Ancora niente da mostrare.'});

  final List<dynamic> righe;

  /// nomi leggibili per le chiavi del server (es. «feed» → «Home e feed»)
  final Map<String, String> nomi;
  final String vuoto;

  @override
  Widget build(BuildContext context) {
    if (righe.isEmpty) return Text(vuoto, style: const TextStyle(color: muto));
    double n(dynamic r) => double.tryParse('${(r as Map)['n']}') ?? 0;
    final massimo = math.max(1.0, righe.map(n).fold<double>(0, math.max));
    return Column(
      children: [
        for (final r in righe)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    nomi['${(r as Map)['nome']}'] ?? '${r['nome']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: n(r) / massimo, minHeight: 8, color: terracotta, backgroundColor: superficie2),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 34,
                  child: Text(n(r).round().toString(), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
