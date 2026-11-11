// Il profilo di una persona: copertina, foto, tribù, numeri, segui, e i suoi post.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import '../widget/lista_post.dart';
import 'bloccati.dart';
import 'naviga.dart';
import 'profilo.dart';

class SchermataUtente extends StatefulWidget {
  const SchermataUtente({super.key, required this.username, this.mio = false});

  final String username;

  /// Il proprio profilo dentro la barra in basso (senza freccia indietro, con le impostazioni).
  final bool mio;

  @override
  State<SchermataUtente> createState() => _SchermataUtenteState();
}

class _SchermataUtenteState extends State<SchermataUtente> {
  Map<String, dynamic>? _u;
  final _lista = GlobalKey<ListaPostState>();
  final _scorri = ScrollController();
  final _chiaveTesta = GlobalKey();
  bool _occupato = false;

  @override
  void dispose() {
    _scorri.dispose();
    super.dispose();
  }

  /// Il numero «post» scorre fino al primo post, sotto la testata del profilo
  void _vaiAiPost() {
    final h = _chiaveTesta.currentContext?.size?.height;
    if (h == null || !_scorri.hasClients) return;
    _scorri.animateTo(
      (h + 4).clamp(0, _scorri.position.maxScrollExtent).toDouble(),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  Future<(List<Post>, bool)> _carica(int prima) async {
    final j = await stato.api.utente(widget.username, prima: prima);
    if (prima == 0 && mounted) setState(() => _u = j['utente'] as Map<String, dynamic>);
    return ((j['post'] as List).map((p) => Post(p as Map<String, dynamic>)).toList(), j['altri'] == true);
  }

  Future<void> _segui() async {
    setState(() => _occupato = true);
    try {
      final j = await stato.api.segui(widget.username);
      if (!mounted) return;
      setState(() {
        _u!['seguo'] = j['following'] == true;
        (_u!['conti'] as Map)['followers'] = (j['counts'] as Map)['followers'];
      });
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _u;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.mio,
        title: Text(widget.mio ? 'Profilo' : (u == null ? '' : '${u['nome']}')),
        actions: [
          if (!widget.mio && u != null && u['io'] != true && widget.username != 'triburba.it')
            PopupMenuButton<String>(
              tooltip: 'Altre azioni',
              onSelected: (v) async {
                final sblocca = u['bloccato'] == true;
                if (await bloccaPersona(context, widget.username, '${u['nome']}', sblocca: sblocca) && mounted) {
                  setState(() => u['bloccato'] = !sblocca);
                  _lista.currentState?.aggiorna();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'blocca',
                  child: Row(
                    children: [
                      Icon(u['bloccato'] == true ? Icons.lock_open_rounded : Icons.block_rounded, color: u['bloccato'] == true ? testo : pompeiano),
                      const SizedBox(width: 10),
                      Text(u['bloccato'] == true ? 'Sblocca' : 'Blocca'),
                    ],
                  ),
                ),
              ],
            ),
          if (widget.mio)
            IconButton(
              tooltip: 'Impostazioni',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataImpostazioni()));
                _lista.currentState?.aggiorna();
              },
            ),
        ],
      ),
      body: ListaPost(
        key: _lista,
        controller: _scorri,
        carica: _carica,
        testa: u == null ? null : KeyedSubtree(key: _chiaveTesta, child: _testa(u)),
        vuoto: Vuoto(
          icona: Icons.edit_note_rounded,
          testo: u?['io'] == true ? 'Non hai ancora scritto niente. Il tuo quartiere ti aspetta!' : 'Non ha ancora scritto niente.',
        ),
      ),
    );
  }

  /// Proprio profilo incompleto: barra discreta «Profilo completo al 60%» con i pezzi mancanti (come sul sito).
  Widget _completa(Map<String, dynamic> u) {
    String? v(String k) => (u[k] as String?)?.trim().isNotEmpty == true ? u[k] as String : null;
    final pezzi = <(String, String, bool)>[
      ('Foto', 'avatar', v('foto') != null),
      ('Quartiere', 'casa', u['casa'] != null),
      ('Due righe su di te', 'bio', v('bio') != null),
      ('Professione', 'occupation', v('lavoro') != null),
      ('Copertina', 'cover', v('copertina') != null),
    ];
    final mancano = pezzi.where((p) => !p.$3).toList();
    if (mancano.isEmpty) return const SizedBox.shrink();
    final perc = ((pezzi.length - mancano.length) / pezzi.length * 100).round();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: superficie, borderRadius: BorderRadius.circular(14), border: Border.all(color: linea)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Profilo completo al $perc%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Stack(children: [
                    Container(height: 6, color: linea2),
                    FractionallySizedBox(widthFactor: perc / 100, child: Container(height: 6, decoration: const BoxDecoration(gradient: gradiente))),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Manca:', style: TextStyle(color: muto, fontSize: 12.5)),
              for (final m in mancano)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16, color: terracotta),
                  label: Text(m.$1),
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 12.5, color: testo),
                  backgroundColor: terracotta.withValues(alpha: .14),
                  side: BorderSide(color: terracotta.withValues(alpha: .4)),
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await apriDestinazione(context, m.$2 == 'casa' ? {'tipo': 'mappa'} : {'tipo': 'modifica_profilo', 'campo': m.$2});
                    _lista.currentState?.aggiorna();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _testa(Map<String, dynamic> u) {
    final f = Faccia(u);
    final casa = u['casa'] as Map?;
    final conti = (u['conti'] as Map?) ?? const {};
    final att = (u['attivita'] as Map?) ?? const {};
    final copertina = img(u['copertina'] as String?);
    final io = u['io'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (io) _completa(u),
        SizedBox(
          height: 190,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                bottom: 40,
                child: copertina != null
                    ? GestureDetector(
                        onTap: () => apriFoto(context, copertina, titolo: f.nome, sottotitolo: 'Copertina'),
                        child: Hero(
                          tag: 'foto-$copertina',
                          child: CachedNetworkImage(imageUrl: copertina, fit: BoxFit.cover),
                        ),
                      )
                    : const DecoratedBox(decoration: BoxDecoration(gradient: gradiente)),
              ),
              Positioned(
                left: 16,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: vernice, shape: BoxShape.circle),
                  // tocco sulla foto: si apre grande (le iniziali senza foto non si aprono)
                  child: Builder(
                    builder: (context) {
                      final a = img(f.foto);
                      final apribile = a != null && !a.startsWith('data:');
                      final foto = FotoProfilo(faccia: f, lato: 88, anello: true);
                      if (!apribile) return foto;
                      return GestureDetector(
                        onTap: () => apriFoto(context, a, titolo: f.nome, sottotitolo: 'Foto profilo · @${f.username}', tondo: true),
                        child: Hero(tag: 'foto-$a', child: foto),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 0,
                child: io
                    ? OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataModificaProfilo()));
                          _lista.currentState?.aggiorna();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Modifica'),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 130),
                        child: u['seguo'] == true
                            ? OutlinedButton.icon(
                                onPressed: _occupato ? null : _segui,
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Segui già'),
                              )
                            : BottoneCaldo(testo: 'Segui', icona: Icons.person_add_alt_1, occupato: _occupato, onPressed: _segui),
                      ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(f.nome, style: titolo(24))),
                  const SizedBox(width: 6),
                  StemmaMini(stemma: f.stemma, altezza: 34),
                  if (f.bot) ...[const SizedBox(width: 6), const PillaProva()],
                ],
              ),
              Text('@${f.username}', style: const TextStyle(color: muto)),
              if (u['compleanno'] is Map) _compleanno(u, io, f),
              if ((u['bio'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('${u['bio']}', style: const TextStyle(height: 1.4)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (casa != null)
                    Chip2(
                      testo: u['residente'] == true ? 'Tribù di ${casa['nome']}' : 'In attesa a ${casa['nome']}',
                      icona: Icons.place_outlined,
                      colore: colore('${casa['colore']}'),
                      onTap: () => apriQuartiere(context, '${casa['slug']}'),
                    ),
                  if ((u['lavoro'] as String?)?.isNotEmpty == true) _info(Icons.work_outline, '${u['lavoro']}'),
                  if ((u['luogo'] as String?)?.isNotEmpty == true) _info(Icons.location_on_outlined, '${u['luogo']}'),
                  if ((u['sito'] as String?)?.isNotEmpty == true)
                    GestureDetector(
                      onTap: () {
                        final s = '${u['sito']}';
                        launchUrl(Uri.parse(s.startsWith('http') ? s : 'https://$s'), mode: LaunchMode.externalApplication);
                      },
                      child: _info(Icons.link, '${u['sito']}'.replaceFirst(RegExp(r'^https?://'), ''), colore: golfo),
                    ),
                  if ((u['dal'] as String?)?.isNotEmpty == true) _info(Icons.calendar_today_outlined, 'Su triburba da ${u['dal']}'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _numero('${conti['post'] ?? 0}', 'post', onTap: _vaiAiPost),
                  _numero('${conti['followers'] ?? 0}', 'follower', onTap: () => apriFollow(context, f.username, f.nome)),
                  _numero('${conti['following'] ?? 0}', 'seguiti', onTap: () => apriFollow(context, f.username, f.nome, seguiti: true)),
                  _numero('${att['reazioni'] ?? 0}', 'reazioni'),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(),
            ],
          ),
        ),
      ],
    );
  }

  /// Il giorno del compleanno: pillola festosa e, per gli altri, il tasto «Fai gli auguri»
  Widget _compleanno(Map<String, dynamic> u, bool io, Faccia f) {
    final c = u['compleanno'] as Map<String, dynamic>;
    final fatto = c['fatto'] == true;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(colors: [terracotta, Color(0xFFD94F7A)]),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cake_rounded, size: 16, color: bianco),
                const SizedBox(width: 6),
                Text(io ? 'Oggi è il tuo compleanno!' : 'Oggi compie gli anni',
                    style: const TextStyle(color: bianco, fontWeight: FontWeight.w700, fontSize: 13.5)),
              ],
            ),
          ),
          if (c['auguri_possibili'] == true)
            fatto
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 18, color: Color(0xFF7FD6A6)),
                      SizedBox(width: 4),
                      Text('Auguri fatti', style: TextStyle(color: Color(0xFF7FD6A6), fontWeight: FontWeight.w700)),
                    ],
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: terracotta, foregroundColor: bianco, visualDensity: VisualDensity.compact),
                    onPressed: () async {
                      setState(() => c['fatto'] = true);
                      try {
                        final msg = await stato.api.auguri((c['id'] as num?)?.toInt() ?? 0);
                        if (mounted) messaggio(context, msg);
                      } on ErroreApi catch (e) {
                        if (!mounted) return;
                        setState(() => c['fatto'] = false);
                        messaggio(context, e.messaggio);
                      }
                    },
                    icon: const Icon(Icons.cake_outlined, size: 17),
                    label: Text('Fai gli auguri a ${f.nome.split(' ').first}'),
                  ),
        ],
      ),
    );
  }

  Widget _info(IconData i, String t, {Color colore = testo2}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 15, color: muto),
      const SizedBox(width: 4),
      Text(t, style: TextStyle(color: colore, fontSize: 13)),
    ],
  );

  Widget _numero(String n, String t, {VoidCallback? onTap}) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(n, style: titolo(20)),
            Text(t, style: TextStyle(color: onTap != null ? testo2 : muto, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
