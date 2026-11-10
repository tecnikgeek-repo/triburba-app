// In cima alla Home, come un social vero: la carta «Cosa succede a …?» con le scorciatoie Foto / Attività / Sondaggio
// e la fila «Da fare» (schede orizzontali come le storie), uguale a quella del sito: le dà il server
// (/app/v1/da-fare) e ogni scheda porta dritta all'azione. Qui anche la schermata «Nuovi vicini» col tasto
// «Dai il benvenuto».
import 'package:flutter/material.dart';

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
    if (io == null || !io.puoPubblicare) return const SizedBox.shrink();
    final dove = io.casa?['nome'];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(color: superficie, borderRadius: BorderRadius.circular(16), border: Border.all(color: linea)),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(onTap: () => apriUtente(context, io.username), child: FotoProfilo(faccia: io.faccia, lato: 42)),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: () => _scrivi(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(99), border: Border.all(color: linea2)),
                    child: Text(
                      dove != null ? 'Cosa succede a $dove?' : 'Cosa succede nel quartiere?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muto, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _scorciatoia(context, Icons.image_outlined, 'Foto', golfo, () => _scrivi(context, foto: true)),
              _scorciatoia(context, Icons.handshake_outlined, 'Attività', terracotta, () => _scrivi(context, tipo: 'attivita')),
              _scorciatoia(context, Icons.how_to_vote_outlined, 'Sondaggio', oro, () => _scrivi(context, tipo: 'sondaggio')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scorciatoia(BuildContext context, IconData i, String t, Color c, VoidCallback f) => Expanded(
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: f,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(i, size: 20, color: c),
            const SizedBox(width: 6),
            Flexible(
              child: Text(t, overflow: TextOverflow.ellipsis, style: const TextStyle(color: testo2, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// La fila «Da fare». Se non c'è niente da fare non occupa spazio.
class FilaDaFare extends StatefulWidget {
  const FilaDaFare({super.key, this.voci});

  /// Solo per le anteprime: voci già pronte, senza rete.
  final List<Map<String, dynamic>>? voci;

  @override
  State<FilaDaFare> createState() => FilaDaFareState();
}

class FilaDaFareState extends State<FilaDaFare> {
  List<Map<String, dynamic>>? _voci;

  @override
  void initState() {
    super.initState();
    _voci = widget.voci;
    if (_voci == null) aggiorna();
  }

  Future<void> aggiorna() async {
    try {
      final v = await stato.api.daFare();
      if (mounted) setState(() => _voci = v);
    } on ErroreApi {
      // senza rete la fila semplicemente non si vede
    }
  }

  Future<void> _apri(Map<String, dynamic> v) async {
    await apriDestinazione(context, (v['app'] as Map).cast<String, dynamic>());
    aggiorna();
    stato.ricarica();
  }

  @override
  Widget build(BuildContext context) {
    final voci = _voci ?? const [];
    if (voci.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: terracotta),
                const SizedBox(width: 6),
                Text('Da fare', style: titolo(16)),
                const Spacer(),
                Text(voci.length == 1 ? '1 cosa per te' : '${voci.length} cose per te', style: const TextStyle(color: muto, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 206,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: voci.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _carta(voci[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carta(Map<String, dynamic> v) {
    final gruppo = '${v['gruppo']}';
    final tinta = switch (gruppo) {
      'moderazione' => oro,
      'admin' => const Color(0xFF7B4BD6),
      'profilo' => golfo,
      _ => terracotta,
    };
    final numero = v['numero'];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _apri(v),
        child: Ink(
          width: 158,
          padding: const EdgeInsets.fromLTRB(13, 14, 13, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: linea2),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.alphaBlend(tinta.withValues(alpha: .18), superficie), superficie],
              stops: const [0, .62],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(gradient: gradiente, borderRadius: BorderRadius.circular(14)),
                    child: Center(child: iconaDaFare('${v['icona']}', lato: 25)),
                  ),
                  if (numero != null && '$numero'.isNotEmpty)
                    Positioned(
                      top: -7,
                      right: -14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: vernice, borderRadius: BorderRadius.circular(99), border: Border.all(color: linea2)),
                        child: Text('$numero', style: const TextStyle(color: testo, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('${v['titolo']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.2)),
              const SizedBox(height: 4),
              Text('${v['testo']}', maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: testo2, fontSize: 12.5, height: 1.3)),
              const Spacer(),
              Row(
                children: [
                  Flexible(
                    child: Text('${v['tasto']}', overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: terracotta, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward, size: 14, color: terracotta),
                ],
              ),
            ],
          ),
        ),
      ),
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
          ? Center(child: _errore != null ? Text(_errore!, style: const TextStyle(color: muto)) : const CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                children: [
                  Text(
                    dove != null
                        ? 'Sono appena arrivati a $dove: un saluto fa sentire a casa.'
                        : 'Sono appena arrivati nel tuo quartiere: un saluto fa sentire a casa.',
                    style: const TextStyle(color: muto, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  if (p.isEmpty) const Vuoto(icona: Icons.waving_hand_outlined, testo: 'Questa settimana non è arrivato nessuno di nuovo.'),
                  for (final x in p)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: superficie, borderRadius: BorderRadius.circular(14), border: Border.all(color: linea)),
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
                                Text('${(x['faccia'] as Map)['nome']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('arrivato ${x['quando']}', style: const TextStyle(color: muto, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          if (x['salutato'] == true)
                            const Chip2(testo: 'Salutato', icona: Icons.check, colore: golfo, tenue: true)
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
