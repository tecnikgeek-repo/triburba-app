// La mappa delle tribù: forme vere dei quartieri e dei comuni ACCESI (gli altri restano nella nebbia),
// col colore della loro zona; tocco = apre il quartiere. Sotto, l'elenco e i comuni da far aprire.
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/tamtam.dart';
import 'naviga.dart';

class SchermataMappa extends StatefulWidget {
  const SchermataMappa({super.key});

  @override
  State<SchermataMappa> createState() => _SchermataMappaState();
}

class _SchermataMappaState extends State<SchermataMappa> {
  Mappa? _m;
  String? _errore;
  String _filtroComuni = '';

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    try {
      final m = await mappaInMemoria(ricarica: true);
      if (mounted) {
        setState(() {
          _m = m;
          _errore = null;
        });
      }
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _chiedi(String chiave) async {
    try {
      final j = await stato.api.chiediZona(chiave);
      if (!mounted) return;
      messaggio(context, '${j['msg']}');
      _carica();
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    return Scaffold(
      appBar: AppBar(title: const Text('Le tribù')),
      body: m == null
          ? Center(
              child: _errore == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errore!, style: const TextStyle(color: testo2)),
                        const SizedBox(height: 10),
                        OutlinedButton(onPressed: _carica, child: const Text('Riprova')),
                      ],
                    ),
            )
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                children: [
                  _Disegno(mappa: m, onTocco: (q) => apriQuartiere(context, q.slug)),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 14),
                    child: Text(
                      m.crediti,
                      style: const TextStyle(color: muto, fontSize: 10.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (m.giorniCambio > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Potrai cambiare quartiere di casa tra ${m.giorniCambio} giorni.',
                        style: const TextStyle(color: muto, fontSize: 12.5),
                      ),
                    ),
                  for (final g in m.gruppi) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                      child: Text(
                        g.$1.toUpperCase(),
                        style: const TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
                      ),
                    ),
                    for (final q in g.$2) _rigaQuartiere(q, m),
                  ],
                  const SizedBox(height: 18),
                  _comuni(m),
                ],
              ),
            ),
    );
  }

  Widget _rigaQuartiere(QuartiereMappa q, Mappa m) {
    final casa = m.casa == q.id;
    final segui = m.seguiti.contains(q.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: superficie,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => apriQuartiere(context, q.slug),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: colore(q.colore), width: 4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.nome, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                      Text(
                        '${q.residenti} residenti · ${q.post} post${q.citta != 'Napoli' ? ' · ${q.citta}' : ''}',
                        style: const TextStyle(color: muto, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (casa) const Chip2(testo: 'Casa', icona: Icons.home_rounded, colore: terracotta),
                if (!casa && segui) const Chip2(testo: 'Segui', icona: Icons.check, colore: golfo),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: muto),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _comuni(Mappa m) {
    final lista = m.spenti.where((c) => _filtroComuni.isEmpty || c.nome.toLowerCase().contains(_filtroComuni.toLowerCase())).toList();
    return Carta(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_twilight_rounded, color: oro),
              const SizedBox(width: 8),
              Expanded(child: Text('Accendi la tua zona', style: titolo(19))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'I quartieri di Napoli e i comuni dell\'area metropolitana restano nella nebbia finché non li chiede '
            'abbastanza gente: a ${m.sogliaApertura} richieste si accendono da soli sulla mappa.',
            style: const TextStyle(color: testo2, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _filtroComuni = v),
            decoration: const InputDecoration(hintText: 'Cerca il quartiere o il comune…', prefixIcon: Icon(Icons.search), isDense: true),
          ),
          const SizedBox(height: 6),
          for (final c in lista.take(_filtroComuni.isEmpty ? 8 : 40))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: (c.richieste / m.sogliaApertura).clamp(0, 1), minHeight: 5, color: oro),
              ),
              trailing: TextButton(
                onPressed: () => _chiedi(c.chiave),
                child: Text(c.mia ? 'Ritira ${c.richieste}/${m.sogliaApertura}' : 'Chiedi ${c.richieste}/${m.sogliaApertura}'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le forme dei quartieri accesi, scalate nel riquadro, con zoom e tocco.
class _Disegno extends StatelessWidget {
  const _Disegno({required this.mappa, required this.onTocco});

  final Mappa mappa;
  final void Function(QuartiereMappa) onTocco;

  @override
  Widget build(BuildContext context) {
    final forme = [
      for (final q in mappa.tutti)
        if (q.forma != null && q.box != null) (q, leggiForma(q.forma!)),
    ];
    if (forme.isEmpty) return const SizedBox(height: 8);
    var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
    for (final (q, _) in forme) {
      x0 = x0 < q.box![0] ? x0 : q.box![0];
      y0 = y0 < q.box![1] ? y0 : q.box![1];
      x1 = x1 > q.box![2] ? x1 : q.box![2];
      y1 = y1 > q.box![3] ? y1 : q.box![3];
    }
    final riquadro = Rect.fromLTRB(x0, y0, x1, y1);
    return AspectRatio(
      aspectRatio: 1.15,
      child: Container(
        decoration: BoxDecoration(
          color: vernice2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: linea),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (c, lim) {
            final dim = Size(lim.maxWidth, lim.maxHeight);
            final t = trasforma(riquadro, dim, margine: 28);
            return InteractiveViewer(
              maxScale: 8,
              child: GestureDetector(
                onTapUp: (d) {
                  for (final (q, path) in forme.reversed) {
                    if (path.transform(t.storage).contains(d.localPosition)) {
                      onTocco(q);
                      return;
                    }
                  }
                },
                child: CustomPaint(
                  size: dim,
                  painter: _Pittore(forme, t, casa: mappa.casa),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Matrice che porta il riquadro della mappa dentro la tela, centrato.
Matrix4 trasforma(Rect r, Size tela, {double margine = 20}) {
  final w = r.width <= 0 ? 1.0 : r.width, h = r.height <= 0 ? 1.0 : r.height;
  final k = ((tela.width - 2 * margine) / w).clamp(0.0, (tela.height - 2 * margine) / h);
  final dx = (tela.width - w * k) / 2 - r.left * k;
  final dy = (tela.height - h * k) / 2 - r.top * k;
  return Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1)
    ..scaleByDouble(k, k, 1, 1);
}

/// «M x y L x y … Z» (anche più pezzi) → Path.
Path leggiForma(String d) {
  final p = Path();
  final rx = RegExp(r'([MLZ])\s*(-?[\d.]+)?\s*(-?[\d.]+)?', caseSensitive: false);
  for (final m in rx.allMatches(d)) {
    final c = m.group(1)!.toUpperCase();
    if (c == 'Z') {
      p.close();
      continue;
    }
    final x = double.tryParse(m.group(2) ?? ''), y = double.tryParse(m.group(3) ?? '');
    if (x == null || y == null) continue;
    c == 'M' ? p.moveTo(x, y) : p.lineTo(x, y);
  }
  return p;
}

class _Pittore extends CustomPainter {
  _Pittore(this.forme, this.t, {this.casa});

  final List<(QuartiereMappa, Path)> forme;
  final Matrix4 t;
  final int? casa;

  @override
  void paint(Canvas canvas, Size size) {
    // griglia sottile di fondo
    final g = Paint()
      ..color = bianco.withValues(alpha: .035)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), g);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    for (final (q, path) in forme) {
      final pp = path.transform(t.storage);
      final col = colore(q.colore);
      final mia = q.id == casa;
      canvas.drawPath(pp, Paint()..color = col.withValues(alpha: mia ? .55 : .32));
      canvas.drawPath(
        pp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = mia ? 2.4 : 1.4
          ..color = mia ? oro : col,
      );
    }
    // pallino e nome al centro di ogni forma
    for (final (q, path) in forme) {
      final b = path.transform(t.storage).getBounds();
      final c = b.center;
      canvas.drawCircle(c, 5, Paint()..color = colore(q.colore));
      canvas.drawCircle(
        c,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = bianco,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: q.nome,
          style: const TextStyle(
            color: testo,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            fontFamily: fontTesto,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 160);
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - 10 - tp.height));
    }
  }

  @override
  bool shouldRepaint(covariant _Pittore old) => old.forme != forme || old.casa != casa;
}
