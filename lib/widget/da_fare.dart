// In cima alla Home, come un social vero: la carta «Cosa succede a …?» con le scorciatoie Foto / Attività / Sondaggio
// e «Da fare» a fisarmonica (banner + elenco), uguale a quello del sito: le voci le dà il server
// (/app/v1/da-fare) e ogni scheda porta dritta all'azione. Qui anche la schermata «Nuovi vicini» col tasto
// «Dai il benvenuto».
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../schermate/naviga.dart';
import '../schermate/scrivi.dart';
import '../tema.dart';
import 'faccia.dart';
import 'icona_tk.dart';
import 'lista_post.dart';

/// Icone del sito → icone dell'app (le stesse del web dove c'è un disegno nostro).
Widget iconaDaFare(String nome, {double lato = 24, Color colore = bianco}) {
  if (nome == 'tamtam' || nome == 'heart' || nome == 'share') {
    return IconaTk(nome, lato: lato, colore: colore);
  }
  final i = switch (nome) {
    'camera' => Icons.photo_camera_outlined,
    'pin' => Icons.place_outlined,
    'handshake' => Icons.handshake_outlined,
    'users' => Icons.groups_outlined,
    'edit' => Icons.edit_outlined,
    'vote' => Icons.how_to_vote_outlined,
    'flag' => Icons.flag_outlined,
    'book' => Icons.menu_book_outlined,
    'shield' => Icons.shield_outlined,
    'image' => Icons.image_outlined,
    'user' => Icons.person_outline,
    _ => Icons.auto_awesome_outlined,
  };
  return Icon(i, size: lato, color: colore);
}

/// Carta in cima alla Home: foto, «Cosa succede a …?», scorciatoie. Chi non può ancora scrivere non la vede.
class TestataHome extends StatelessWidget {
  const TestataHome({super.key, this.onScritto});

  final VoidCallback? onScritto;

  Future<void> _scrivi(BuildContext context, {String tipo = 'post', bool foto = false}) async {
    final p = await apriScrivi(context, tipo: tipo, foto: foto);
    if (p != null) onScritto?.call();
  }

