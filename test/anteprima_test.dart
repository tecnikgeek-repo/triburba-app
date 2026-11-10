// Foto delle schermate (caratteri veri, sito finto) in build/anteprime/, per guardarle senza telefono.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triburba/dati/api.dart';
import 'package:triburba/dati/modelli.dart';
import 'package:triburba/dati/stato.dart';
import 'package:triburba/main.dart';
import 'package:triburba/schermate/admin.dart';
import 'package:triburba/schermate/legale.dart';
import 'package:triburba/schermate/accesso.dart';
import 'package:triburba/schermate/feed.dart';
import 'package:triburba/schermate/follow.dart';
import 'package:triburba/schermate/home.dart';
import 'package:triburba/schermate/naviga.dart';
import 'package:triburba/schermate/post.dart';
import 'package:triburba/schermate/primo_accesso.dart';
import 'package:triburba/schermate/quartiere.dart';
import 'package:triburba/schermate/scrivi.dart';
import 'package:triburba/schermate/bloccati.dart';
import 'package:triburba/schermate/moderazione.dart';
import 'package:triburba/schermate/preferenze_notifiche.dart';
import 'package:triburba/schermate/profilo.dart';
import 'package:triburba/widget/post_card.dart';
import 'package:triburba/schermate/tag.dart';
import 'package:triburba/schermate/utente.dart';
import 'package:triburba/tema.dart';
import 'package:triburba/widget/emoji.dart';
import 'package:triburba/widget/da_fare.dart';
import 'package:triburba/schermate/notifiche.dart';

import 'caratteri.dart';
import 'admin_finto.dart';
import 'finto.dart';
import 'package:triburba/widget/mappa_disegno.dart';

