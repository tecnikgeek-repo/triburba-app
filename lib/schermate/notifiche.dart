// Notifiche: chi ha fatto cosa sui tuoi post, garanzie dei vicini, menzioni; tocco = apre la schermata giusta.
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import '../widget/lista_post.dart';
import 'naviga.dart';
import 'preferenze_notifiche.dart';

class SchermataNotifiche extends StatefulWidget {
  const SchermataNotifiche({super.key});

  @override
  State<SchermataNotifiche> createState() => SchermataNotificheState();
}

class SchermataNotificheState extends State<SchermataNotifiche> {
  List<Notifica>? _n;
  String? _errore;

  @override
  void initState() {
    super.initState();
    aggiorna();
  }

  Future<void> aggiorna() async {
    try {
      final (n, nuove) = await stato.api.notifiche();
      if (!mounted) return;
      setState(() {
        _n = n;
        _errore = null;
      });
      stato.impostaNotifiche(nuove);
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _tutteLette() async {
    try {
      stato.impostaNotifiche(await stato.api.segnaLette());
      setState(() {
        for (final x in _n ?? <Notifica>[]) {
          x.letta = true;
        }
      });
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  void _apri(Notifica n) {
    if (!n.letta) {
      setState(() => n.letta = true);
      stato.api.segnaLette(id: n.id).then(stato.impostaNotifiche).catchError((_) {});
    }
    apriDestinazione(context, n.vai);
  }

  IconData _icona(String i) => switch (i) {
    'comment' => Icons.chat_bubble_rounded,
    'chat' => Icons.alternate_email_rounded,
    'heart' => Icons.favorite_rounded,
    'users' => Icons.groups_rounded,
    'handshake' => Icons.handshake_rounded,
    'check' => Icons.verified_rounded,
    'tamtam' => Icons.campaign_rounded,
    'eye-off' => Icons.visibility_off_rounded,
    'vote' => Icons.how_to_vote_rounded,
    'sparkle' => Icons.auto_awesome_rounded,
    'camera' => Icons.photo_camera_rounded,
    'cake' => Icons.cake_rounded,
    'map' || 'pin' => Icons.place_rounded,
    _ => Icons.notifications_rounded,
  };

  Color _colore(String i) => switch (i) {
    'heart' => pompeiano,
    'comment' || 'chat' => golfo,
    'check' || 'handshake' => oro,
    'eye-off' => muto,
    'cake' => const Color(0xFFD94F7A),
    _ => terracotta,
  };

  @override
  Widget build(BuildContext context) {
    final n = _n;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifiche'),
        actions: [
          if (n != null && n.any((x) => !x.letta)) TextButton(onPressed: _tutteLette, child: const Text('Segna tutte lette')),
          IconButton(
            tooltip: 'Scegli cosa ricevere',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataPreferenzeNotifiche())),
          ),
        ],
      ),
      body: n == null
          ? Center(
              child: _errore == null ? const CircularProgressIndicator() : Text(_errore!, style: const TextStyle(color: muto)),
            )
          : RefreshIndicator(
              onRefresh: aggiorna,
              child: n.isEmpty
                  ? ListView(
                      children: const [
                        Vuoto(
                          icona: Icons.notifications_none_rounded,
                          testo: 'Nessuna notifica. Quando qualcuno reagisce o ti risponde, lo trovi qui.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: n.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                      itemBuilder: (c, i) {
                        final x = n[i];
                        return Material(
                          color: x.letta ? Colors.transparent : terracotta.withValues(alpha: .07),
                          child: InkWell(
                            onTap: () => _apri(x),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      x.chi != null
                                          ? FotoProfilo(faccia: x.chi!, lato: 46)
                                          : Container(
                                              width: 46,
                                              height: 46,
                                              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: gradiente),
                                              child: const Icon(Icons.groups_rounded, color: bianco),
                                            ),
                                      Positioned(
                                        right: -3,
                                        bottom: -3,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: _colore(x.icona),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: vernice, width: 2),
                                          ),
                                          child: Icon(_icona(x.icona), size: 12, color: bianco),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              if (x.chi != null)
                                                TextSpan(
                                                  text: '${x.chi!.nome} ',
                                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                                ),
                                              TextSpan(text: x.frase),
                                            ],
                                          ),
                                          style: const TextStyle(fontSize: 14.5, height: 1.35),
                                        ),
                                        if (x.testo.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              x.testo,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: testo2, fontSize: 13.5),
                                            ),
                                          ),
                                        const SizedBox(height: 3),
                                        Text(
                                          x.quando,
                                          style: TextStyle(color: x.letta ? muto : terracotta, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!x.letta)
                                    Container(
                                      margin: const EdgeInsets.only(top: 6, left: 6),
                                      width: 9,
                                      height: 9,
                                      decoration: const BoxDecoration(color: terracotta, shape: BoxShape.circle),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
