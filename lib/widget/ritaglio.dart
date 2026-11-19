// Copertina: scelta della foto (galleria o fotocamera) e ritaglio 3:1 prima di caricarla, come l'editor del sito.
// La foto intera resta visibile e scurita fuori dalla cornice: si sposta col dito, si ingrandisce con due dita o col cursore.
// Il risultato (1800×600) è esattamente quello che si vede sul profilo, dove la copertina è sempre 3:1.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../tema.dart';

/// Proporzione della copertina, uguale sul sito (aspect-ratio 3/1) e nell'app.
const double proporzioneCopertina = 3;

/// Chiede da dove prendere la foto, poi apre il ritaglio. Ritorna il file pronto da caricare (o null se annullato).
/// [attuale] = indirizzo completo della copertina di adesso: compare anche «Sposta quella attuale», come sul sito.
Future<File?> scegliCopertina(BuildContext context, {String? attuale}) async {
  const sposta = 'sposta';
  final da = await showModalBottomSheet<Object>(
    context: context,
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Nuova copertina', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Scegli dalla galleria'),
            onTap: () => Navigator.pop(s, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Scatta una foto'),
            onTap: () => Navigator.pop(s, ImageSource.camera),
          ),
          if (attuale != null)
            ListTile(
              leading: const Icon(Icons.open_with_rounded),
              title: const Text('Sposta quella attuale'),
              subtitle: const Text('Scegli un\'altra parte della stessa foto o ingrandiscila'),
              onTap: () => Navigator.pop(s, sposta),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (da == null || !context.mounted) return null;
  if (da == sposta) {
    final f = await _scarica(attuale!);
    if (!context.mounted) return null;
    if (f == null) {
      messaggio(context, 'Non riesco ad aprire la copertina attuale: riprova.');
      return null;
    }
    return Navigator.push<File>(context, MaterialPageRoute(builder: (_) => SchermataRitaglio(file: f)));
  }
  final x = await ImagePicker().pickImage(source: da as ImageSource, maxWidth: 2400, maxHeight: 2400, imageQuality: 92);
  if (x == null || !context.mounted) return null;
  return Navigator.push<File>(context, MaterialPageRoute(builder: (_) => SchermataRitaglio(file: File(x.path))));
}

/// Velo sopra la copertina mentre si carica (rotellina + «Carico la copertina…»), come sul sito.
class VeloCaricamento extends StatelessWidget {
  const VeloCaricamento({super.key, this.testo = 'Carico la copertina…'});

  final String testo;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x80120D0B),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: oro)),
          const SizedBox(height: 10),
          Text(testo, style: const TextStyle(color: bianco, fontWeight: FontWeight.w700, fontSize: 13.5)),
        ],
      ),
    ),
  );
}