Future<void> _scatta(WidgetTester t, Widget w, String nome, {Future<void> Function()? prima}) async {
  final k = GlobalKey();
  await t.pumpWidget(
    RepaintBoundary(
      key: k,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: chiaveNavigazione,
        theme: temaTriburba(),
        locale: const Locale('it'),
        supportedLocales: const [Locale('it')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: w,
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump(const Duration(milliseconds: 300));
  }
  await prima?.call();
  await t.runAsync(() async {
    final img = await (k.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/anteprime').createSync(recursive: true);
    File('build/anteprime/$nome.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 2));
}

Future<void> _carattere(String famiglia, List<String> file) async {
  final l = FontLoader(famiglia);
  for (final f in file) {
    l.addFont(Future.value(ByteData.view(Uint8List.fromList(File(f).readAsBytesSync()).buffer)));
  }
  await l.load();
}

void main() {
  setUpAll(() async {
    await caricaCaratteri();
    await _carattere('Inter', [
      for (final w in [400, 500, 600, 700, 800]) 'assets/font/Inter-$w.ttf',
    ]);
    await _carattere('Bricolage', [
      for (final w in [600, 700, 800]) 'assets/font/Bricolage-$w.ttf',
    ]);
    configTk = configTriburba;
    SharedPreferences.setMockInitialValues({'triburba_token': 'a' * 64});
    stato = Stato(Api(versione: '1.0.0', client: clientFinto()));
    await stato.api.caricaToken();
    stato.entra(Io(ioFinto));
  });

  testWidgets('anteprime', (t) async {
    t.view.physicalSize = const Size(1080, 2280);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);

    await _scatta(t, const Avvio(), '01-avvio');
    await _scatta(t, const SchermataBenvenuto(), '02-benvenuto');
    await _scatta(t, const SchermataAccesso(), '03-accesso');
    await _scatta(t, const SchermataHome(), '04-home');
    await _scatta(t, const SchermataPost(id: 1), '05-post');
    await _scatta(t, const SchermataScrivi(), '06-scrivi');
    await _scatta(t, const SchermataQuartiere(slug: 'borgo-fiorito'), '07-quartiere');
    await _scatta(
      t,
      const SchermataHome(),
      '08-mappa',
      prima: () async {
        await t.tap(find.byIcon(Icons.map_outlined));
        for (var i = 0; i < 3; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await t.pump(const Duration(milliseconds: 300));
        }
      },
    );
    // mappa allontanata fino alla Campania col cursore
    await _scatta(
      t,
      const SchermataHome(),
      '08b-mappa-campania',
      prima: () async {
        await t.tap(find.byIcon(Icons.map_outlined));
        for (var i = 0; i < 3; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await t.pump(const Duration(milliseconds: 300));
        }
        await t.drag(find.byType(Slider), const Offset(0, 120), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 300));
      },
    );
    // etichetta di una zona spenta toccata
    await _scatta(
      t,
      const SchermataHome(),
      '08c-mappa-etichetta',
      prima: () async {
        await t.tap(find.byIcon(Icons.map_outlined));
        for (var i = 0; i < 3; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await t.pump(const Duration(milliseconds: 300));
        }
        final r = t.getRect(find.byType(MappaDisegno));
        await t.tapAt(r.topLeft + Offset(r.width * .3, r.height * .3), kind: PointerDeviceKind.touch);
        await t.pump(const Duration(milliseconds: 400));
      },
    );
    await _scatta(
      t,
      const SchermataHome(),
      '09-notifiche',
      prima: () async {
        await t.tap(find.text('Notifiche').last);
        for (var i = 0; i < 3; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await t.pump(const Duration(milliseconds: 300));
        }
      },
    );
    await _scatta(
      t,
      const SchermataHome(),
      '13-sondaggio',
      prima: () async {
        // in cima alla Home ora ci sono la carta «Cosa succede…» e la fila «Da fare»: si scorre fino al sondaggio
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await t.pump(const Duration(milliseconds: 300));
        await t.scrollUntilVisible(
          find.text('Sabato pomeriggio'),
          300,
          scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first,
        );
        await t.drag(find.text('Sabato pomeriggio'), const Offset(0, -120));
        await t.pump(const Duration(milliseconds: 500));
      },
    );
    await _scatta(
      t,
      const SchermataScrivi(),
      '11-scrivi-attivita',
      prima: () async {
        await t.tap(find.text('Attività'));
        await t.pump(const Duration(milliseconds: 400));
      },
    );
    await _scatta(
      t,
      const SchermataScrivi(),
      '12-scrivi-sondaggio',
      prima: () async {
        await t.tap(find.text('Sondaggio'));
        await t.pump(const Duration(milliseconds: 400));
      },
    );
    await _scatta(
      t,
      const SchermataHome(),
      '10-profilo',
      prima: () async {
        await t.tap(find.text('Profilo').last);
        for (var i = 0; i < 3; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await t.pump(const Duration(milliseconds: 300));
        }
      },
    );

    // guida dei nuovi iscritti: benvenuto e carta «Primi passi»
    stato.entra(Io({...ioFinto, 'guida': guidaFinta()}));
    await _scatta(t, const SchermataPrimoAccesso(), '14-benvenuto');
    await _scatta(t, const SchermataFeed(), '15-primi-passi');
    stato.entra(Io({...ioFinto, 'guida': guidaFinta(completa: true)}));
    await _scatta(t, const SchermataFeed(), '16-primi-passi-fatti');
    // preferenze delle notifiche: come Impostazioni → Notifiche sul sito
    await _scatta(t, SchermataPreferenzeNotifiche(iniziali: preferenzeFinte), '22-preferenze-notifiche');
    stato.entra(Io(ioFinto));

    // profilo di un altro: tasto «Segui già» su una riga
    utenteFinto['utente'] = {...(utenteFinto['utente'] as Map), 'io': false, 'seguo': true, 'residente': false};
    await _scatta(t, const SchermataUtente(username: 'anna.rossi'), '17-profilo-segui-gia');

    // numeri del profilo cliccabili: elenco Follower / Seguiti
    await _scatta(t, const SchermataFollow(username: 'anna.rossi', nome: 'Anna Rossi'), '21-follower');

    // 1.0.10: pagina #tag con bollini, @triburba e hashtag nel testo
    await _scatta(t, const SchermataTag(tag: 'festadelquartiere'), '18-tag-bollini');
    // foglio del tam-tam con «RITIRA» sulle destinazioni già mie
    await _scatta(
      t,
      const SchermataTag(tag: 'festadelquartiere'),
      '19-tamtam-ritira',
      prima: () async {
        await t.tap(find.text('Tam-tam').first);
        for (var i = 0; i < 4; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await t.pump(const Duration(milliseconds: 300));
        }
      },
    );
    // compositore del super admin: «Ovunque»
    stato.entra(Io({...ioFinto, 'puo': {...(ioFinto['puo'] as Map), 'superadmin': true}}));
    await _scatta(
      t,
      const SchermataScrivi(),
      '20-scrivi-ovunque',
      prima: () async {
        await t.drag(find.text('FIN DOVE ARRIVA'), const Offset(0, -900));
        await t.pump(const Duration(milliseconds: 500));
        await t.tap(find.text('Ovunque'));
        await t.pump(const Duration(milliseconds: 400));
      },
    );
    stato.entra(Io(ioFinto));

    // barra delle 8 reazioni (tamburo di triburba «Mi piace» e 👌 «Ho capito» nuove)
    await _scatta(
      t,
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: BarraReazioni(attuale: 'capito', onScelta: (_) {})),
        ),
      ),
      '23-barra-reazioni',
    );

    // niente rimandi al sito: voto della candidatura, moderazione e account dentro l'app
    await _scatta(t, Scaffold(body: ListView(children: [PostCard(post: Post(postCandidatura))])), '24-candidatura-vota');
    await _scatta(t, SchermataModerazione(slug: 'borgo-fiorito', datiIniziali: moderazioneFinta), '25-moderazione-moderatori');
    await _scatta(
      t,
      SchermataModerazione(slug: 'borgo-fiorito', datiIniziali: moderazioneFinta),
      '26-moderazione-proposte',
      prima: () async {
        await t.tap(find.textContaining('Proposte'));
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    );
    await _scatta(
      t,
      SchermataModerazione(slug: 'borgo-fiorito', datiIniziali: moderazioneFinta),
      '27-moderazione-nascosti',
      prima: () async {
        await t.tap(find.textContaining('Nascosti'));
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    );
    await _scatta(t, const SchermataImpostazioni(), '28-impostazioni-account');

    // pannello admin dentro l'app e pagine legali
    final adm = {
      'gestione': adminGestioneFinta,
      'statistiche': adminStatisticheFinte,
      'iscritti': adminIscrittiFinti,
      'visite': adminVisiteFinte,
      'registro': adminRegistroFinto,
    };
    await _scatta(t, SchermataAdmin(iniziali: adm), '29-admin-gestione');
    await _scatta(t, SchermataAdmin(iniziali: adm, scheda: 1), '30-admin-statistiche');
    await _scatta(t, SchermataAdmin(iniziali: adm, scheda: 2), '31-admin-iscritti');
    await _scatta(t, SchermataAdmin(iniziali: adm, scheda: 3), '32-admin-visite');
    await _scatta(t, SchermataAdmin(iniziali: adm, scheda: 4), '33-admin-registro');
    await _scatta(t, SchermataLegale(pagina: 'cookie', iniziali: legaleFinta), '34-legale-cookie');

    // Home «come un social vero»: carta «Cosa succede a …?» e fila «Da fare» (residente con cose da fare)
    await _scatta(t, const SchermataFeed(), '35-home-da-fare');
    // chi si è appena iscritto (non può ancora scrivere): solo la fila
    await _scatta(
      t,
      Scaffold(appBar: AppBar(title: const Text('Per te')), body: ListView(children: [FilaDaFare(voci: daFareNuovo)])),
      '36-da-fare-nuovo-iscritto',
    );
    await _scatta(t, const SchermataQuartiere(slug: 'borgo-fiorito'), '37-quartiere-pallini');
    await _scatta(t, const SchermataNuoviVicini(), '38-nuovi-vicini');
    // profilo mio senza foto né bio: barra «Profilo completo al …%»
    final utentePrima = utenteFinto['utente'];
    utenteFinto['utente'] = {...(utentePrima as Map), 'foto': null, 'bio': null, 'lavoro': null, 'copertina': null, 'io': true};
    await _scatta(t, const SchermataUtente(username: 'anna.rossi', mio: true), '39-profilo-da-completare');
    utenteFinto['utente'] = utentePrima;
    // tocco su una notifica: si apre il post
    await _scatta(
      t,
      const SchermataNotifiche(),
      '40-notifica-tocco',
      prima: () async {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.textContaining('Io porto il caffè', findRichText: true).first);
        for (var i = 0; i < 10; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
          await t.pump(const Duration(milliseconds: 100));
        }
      },
    );

    // email non ancora confermata: fascia in cima alla Home, e «Ti abbiamo scritto» dopo l'iscrizione
    stato.entra(Io({...ioFinto, 'utente': <String, dynamic>{...(ioFinto['utente'] as Map<String, dynamic>), 'email_confermata': false}}));
    await _scatta(t, const SchermataFeed(), '41-fascia-email');
    stato.entra(Io(ioFinto));
    await _scatta(t, const SchermataAccesso(), '43-accesso-password-dimenticata');

    // persone bloccate (requisito Play per i social)
    await _scatta(
      t,
      SchermataBloccati(iniziali: [
        {'username': 'gino.p', 'nome': 'Gino Palumbo', 'avatar': null},
        {'username': 'offerte.top', 'nome': 'Offerte Top', 'avatar': null},
      ]),
      '44-persone-bloccate',
    );
  });
}
