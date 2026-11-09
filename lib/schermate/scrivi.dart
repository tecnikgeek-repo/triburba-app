// Scrivere un post nel proprio quartiere: testo con grassetto e colori, foto, e fin dove mandarlo.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import '../widget/testo_ricco.dart';

/// Ritorna il post pubblicato (o null se annullato).
Future<Post?> apriScrivi(BuildContext context) =>
    Navigator.of(context).push<Post>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const SchermataScrivi()));

class SchermataScrivi extends StatefulWidget {
  const SchermataScrivi({super.key});

  @override
  State<SchermataScrivi> createState() => _SchermataScriviState();
}

class _SchermataScriviState extends State<SchermataScrivi> {
  final _campo = TextEditingController();
  File? _foto;
  String _portata = 'quartiere';
  bool _invio = false;
  bool _anteprima = false;

  @override
  void initState() {
    super.initState();
    _campo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  /// Avvolge la parte selezionata (o mette i segni dove c'è il cursore).
  void _avvolgi(String apri, String chiudi) {
    final s = _campo.selection;
    final t = _campo.text;
    if (!s.isValid) {
      _campo.text = '$t$apri$chiudi';
      return;
    }
    final scelto = t.substring(s.start, s.end);
    final nuovo = t.replaceRange(s.start, s.end, '$apri$scelto$chiudi');
    _campo.value = TextEditingValue(
      text: nuovo,
      selection: scelto.isEmpty
          ? TextSelection.collapsed(offset: s.start + apri.length)
          : TextSelection(baseOffset: s.start + apri.length, extentOffset: s.start + apri.length + scelto.length),
    );
  }

  Future<void> _scegliFoto(ImageSource da) async {
    final x = await ImagePicker().pickImage(source: da, maxWidth: 2000, maxHeight: 2000, imageQuality: 88);
    if (x != null) setState(() => _foto = File(x.path));
  }

  Future<void> _pubblica() async {
    final t = _campo.text.trim();
    if (t.isEmpty) {
      messaggio(context, 'Scrivi qualcosa prima di pubblicare.');
      return;
    }
    setState(() => _invio = true);
    try {
      final (post, msg) = await stato.api.pubblica(t, foto: _foto, portata: _portata);
      if (!mounted) return;
      messaggio(context, msg);
      Navigator.pop(context, post);
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final io = stato.io!;
    final casa = io.casa;
    final max = io.maxPost;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), tooltip: 'Annulla'),
        title: const Text('Nuovo post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 120,
              child: BottoneCaldo(testo: 'Pubblica', occupato: _invio, onPressed: _campo.text.trim().isEmpty ? null : _pubblica),
            ),
          ),
        ],
      ),
      body: !io.puoPubblicare
          ? Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.how_to_reg_outlined, size: 54, color: oro),
                  const SizedBox(height: 14),
                  Text(
                    casa == null ? 'Prima scegli il tuo quartiere' : 'La tua residenza è in attesa',
                    style: titolo(22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    casa == null
                        ? 'Su triburba si scrive nella propria tribù: scegli il quartiere dove abiti dalla mappa.'
                        : 'Per pubblicare a ${casa['nome']} servono le garanzie di ${io.viciniGaranti} già confermati. Intanto puoi leggere, reagire e commentare.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: testo2, height: 1.45),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    FotoProfilo(faccia: io.faccia, lato: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(io.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (casa != null) Text('Nella tribù di ${casa['nome']}', style: const TextStyle(color: muto, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_anteprima)
                  Carta(child: TestoRicco(_campo.text.isEmpty ? ' ' : _campo.text))
                else
                  TextField(
                    controller: _campo,
                    autofocus: true,
                    minLines: 6,
                    maxLines: 14,
                    maxLength: max > 0 ? max : null,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 17, height: 1.4),
                    decoration: const InputDecoration(hintText: 'Cosa succede nel quartiere?'),
                  ),
                // grassetto, colori, anteprima, @tribu
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _tasto(
                      const Text('B', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      'Grassetto',
                      () => _avvolgi('**', '**'),
                    ),
                    for (final e in coloriTesto.entries)
                      _tasto(
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(color: e.value, shape: BoxShape.circle),
                        ),
                        'Colore ${e.key}',
                        () => _avvolgi('{${e.key}}', '{/}'),
                      ),
                    _tasto(
                      const Text(
                        '@tribu',
                        style: TextStyle(color: oro, fontWeight: FontWeight.w800, fontSize: 12.5),
                      ),
                      'Avvisa tutta la tua tribù (una volta al giorno)',
                      () => _avvolgi('@tribu ', ''),
                    ),
                    _tasto(
                      Icon(_anteprima ? Icons.edit_outlined : Icons.visibility_outlined, size: 19),
                      _anteprima ? 'Scrivi' : 'Anteprima',
                      () => setState(() => _anteprima = !_anteprima),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_foto != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_foto!, height: 220, width: double.infinity, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: () => setState(() => _foto = null),
                          icon: const Icon(Icons.close, color: bianco),
                          tooltip: 'Togli la foto',
                        ),
                      ),
                    ],
                  )
                else if (io.fotoPost)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _scegliFoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_outlined),
                          label: const Text('Foto'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _scegliFoto(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Scatta'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                const Text(
                  'FIN DOVE ARRIVA',
                  style: TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
                ),
                const SizedBox(height: 8),
                _scelta('quartiere', Icons.place_outlined, 'Solo il mio quartiere', 'Lo vedono la tua tribù e chi la segue.'),
                _scelta(
                  'municipalita',
                  Icons.layers_outlined,
                  casa?['citta'] == 'Napoli' ? 'Tutta la municipalità' : 'Tutto il comune',
                  'Arriva subito in tutti i quartieri della ${casa?['municipalita'] ?? 'municipalità'}.',
                ),
                _scelta(
                  'citta',
                  Icons.location_city,
                  io.tamtam['grande'] ?? 'Verso tutta Napoli',
                  io.tamtam['nota'] ?? 'Arriva quando lo rilanciano residenti di altri quartieri.',
                ),
                const SizedBox(height: 10),
                const Text(
                  'Le foto passano un controllo automatico. Ricorda il regolamento: rispetto per tutti, niente dati personali di altri.',
                  style: TextStyle(color: muto, fontSize: 12, height: 1.4),
                ),
              ],
            ),
    );
  }

  Widget _tasto(Widget dentro, String aiuto, VoidCallback f) => Tooltip(
    message: aiuto,
    child: Material(
      color: superficie2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: f,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: dentro),
      ),
    ),
  );

  Widget _scelta(String id, IconData ico, String t, String s) {
    final on = _portata == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on ? terracotta.withValues(alpha: .16) : superficie,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _portata = id),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? terracotta : linea, width: on ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(ico, color: on ? terracotta : testo2),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s, style: const TextStyle(color: muto, fontSize: 12.5, height: 1.3)),
                    ],
                  ),
                ),
                Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? terracotta : muto),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