  @override
  Widget build(BuildContext context) {
    final io = stato.io;
    if (io == null || (!io.puoPubblicare && !io.puoBacheca)) return const SizedBox.shrink();
    final dove = io.casa?['nome'];
    // chi non è ancora residente scrive solo sulla propria bacheca: niente attività né sondaggi
    final soloBacheca = !io.puoPubblicare;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: linea),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => apriUtente(context, io.username),
                child: FotoProfilo(faccia: io.faccia, lato: 42),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => _scrivi(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: superficie2,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: linea2),
                    ),
                    child: Text(
                      soloBacheca ? 'Scrivi sulla tua bacheca…' : (dove != null ? 'Cosa succede a $dove?' : 'Cosa succede nel quartiere?'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muto, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // tre voci a distanze uguali (con tre terzi uguali «Foto» corta e «Sondaggio» lunga sembravano spostate a destra)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _scorciatoia(context, Icons.image_outlined, 'Foto', golfo, () => _scrivi(context, foto: true)),
              if (!soloBacheca) ...[
                _scorciatoia(context, Icons.handshake_outlined, 'Attività', terracotta, () => _scrivi(context, tipo: 'attivita')),
                _scorciatoia(context, Icons.how_to_vote_outlined, 'Sondaggio', oro, () => _scrivi(context, tipo: 'sondaggio')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _scorciatoia(BuildContext context, IconData i, String t, Color c, VoidCallback f) => Flexible(
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: f,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 20, color: c),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                t,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: testo2, fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// «Da fare» a fisarmonica, come sul sito (26/11/2026): il banner dice quante cose ci sono; toccandolo si apre
/// l'elenco. Aperto o chiuso resta come l'ha lasciato la persona. Ogni voce ha la ✕ «Non ora» (pausa di qualche
/// giorno decisa in Admin, torna prima se il numero cresce). Se non c'è niente da fare non occupa spazio.
class FilaDaFare extends StatefulWidget {
  const FilaDaFare({super.key, this.voci, this.aperto});

  /// Solo per le anteprime: voci già pronte, senza rete.
  final List<Map<String, dynamic>>? voci;

  /// Solo per le anteprime: aperta o chiusa senza leggere la scelta salvata.
  final bool? aperto;

  @override
  State<FilaDaFare> createState() => FilaDaFareState();
}

class FilaDaFareState extends State<FilaDaFare> {
  static const _chiaveAperto = 'tb_dafare_aperto';
  List<Map<String, dynamic>>? _voci;
  bool _aperto = false;

  @override
  void initState() {
    super.initState();
    _voci = widget.voci;
    _aperto = widget.aperto ?? false;
    if (widget.aperto == null) _leggiAperto();
    if (_voci == null) aggiorna();
  }

  Future<void> _leggiAperto() async {
    try {
      final a = (await SharedPreferences.getInstance()).getBool(_chiaveAperto) ?? false;
      if (mounted && a != _aperto) setState(() => _aperto = a);
    } catch (_) {
      // niente archivio: resta chiusa
    }
  }

  void _giraAperto() {
    setState(() => _aperto = !_aperto);
    final a = _aperto;
    SharedPreferences.getInstance().then((p) => p.setBool(_chiaveAperto, a)).catchError((_) => false);
  }

  Future<void> aggiorna() async {
    try {
      final v = await stato.api.daFare();
      if (mounted) setState(() => _voci = v);
    } on ErroreApi {
      // senza rete il riquadro semplicemente non si vede
    }
  }

  Future<void> _apri(Map<String, dynamic> v) async {
    await apriDestinazione(context, (v['app'] as Map).cast<String, dynamic>());
    aggiorna();
    stato.ricarica();
  }

  /// ✕ «Non ora»: la voce sparisce subito; il server la rimette fuori più avanti
  void _nonOra(Map<String, dynamic> v) {
    setState(() => _voci = [...?_voci]..remove(v));
    final chiudi = v['chiudi'];
    final numero = v['numero'] is int ? v['numero'] : null;
    final f = chiudi != null ? stato.api.guida('$chiudi') : stato.api.daFareChiudi('${v['chiave']}', numero);
    f.catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final voci = _voci ?? const [];
    if (voci.isEmpty) return const SizedBox.shrink();
    final n = voci.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 14, 10, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: terracotta.withValues(alpha: .35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(terracotta.withValues(alpha: .22), superficie),
            superficie,
            Color.alphaBlend(oro.withValues(alpha: .12), superficie),
          ],
          stops: const [0, .55, 1],
        ),
        boxShadow: [BoxShadow(color: terracotta.withValues(alpha: .28), blurRadius: 34, spreadRadius: -20, offset: const Offset(0, 16))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _aperto,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _giraAperto,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: gradiente,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(color: terracotta.withValues(alpha: .55), blurRadius: 18, spreadRadius: -8, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: const Center(child: Icon(Icons.auto_awesome, size: 25, color: bianco)),
                        ),
                        Positioned(
                          top: -7,
                          right: -9,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 24),
                            height: 24,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5484D),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: superficie, width: 2),
                            ),
                            child: Text('$n', style: const TextStyle(color: bianco, fontSize: 12, fontWeight: FontWeight.w800, height: 1)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Da fare', style: titolo(21)),
                          const SizedBox(height: 2),
                          Text(n == 1 ? '1 cosa per te' : '$n cose per te', style: TextStyle(color: testo2, fontSize: 14)),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _aperto ? .5 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: superficie2, shape: BoxShape.circle, border: Border.all(color: linea)),
                        child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: testo2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _aperto
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        children: [
                          for (var i = 0; i < n; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _riga(voci[i]),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  /// Una voce: icona, titolo e testo, tasto sotto (come sul sito da telefono), ✕ «Non ora» a destra
  Widget _riga(Map<String, dynamic> v) {
    final numero = v['numero'];
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _apri(v),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 12, 46, 12),
              decoration: BoxDecoration(
                color: superficie2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: linea),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(gradient: gradiente, borderRadius: BorderRadius.circular(13)),
                            child: Center(child: iconaDaFare('${v['icona']}', lato: 23)),
                          ),
                          if (numero != null && '$numero'.isNotEmpty)
                            Positioned(
                              top: -6,
                              right: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: vernice,
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(color: linea2),
                                ),
                                child: Text('$numero', style: TextStyle(color: testo, fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${v['titolo']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.2),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${v['testo']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: testo2, fontSize: 12.5, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 58),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: terracotta.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${v['tasto']}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: terracotta, fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: terracotta),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 6,
          child: Center(
            child: IconButton(
              tooltip: 'Non ora: torna tra qualche giorno',
              visualDensity: VisualDensity.compact,
              iconSize: 15,
              style: IconButton.styleFrom(backgroundColor: superficie, foregroundColor: muto, minimumSize: const Size(28, 28)),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _nonOra(v),
            ),
          ),
        ),
      ],
    );
  }
}

