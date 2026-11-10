// Aperture comuni: post, persone, quartieri, foto a tutto schermo, chi ha reagito.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/emoji.dart';
import '../widget/faccia.dart';
import 'package:share_plus/share_plus.dart';

import '../widget/da_fare.dart';
import 'admin.dart';
import 'follow.dart';
import 'moderazione.dart';
import 'profilo.dart';
import 'scrivi.dart';
import 'post.dart';
import 'quartiere.dart';
import 'tag.dart';
import 'utente.dart';

final chiaveNavigazione = GlobalKey<NavigatorState>();

Route<T> _via<T>(Widget w) => MaterialPageRoute<T>(builder: (_) => w);

Future<void> apriUtente(BuildContext context, String username) => Navigator.of(context).push(_via(SchermataUtente(username: username)));

Future<void> apriFollow(BuildContext context, String username, String nome, {bool seguiti = false}) =>
    Navigator.of(context).push(_via(SchermataFollow(username: username, nome: nome, seguiti: seguiti)));

Future<void> apriQuartiere(BuildContext context, String slug) => Navigator.of(context).push(_via(SchermataQuartiere(slug: slug)));

Future<void> apriPost(BuildContext context, int id, {Post? post, bool scrivi = false}) =>
    Navigator.of(context).push(_via(SchermataPost(id: id, post: post, scrivi: scrivi)));

Future<void> apriTag(BuildContext context, String tag) => Navigator.of(context).push(_via(SchermataTag(tag: tag)));

/// Schede della moderazione a cui si arriva dai link «?t=…» del sito e dalla fila «Da fare».
const schedeModerazione = {'moderatori': 'moderatori', 'proposti': 'proposte', 'proposte': 'proposte', 'segnalati': 'nascosti', 'nascosti': 'nascosti', 'regole': 'regole'};

/// Destinazione da notifica, link o scheda «Da fare»: porta sempre dritta alla schermata dell'azione.
/// {tipo: post|utente|quartiere (+scheda)|moderazione (+scheda)|tag|modifica_profilo (+campo)|admin|mappa|notifiche|
///  scrivi (+tipo)|feed|invito|nuovi_vicini|sito (+link)}
Future<void> apriDestinazione(BuildContext context, Map<String, dynamic> vai) async {
  switch (vai['tipo']) {
    case 'post':
      await apriPost(context, (vai['id'] as num).toInt());
    case 'utente':
      await apriUtente(context, '${vai['username']}');
    case 'quartiere':
      final scheda = '${vai['scheda'] ?? ''}';
      if (schedeModerazione.containsKey(scheda)) {
        await Navigator.of(context).push(_via(SchermataModerazione(slug: '${vai['slug']}', scheda: schedeModerazione[scheda]!)));
      } else {
        await Navigator.of(context).push(_via(SchermataQuartiere(slug: '${vai['slug']}', apriResidenti: scheda == 'residenti')));
      }
    case 'moderazione':
      await Navigator.of(context).push(_via(SchermataModerazione(slug: '${vai['slug']}', scheda: schedeModerazione['${vai['scheda']}'] ?? 'moderatori')));
    case 'tag':
      await apriTag(context, '${vai['tag']}');
    case 'modifica_profilo':
      await Navigator.of(context).push(_via(SchermataModificaProfilo(campo: '${vai['campo'] ?? ''}')));
    case 'admin':
      if (stato.io?.admin == true) await Navigator.of(context).push(_via(const SchermataAdmin()));
    case 'mappa' || 'notifiche':
      stato.apri({'tipo': vai['tipo']});
    case 'scrivi':
      await apriScrivi(context, tipo: '${vai['tipo_post'] ?? 'post'}');
    case 'nuovi_vicini':
      await Navigator.of(context).push(_via(const SchermataNuoviVicini()));
    case 'invito':
      final r = await SharePlus.instance.share(ShareParams(
        text: 'Ti aspetto su triburba, il social dei quartieri nato a Napoli: iscriviti e scegli il tuo quartiere.\n\n$sito/register',
      ));
      if (r.status == ShareResultStatus.success) {
        try {
          await stato.api.guida('invito');
        } catch (_) {}
      }
    case 'sito':
      // link che il server non ha tradotto: se lo riconosco lo apro nell'app (mai il browser)
      final d = destinazioneDaLink('${vai['link'] ?? ''}');
      if (d != null && d['tipo'] != 'sito' && context.mounted) await apriDestinazione(context, d);
    // 'feed' e voci sconosciute: si resta dove si è
  }
}

Future<void> apriFoto(BuildContext context, String url) => Navigator.of(context).push(
  PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (c, _, _) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: bianco),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    ),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ),
);

/// Chi ha reagito a un post, con la sua emoji e il quartiere.
Future<void> apriChiHaReagito(BuildContext context, int postId) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (c) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .6,
    maxChildSize: .92,
    builder: (c, scorri) => FutureBuilder<List<Map<String, dynamic>>>(
      future: stato.api.chiHaReagito(postId),
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: Text('${s.error}', style: const TextStyle(color: muto)),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final persone = s.data!;
        return ListView(
          controller: scorri,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Reazioni', style: titolo(22)),
            ),
            for (final r in persone)
              ListTile(
                leading: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FotoProfilo.da(nome: '${r['nome']}', avatar: r['avatar'] as String?, lato: 40),
                    Positioned(right: -4, bottom: -4, child: Emoji('${r['reazione']}', lato: 20)),
                  ],
                ),
                title: Text('${r['nome']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  r['quartiere'] == null ? '@${r['username']}' : '@${r['username']} · ${r['quartiere']}',
                  style: const TextStyle(color: muto),
                ),
                onTap: () {
                  Navigator.pop(c);
                  apriUtente(context, '${r['username']}');
                },
              ),
          ],
        );
      },
    ),
  ),
);

/// Indirizzo assoluto di un'immagine del sito per CachedNetworkImage (o null).
String? img(String? p) => assoluto(p);