/// La copertina di adesso in un file temporaneo (per risistemarla)
Future<File?> _scarica(String url) async {
  final client = HttpClient();
  try {
    final r = await (await client.getUrl(Uri.parse(url))).close();
    if (r.statusCode != 200) return null;
    final f = File('${Directory.systemTemp.path}/copertina-attuale-${DateTime.now().millisecondsSinceEpoch}');
    await r.pipe(f.openWrite());
    return f;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

class SchermataRitaglio extends StatefulWidget {
  const SchermataRitaglio({super.key, required this.file, this.immagine});

  final File file;

  /// Solo per le anteprime di prova: la foto già decodificata (nei test la decodifica asincrona non parte)
  @visibleForTesting
  final ui.Image? immagine;

  @override
  State<SchermataRitaglio> createState() => _SchermataRitaglioState();
}

class _SchermataRitaglioState extends State<SchermataRitaglio> {
  ui.Image? _img;
  bool _salvo = false;

  // cornice (in pixel dello schermo) e posizione della foto rispetto all'angolo in alto a sinistra della cornice
  Rect _cornice = Rect.zero;
  double _z = 1; // ingrandimento 1–4 sopra la misura minima che copre la cornice
  Offset _pos = Offset.zero;
  bool _pronta = false;

  // inizio del gesto
  double _z0 = 1;
  Offset _p0 = Offset.zero, _f0 = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (widget.immagine != null) {
      _img = widget.immagine;
    } else {
      _carica();
    }
  }

  Future<void> _carica() async {
    final codec = await ui.instantiateImageCodec(await widget.file.readAsBytes());
    final f = await codec.getNextFrame();
    if (mounted) setState(() => _img = f.image);
  }

  double get _base => math.max(_cornice.width / _img!.width, _cornice.height / _img!.height);
  double get _scala => _base * _z;

  Offset _blocca(Offset p) {
    final s = _scala;
    return Offset(
      p.dx.clamp(_cornice.width - _img!.width * s, 0.0),
      p.dy.clamp(_cornice.height - _img!.height * s, 0.0),
    );
  }

  void _imposta(Rect cornice) {
    if (_cornice == cornice && _pronta) return;
    _cornice = cornice;
    if (!_pronta) {
      // all'inizio la foto è centrata e copre tutta la cornice
      _pos = Offset((_cornice.width - _img!.width * _base) / 2, (_cornice.height - _img!.height * _base) / 2);
      _pronta = true;
    }
    _pos = _blocca(_pos);
  }

  void _zoom(double z, Offset fuoco) {
    final s0 = _scala;
    _z = z.clamp(1.0, 4.0);
    final s1 = _scala;
    setState(() => _pos = _blocca(fuoco - (fuoco - _pos) * (s1 / s0)));
  }

  Future<void> _salva() async {
    setState(() => _salvo = true);
    try {
      const w = 1800.0, h = w / proporzioneCopertina;
      final s = _scala;
      final src = Rect.fromLTWH(-_pos.dx / s, -_pos.dy / s, _cornice.width / s, _cornice.height / s);
      final rec = ui.PictureRecorder();
      Canvas(rec).drawImageRect(_img!, src, const Rect.fromLTWH(0, 0, w, h), Paint()..filterQuality = FilterQuality.high);
      final out = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final dati = await out.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${Directory.systemTemp.path}/copertina-${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(dati!.buffer.asUint8List());
      if (mounted) Navigator.pop(context, file);
    } catch (_) {
      if (mounted) {
        setState(() => _salvo = false);
        messaggio(context, 'Non sono riuscito a preparare la foto: riprova o scegline un\'altra.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sistema la copertina')),
    body: _img == null
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (c, box) {
                      // cornice larga quanto lo schermo (meno i margini), alta un terzo, al centro dell'area
                      final larga = box.maxWidth - 32;
                      final alta = larga / proporzioneCopertina;
                      _imposta(Rect.fromLTWH(16, (box.maxHeight - alta) / 2, larga, alta));
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (d) {
                          _z0 = _z;
                          _p0 = _pos;
                          _f0 = d.localFocalPoint - _cornice.topLeft;
                        },
                        onScaleUpdate: (d) {
                          final f = d.localFocalPoint - _cornice.topLeft;
                          final s0 = _base * _z0;
                          _z = (_z0 * d.scale).clamp(1.0, 4.0);
                          final s1 = _scala;
                          setState(() => _pos = _blocca(f - (_f0 - _p0) * (s1 / s0)));
                        },
                        // la foto ingrandita non esce dall'area (sotto c'è il testo d'aiuto)
                        child: ClipRect(
                          child: CustomPaint(
                            size: Size(box.maxWidth, box.maxHeight),
                            painter: _Pittore(_img!, _cornice, _pos, _scala),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    'Trascina la foto per scegliere la parte da mostrare. Con due dita, o col cursore, la ingrandisci. '
                    'Quello che vedi nella cornice è la tua copertina.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: testo2, fontSize: 13.5, height: 1.4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_out, color: muto),
                      Expanded(
                        child: Slider(
                          value: _z,
                          min: 1,
                          max: 4,
                          activeColor: terracotta,
                          onChanged: (v) => _zoom(v, _cornice.size.center(Offset.zero)),
                        ),
                      ),
                      const Icon(Icons.zoom_in, color: muto),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _salvo ? null : () => Navigator.pop(context),
                          child: const Text('Annulla'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: BottoneCaldo(testo: 'Salva la copertina', occupato: _salvo, onPressed: _salva),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
  );
}

class _Pittore extends CustomPainter {
  _Pittore(this.img, this.cornice, this.pos, this.scala);

  final ui.Image img;
  final Rect cornice;
  final Offset pos;
  final double scala;

  @override
  void paint(Canvas canvas, Size size) {
    final dove = Rect.fromLTWH(cornice.left + pos.dx, cornice.top + pos.dy, img.width * scala, img.height * scala);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dove,
        Paint()..filterQuality = FilterQuality.medium);
    // fuori dalla cornice la foto resta visibile ma scurita: si capisce cosa resta fuori
    final fuori = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(cornice, const Radius.circular(10)));
    canvas.drawPath(fuori, Paint()..color = const Color(0xB3000000));
    canvas.drawRRect(
      RRect.fromRectAndRadius(cornice, const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xE6FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_Pittore old) => old.pos != pos || old.scala != scala || old.cornice != cornice || old.img != img;
}
