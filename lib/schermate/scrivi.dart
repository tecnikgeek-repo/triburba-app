// Scrivere un post nel proprio quartiere: testo con grassetto e colori, foto, e fin dove mandarlo.
// Può essere anche un'attività (parte solo con il minimo di persone entro la data limite) o un sondaggio.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import '../widget/testo_ricco.dart';
import '../widget/menzioni.dart';

/// Ritorna il post pubblicato (o null se annullato).
Future<Post?> apriScrivi(BuildContext context, {String tipo = 'post', bool foto = false}) =>
    Navigator.of(context).push<Post>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => SchermataScrivi(tipo: tipo, foto: foto)));

class SchermataScrivi extends StatefulWidget {
  const SchermataScrivi({super.key, this.tipo = 'post', this.foto = false});

  /// Dalle scorciatoie della Home: si apre già su Attività o Sondaggio, oppure con la scelta della foto.
  final String tipo;
  final bool foto;

  @override
  State<SchermataScrivi> createState() => _SchermataScriviState();
}

class _SchermataScriviState extends State<SchermataScrivi> {
  final _campo = TextEditingController();
  File? _foto;
  String _portata = 'quartiere';
  bool _invio = false;
  bool _anteprima = false;

  /// post, attivita, sondaggio
  late String _tipo = widget.tipo;

  // attività
  DateTime? _quando;
  DateTime? _scadenza;
  int _minimo = 0;
  final _luogo = TextEditingController();

  // sondaggio
  final List<TextEditingController> _risposte = [TextEditingController(), TextEditingController()];
  bool _multi = false;
  bool _soloResidenti = false;
  int _durata = 0;

  @override
  void initState() {
    super.initState();
    _campo.addListener(() => setState(() {}));
    if (widget.foto) WidgetsBinding.instance.addPostFrameCallback((_) => _scegliFoto(ImageSource.gallery));
  }