/// Chi è arrivato nel mio quartiere negli ultimi 7 giorni, con «Dai il benvenuto».
class SchermataNuoviVicini extends StatefulWidget {
  const SchermataNuoviVicini({super.key, this.persone});

  /// Solo per le anteprime.
  final List<Map<String, dynamic>>? persone;

  @override
  State<SchermataNuoviVicini> createState() => _SchermataNuoviViciniState();
}

class _SchermataNuoviViciniState extends State<SchermataNuoviVicini> {
  List<Map<String, dynamic>>? _p;
  String? _errore;
  final _invio = <int>{};

  @override
  void initState() {
    super.initState();
    _p = widget.persone;
    if (_p == null) _carica();
  }

  Future<void> _carica() async {
    try {
      final p = await stato.api.nuoviVicini();
      if (mounted) setState(() => _p = p);
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _saluta(Map<String, dynamic> x) async {
    final id = (x['id'] as num).toInt();
    setState(() => _invio.add(id));
    try {
      final j = await stato.api.benvenuto(id);
      if (!mounted) return;
      setState(() => x['salutato'] = true);
      messaggio(context, '${j['msg']}');
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _invio.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final dove = stato.io?.casa?['nome'];
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovi vicini')),
      body: p == null
          ? Center(
              child: _errore != null ? Text(_errore!, style: TextStyle(color: muto)) : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                children: [
                  Text(
                    dove != null
                        ? 'Sono appena arrivati a $dove: un saluto fa sentire a casa.'
                        : 'Sono appena arrivati nel tuo quartiere: un saluto fa sentire a casa.',
                    style: TextStyle(color: muto, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (p.isEmpty) const Vuoto(icona: Icons.waving_hand_outlined, testo: 'Questa settimana non è arrivato nessuno di nuovo.'),
                  for (final x in p)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: superficie,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: linea),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => apriUtente(context, '${(x['faccia'] as Map)['username']}'),
                            child: FotoProfilo(faccia: Faccia((x['faccia'] as Map).cast<String, dynamic>()), lato: 44),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(x['faccia'] as Map)['nome']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text('arrivato ${x['quando']}', style: TextStyle(color: muto, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          if (x['salutato'] == true)
                            Chip2(testo: 'Salutato', icona: Icons.check, colore: golfo, tenue: true)
                          else
                            SizedBox(
                              width: 130,
                              child: BottoneCaldo(
                                testo: 'Benvenuto',
                                icona: Icons.waving_hand_outlined,
                                occupato: _invio.contains((x['id'] as num).toInt()),
                                onPressed: () => _saluta(x),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
