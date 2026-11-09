// La mappa come sul web: sotto la sagoma della regione (senza confini interni), poi le zone ancora spente
// in grigio (i quartieri di Napoli un po' più chiari dei comuni), sopra le zone accese in colore pieno con
// bordo bianco e bagliore. Si apre sul Napoletano; il cursore verticale allontana fino alla regione intera,
// il tasto sotto torna alla vista iniziale. Trascinamento e pizzico; al tocco un'etichetta col nome.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../dati/modelli.dart';
import '../tema.dart';

/// «M x y L x y … Z» (anche più pezzi) → Path, in unità di mappa.
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

const _gesso = Color(0xFFF7F0E6);
const _zMax = 14.0;

class MappaDisegno extends StatefulWidget {
  const MappaDisegno({super.key, required this.mappa, required this.onApri});

  final Mappa mappa;
  final void Function(QuartiereMappa) onApri;

  @override
  State<MappaDisegno> createState() => _MappaDisegnoState();
}

/// Cosa mostra l'etichetta toccata.
class _Scelta {
  _Scelta({required this.nome, required this.riga, required this.punto, this.quartiere, this.grigia});

  final String nome, riga;
  final Offset punto; // in unità di mappa
  final QuartiereMappa? quartiere;
  final ZonaGrigia? grigia;
}

class _MappaDisegnoState extends State<MappaDisegno> {
  late List<(QuartiereMappa, Path)> _accesi;
  late List<(ZonaGrigia, Path)> _grigie;
  late List<Path> _regioni;
  late Rect _inizio, _limite;
  late Rect _vista;
  _Scelta? _scelta;

  // pizzico e trascinamento
  Rect? _vistaInizioGesto;
  Offset? _fuocoInizio;

  @override
  void initState() {
    super.initState();
    _prepara();
  }

  @override
  void didUpdateWidget(covariant MappaDisegno old) {
    super.didUpdateWidget(old);
    if (old.mappa != widget.mappa) _prepara();
  }

  static Rect _unisci(Iterable<List<double>> box) {
    var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
    for (final b in box) {
      x0 = math.min(x0, b[0]);
      y0 = math.min(y0, b[1]);
      x1 = math.max(x1, b[2]);
      y1 = math.max(y1, b[3]);
    }
    return x0.isFinite ? Rect.fromLTRB(x0, y0, x1, y1) : const Rect.fromLTWH(0, 0, 1, 1);
  }

  /// Allarga il riquadro (centrato) fino alle proporzioni altezza/larghezza = [a].
  static Rect _proporzioni(Rect r, double a) {
    var w = r.width, h = r.height;
    if (h / w > a) {
      w = h / a;
    } else {
      h = w * a;
    }
    return Rect.fromCenter(center: r.center, width: w, height: h);
  }

  void _prepara() {
    final m = widget.mappa;
    _accesi = [
      for (final q in m.tutti)
        if (q.forma != null && q.box != null) (q, leggiForma(q.forma!)),
    ];
    _grigie = [for (final z in m.nebbia) (z, leggiForma(z.forma))];
    _regioni = [for (final r in m.regioni) leggiForma(r.forma)];

    // vista iniziale: il Napoletano (zone accese e spente), un po' ristretto come sul web
    final zone = _unisci([
      for (final (q, _) in _accesi) q.box!,
      for (final (z, _) in _grigie) z.box,
    ]);
    final pad = zone.width * .02;
    var inizio = zone.inflate(pad);
    if (_regioni.isNotEmpty) {
      inizio = Rect.fromCenter(center: inizio.center, width: inizio.width / 1.14, height: inizio.height / 1.14);
    }
    _inizio = inizio;
    final a = (inizio.height / inizio.width).clamp(.6, 1.15);
    _inizio = _proporzioni(inizio, a);
    // limite dello zoom indietro: la regione intera (o le zone, con un server vecchio)
    final tutto = _unisci([
      for (final r in m.regioni) r.box,
      for (final (q, _) in _accesi) q.box!,
      for (final (z, _) in _grigie) z.box,
    ]).inflate(zone.width * .02);
    _limite = _proporzioni(tutto, a);
    _vista = _inizio;
    _scelta = null;
  }

  double get _proporzione => _inizio.height / _inizio.width;
  double get _zoom => _limite.width / _vista.width;

  void _blocca() {
    var w = _vista.width.clamp(_limite.width / _zMax, _limite.width);
    final h = w * _proporzione;
    var l = _vista.left.clamp(_limite.left, _limite.right - w);
    var t = _vista.top.clamp(_limite.top, _limite.bottom - h);
    _vista = Rect.fromLTWH(l, t, w, h);
  }

