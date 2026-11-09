// Foto delle schermate (caratteri veri, sito finto) in build/anteprime/, per guardarle senza telefono.
import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:triburba/schermate/accesso.dart';
import 'package:triburba/schermate/feed.dart';
import 'package:triburba/schermate/home.dart';
import 'package:triburba/schermate/naviga.dart';
import 'package:triburba/schermate/post.dart';
import 'package:triburba/schermate/primo_accesso.dart';
import 'package:triburba/schermate/quartiere.dart';
import 'package:triburba/schermate/scrivi.dart';
import 'package:triburba/schermate/utente.dart';
import 'package:triburba/tema.dart';

import 'caratteri.dart';
import 'finto.dart';

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
        await t.tap(find.text('Tribù'));
        for (var i = 0; i < 3; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
          await t.pump(const Duration(milliseconds: 300));
        }
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
        await t.ensureVisible(find.text('Sabato pomeriggio'));
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
    stato.entra(Io(ioFinto));

    // profilo di un altro: tasto «Segui già» su una riga
    utenteFinto['utente'] = {...(utenteFinto['utente'] as Map), 'io': false, 'seguo': true, 'residente': false};
    await _scatta(t, const SchermataUtente(username: 'anna.rossi'), '17-profilo-segui-gia');
  });
}