  @override
  void dispose() {
    _campo.dispose();
    _luogo.dispose();
    for (final c in _risposte) {
      c.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _scegliData(DateTime? attuale, {DateTime? prima}) async {
    final ora = DateTime.now();
    final base = attuale ?? (prima ?? ora.add(const Duration(days: 2))).copyWith(minute: 0);
    final d = await showDatePicker(
      context: context,
      initialDate: base.isBefore(ora) ? ora : base,
      firstDate: ora,
      lastDate: ora.add(const Duration(days: 365)),
      helpText: 'Scegli il giorno',
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base), helpText: 'Scegli l\'ora');
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String _leggibile(DateTime d) {
    const g = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
    const m = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
    return '${g[d.weekday - 1]} ${d.day} ${m[d.month - 1]}, ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// I campi in più per il sito, o un messaggio se manca qualcosa.
  (Map<String, String>?, String?) _extra() {
    if (_tipo == 'attivita') {
      if (_quando == null) return (null, 'Scegli giorno e ora dell\'attività.');
      final scad = _scadenza ?? _quando!.subtract(const Duration(hours: 1));
      return (
        {'tipo': 'attivita', 'quando': _iso(_quando!), 'scadenza': _iso(scad), 'minimo': '$_minimo', 'luogo': _luogo.text.trim()},
        null,
      );
    }
    if (_tipo == 'sondaggio') {
      final r = _risposte.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (r.length < 2) return (null, 'Scrivi almeno due risposte.');
      return (
        {
          'tipo': 'sondaggio',
          'opzioni': jsonEncode(r),
          'multi': _multi ? '1' : '0',
          'solo_residenti': _soloResidenti ? '1' : '0',
          'durata': '$_durata',
        },
        null,
      );
    }
    return (const {}, null);
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
    final (extra, errore) = _extra();
    if (errore != null) {
      messaggio(context, errore);
      return;
    }
    setState(() => _invio = true);
    try {
      final ovunque = _portata == 'ovunque';
      final (post, msg) = await stato.api.pubblica(
        t,
        foto: _foto,
        portata: ovunque ? 'quartiere' : _portata,
        extra: {...extra!, if (ovunque) 'ovunque': '1'},
      );
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
    if (_minimo < io.attivitaMin) _minimo = io.attivitaMin < 5 ? 5 : io.attivitaMin;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), tooltip: 'Annulla'),
        title: Text(switch (_tipo) {
          'attivita' => 'Nuova attività',
          'sondaggio' => 'Nuovo sondaggio',
          _ => 'Nuovo post',
        }),
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
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'post',
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text('Post', maxLines: 1, softWrap: false)),
                      icon: Icon(Icons.edit_note_rounded),
                    ),
                    ButtonSegment(
                      value: 'attivita',
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text('Attività', maxLines: 1, softWrap: false)),
                      icon: Icon(Icons.handshake_outlined),
                    ),
                    ButtonSegment(
                      value: 'sondaggio',
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text('Sondaggio', maxLines: 1, softWrap: false)),
                      icon: Icon(Icons.how_to_vote_outlined),
                    ),
                  ],
                  selected: {_tipo},
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? bianco : testo),
                    backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? terracotta : superficie),
                    side: const WidgetStatePropertyAll(BorderSide(color: linea2)),
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
                    iconSize: const WidgetStatePropertyAll(18),
                    textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w600)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: (v) => setState(() => _tipo = v.first),
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
                    decoration: InputDecoration(
                      hintText: switch (_tipo) {
                        'attivita' => 'Cosa proponi di fare insieme? Es. pulire il parco, una raccolta…',
                        'sondaggio' => 'Fai una domanda ai tuoi vicini…',
                        _ => 'Cosa succede nel quartiere?',
                      },
                    ),
                  ),
                if (!_anteprima) SuggerimentiMenzioni(campo: _campo),
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
                    if (io.superadmin)
                      _tasto(
                        const Text(
                          '@triburba',
                          style: TextStyle(color: oro, fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                        'Solo tu: avvisa tutti gli iscritti e il post arriva ovunque',
                        () => _avvolgi('@triburba ', ''),
                      ),
                    _tasto(
                      Icon(_anteprima ? Icons.edit_outlined : Icons.visibility_outlined, size: 19),
                      _anteprima ? 'Scrivi' : 'Anteprima',
                      () => setState(() => _anteprima = !_anteprima),
                    ),
                  ],
                ),
                if (_tipo == 'attivita') ..._campiAttivita(io),
                if (_tipo == 'sondaggio') ..._campiSondaggio(casa),
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
                if (io.superadmin)
                  _scelta('ovunque', Icons.public, 'Ovunque', 'Solo tu: lo vede tutta triburba, in ogni quartiere.'),
                const SizedBox(height: 10),
                const Text(
                  'Le foto passano un controllo automatico. Ricorda il regolamento: rispetto per tutti, niente dati personali di altri.',
                  style: TextStyle(color: muto, fontSize: 12, height: 1.4),
                ),
              ],
            ),
    );
  }

  Widget _sezione(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
    ),
  );

  Widget _riga(IconData ico, String t, String? valore, VoidCallback f) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: superficie,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: f,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: linea),
          ),
          child: Row(
            children: [
              Icon(ico, color: terracotta),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(
                valore ?? 'Scegli',
                style: TextStyle(color: valore == null ? muto : testo, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: muto),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _campiAttivita(Io io) => [
    _sezione('L\'attività'),
    const Text(
      'Parte solo se entro la data limite confermano almeno le persone che servono. Se non si arriva al minimo, avvisiamo tutti.',
      style: TextStyle(color: testo2, fontSize: 13, height: 1.4),
    ),
    const SizedBox(height: 10),
    _riga(Icons.event_outlined, 'Quando', _quando == null ? null : _leggibile(_quando!), () async {
      final d = await _scegliData(_quando);
      if (d != null) setState(() => _quando = d);
    }),
    _riga(
      Icons.hourglass_bottom_rounded,
      'Conferme entro',
      _scadenza != null ? _leggibile(_scadenza!) : (_quando != null ? _leggibile(_quando!.subtract(const Duration(hours: 1))) : null),
      () async {
        final d = await _scegliData(_scadenza, prima: _quando?.subtract(const Duration(hours: 1)));
        if (d != null) setState(() => _scadenza = d);
      },
    ),
    Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: linea),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, color: terracotta),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Persone che servono', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            tooltip: 'Meno',
            onPressed: _minimo > io.attivitaMin ? () => setState(() => _minimo--) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('$_minimo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          IconButton(
            tooltip: 'Più',
            onPressed: _minimo < 500 ? () => setState(() => _minimo++) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    ),
    const SizedBox(height: 8),
    TextField(
      controller: _luogo,
      maxLength: 120,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Dove (facoltativo): piazza, via, parco…', prefixIcon: Icon(Icons.place_outlined)),
    ),
  ];

  List<Widget> _campiSondaggio(Map<String, dynamic>? casa) => [
    _sezione('Le risposte'),
    for (var i = 0; i < _risposte.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _risposte[i],
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Risposta ${i + 1}',
            counterText: '',
            suffixIcon: _risposte.length > 2
                ? IconButton(
                    tooltip: 'Togli',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _risposte.removeAt(i).dispose()),
                  )
                : null,
          ),
        ),
      ),
    if (_risposte.length < 6)
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _risposte.add(TextEditingController())),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Aggiungi una risposta'),
        ),
      ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _multi,
      onChanged: (v) => setState(() => _multi = v),
      title: const Text('Più risposte a testa'),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _soloResidenti,
      onChanged: (v) => setState(() => _soloResidenti = v),
      title: Text('Votano solo i residenti di ${casa?['nome'] ?? 'casa tua'}'),
    ),
    const SizedBox(height: 4),
    const Text('Si chiude', style: TextStyle(fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (g, t) in const [(0, 'Mai'), (1, 'Tra 1 giorno'), (3, 'Tra 3 giorni'), (7, 'Tra 7 giorni')])
          ChoiceChip(label: Text(t), selected: _durata == g, onSelected: (_) => setState(() => _durata = g)),
      ],
    ),
  ];

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