  /// Avvicina o allontana tenendo fermo il punto [fuoco] (in unità di mappa).
  void _zoomA(double nuovaLarghezza, Offset fuoco) {
    final f = nuovaLarghezza / _vista.width;
    _vista = Rect.fromLTWH(
      fuoco.dx - (fuoco.dx - _vista.left) * f,
      fuoco.dy - (fuoco.dy - _vista.top) * f,
      _vista.width * f,
      _vista.height * f,
    );
    _blocca();
  }

  Offset _aMappa(Offset p, Size s) => Offset(_vista.left + p.dx / s.width * _vista.width, _vista.top + p.dy / s.height * _vista.height);

  Matrix4 _matrice(Size s) {
    final k = s.width / _vista.width;
    return Matrix4.identity()
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-_vista.left, -_vista.top, 0, 1);
  }

  void _tocco(Offset p, Size s) {
    final t = _matrice(s).storage;
    for (final (q, path) in _accesi.reversed) {
      if (path.transform(t).contains(p)) {
        if (_scelta?.quartiere?.id == q.id) {
          widget.onApri(q);
          return;
        }
        final r = q.residenti;
        setState(
          () => _scelta = _Scelta(
            nome: q.nome,
            riga: r == 0 ? 'Acceso · ancora nessun residente' : (r == 1 ? 'Acceso · 1 residente' : 'Acceso · $r residenti'),
            punto: _aMappa(p, s),
            quartiere: q,
          ),
        );
        return;
      }
    }
    for (final (z, path) in _grigie.reversed) {
      if (path.transform(t).contains(p)) {
        setState(
          () => _scelta = _Scelta(
            nome: z.nome,
            riga: '${z.dove.isEmpty ? (z.napoli ? 'Quartiere di Napoli' : 'Comune') : z.dove} · ancora spento, si accende con le richieste dei vicini',
            punto: _aMappa(p, s),
            grigia: z,
          ),
        );
        return;
      }
    }
    for (final (i, path) in _regioni.indexed) {
      if (path.transform(t).contains(p)) {
        setState(
          () => _scelta = _Scelta(
            nome: widget.mappa.regioni[i].nome,
            riga: 'Le altre province arrivano presto',
            punto: _aMappa(p, s),
          ),
        );
        return;
      }
    }
    if (_scelta != null) setState(() => _scelta = null);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / _proporzione,
      child: Container(
        decoration: BoxDecoration(
          color: vernice2,
          gradient: const RadialGradient(
            center: Alignment(0, -.1),
            radius: .9,
            colors: [Color(0x14E0663A), Color(0x00E0663A)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: linea),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (c, lim) {
            final s = Size(lim.maxWidth, lim.maxHeight);
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _tocco(d.localPosition, s),
                    onScaleStart: (d) {
                      _vistaInizioGesto = _vista;
                      _fuocoInizio = d.localFocalPoint;
                    },
                    onScaleUpdate: (d) {
                      final v0 = _vistaInizioGesto, f0 = _fuocoInizio;
                      if (v0 == null || f0 == null) return;
                      setState(() {
                        // il punto sotto le dita all'inizio resta sotto le dita
                        final w = v0.width / d.scale;
                        final fuocoMappa = Offset(v0.left + f0.dx / s.width * v0.width, v0.top + f0.dy / s.height * v0.height);
                        final l = fuocoMappa.dx - d.localFocalPoint.dx / s.width * w;
                        final t = fuocoMappa.dy - d.localFocalPoint.dy / s.height * w * _proporzione;
                        _vista = Rect.fromLTWH(l, t, w, w * _proporzione);
                        _blocca();
                      });
                    },
                    child: CustomPaint(
                      size: s,
                      painter: _Pittore(
                        accesi: _accesi,
                        grigie: _grigie,
                        regioni: _regioni,
                        matrice: _matrice(s),
                        casa: widget.mappa.casa,
                        scelta: _scelta,
                      ),
                    ),
                  ),
                ),
                if (_scelta != null) _etichetta(_scelta!, s),
                Positioned(top: 10, right: 10, child: _comandi()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _comandi() {
    final v = (math.log(_zoom) / math.log(_zMax) * 100).clamp(0.0, 100.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
      decoration: BoxDecoration(
        color: superficie.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: linea2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 110,
            width: 36,
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 5,
                  activeTrackColor: terracotta,
                  inactiveTrackColor: linea2,
                  thumbColor: terracotta,
                  overlayColor: terracotta.withValues(alpha: .18),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  value: v,
                  max: 100,
                  semanticFormatterCallback: (_) => 'Zoom della mappa',
                  onChanged: (x) => setState(() {
                    final z = math.exp(x / 100 * math.log(_zMax));
                    _zoomA(_limite.width / z, _vista.center);
                  }),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Torna alla vista iniziale',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.restart_alt_rounded, color: testo2, size: 22),
            onPressed: () => setState(() {
              _vista = _inizio;
              _scelta = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _etichetta(_Scelta sc, Size s) {
    final p = Offset((sc.punto.dx - _vista.left) / _vista.width * s.width, (sc.punto.dy - _vista.top) / _vista.height * s.height);
    const larg = 230.0;
    final left = (p.dx - larg / 2).clamp(8.0, math.max(8.0, s.width - larg - 8)).toDouble();
    final sopra = p.dy > 90;
    final acceso = sc.quartiere != null;
    return Positioned(
      left: left,
      top: sopra ? null : p.dy + 18,
      bottom: sopra ? s.height - p.dy + 14 : null,
      width: larg,
      child: GestureDetector(
        onTap: acceso ? () => widget.onApri(sc.quartiere!) : () => setState(() => _scelta = null),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          decoration: BoxDecoration(
            color: superficie.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: acceso ? const Color(0xFF9ACD32).withValues(alpha: .55) : linea2),
            boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sc.nome,
                      style: const TextStyle(fontFamily: fontTesto, fontWeight: FontWeight.w700, fontSize: 14, color: testo),
                    ),
                  ),
                  if (acceso) const Icon(Icons.chevron_right_rounded, color: testo2, size: 20),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                sc.riga,
                style: TextStyle(
                  fontFamily: fontTesto,
                  fontSize: 12,
                  height: 1.3,
                  color: acceso ? const Color(0xFFB5DD5A) : muto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pittore extends CustomPainter {
  _Pittore({
    required this.accesi,
    required this.grigie,
    required this.regioni,
    required this.matrice,
    required this.casa,
    required this.scelta,
  });

  final List<(QuartiereMappa, Path)> accesi;
  final List<(ZonaGrigia, Path)> grigie;
  final List<Path> regioni;
  final Matrix4 matrice;
  final int? casa;
  final _Scelta? scelta;

  @override
  void paint(Canvas canvas, Size size) {
    final t = matrice.storage;
    final tratto = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    // regione: sagoma senza confini interni
    for (final r in regioni) {
      final pp = r.transform(t);
      canvas.drawPath(pp, Paint()..color = _gesso.withValues(alpha: .025));
      canvas.drawPath(pp, tratto
        ..strokeWidth = 1
        ..color = _gesso.withValues(alpha: .2));
    }
    // zone spente in grigio: Napoli più chiara dei comuni; quella toccata in oro
    for (final (z, path) in grigie) {
      final pp = path.transform(t);
      final toccata = identical(scelta?.grigia, z);
      canvas.drawPath(
        pp,
        Paint()..color = toccata ? oro.withValues(alpha: .22) : _gesso.withValues(alpha: z.napoli ? .09 : .045),
      );
      canvas.drawPath(pp, tratto
        ..strokeWidth = z.napoli ? .8 : .7
        ..color = _gesso.withValues(alpha: z.napoli ? .28 : .16));
    }
    // zone accese: colore pieno, bagliore, bordo bianco
    for (final (q, path) in accesi) {
      final pp = path.transform(t);
      final col = colore(q.colore);
      canvas.drawPath(
        pp,
        Paint()
          ..color = col.withValues(alpha: .7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawPath(pp, Paint()..color = identical(scelta?.quartiere, q) ? Color.lerp(col, Colors.white, .2)! : col);
      canvas.drawPath(pp, tratto
        ..strokeWidth = 1.4
        ..color = Colors.white);
    }
    // punto bianco con anello e nome
    for (final (q, path) in accesi) {
      final c = q.centro != null && q.centro!.length == 2
          ? MatrixUtils.transformPoint(matrice, Offset(q.centro![0], q.centro![1]))
          : path.transform(t).getBounds().center;
      final col = colore(q.colore);
      if (q.id == casa) {
        canvas.drawCircle(c, 13, Paint()..color = col.withValues(alpha: .28));
        canvas.drawCircle(c, 13, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = col.withValues(alpha: .6));
      }
      canvas.drawCircle(c, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(c, 6.5, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = col);
      const stile = TextStyle(fontFamily: fontTesto, fontSize: 13, fontWeight: FontWeight.w700);
      final bordo = TextPainter(
        text: TextSpan(
          text: q.nome,
          style: stile.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeJoin = StrokeJoin.round
              ..color = vernice.withValues(alpha: .85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 200);
      final nome = TextPainter(
        text: TextSpan(text: q.nome, style: stile.copyWith(color: Colors.white)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 200);
      final o = Offset(c.dx - nome.width / 2, c.dy - 12 - nome.height);
      bordo.paint(canvas, o);
      nome.paint(canvas, o);
    }
  }

  @override
  bool shouldRepaint(covariant _Pittore old) =>
      old.matrice != matrice || old.accesi != accesi || old.grigie != grigie || old.casa != casa || old.scelta != scelta;
}
