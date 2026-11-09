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
        SizedBox(
          height: 190,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                bottom: 40,
                child: copertina != null
                    ? CachedNetworkImage(imageUrl: copertina, fit: BoxFit.cover)
                    : const DecoratedBox(decoration: BoxDecoration(gradient: gradiente)),
              ),
              Positioned(
                left: 16,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: vernice, shape: BoxShape.circle),
                  child: FotoProfilo(faccia: f, lato: 88, anello: true),
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
