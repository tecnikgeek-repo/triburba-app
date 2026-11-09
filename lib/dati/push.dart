// Notifiche push istantanee con Firebase Cloud Messaging.
// Se l'app è compilata senza google-services.json (chi compila dal sorgente), Firebase non parte e l'app
// funziona lo stesso: le notifiche restano visibili nella scheda Notifiche.
import 'dart:async';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'stato.dart';

final _locali = FlutterLocalNotificationsPlugin();
StreamSubscription<String>? _registrazione;
bool _pronto = false;

const _canale = AndroidNotificationChannel(
  'triburba',
  'Attività su triburba',
  description: 'Commenti, reazioni, menzioni, garanzie dei vicini e tam-tam',
  importance: Importance.high,
);

/// In sottofondo il sistema mostra già la notifica: qui non serve fare nulla.
@pragma('vm:entry-point')
Future<void> _inSottofondo(RemoteMessage m) async {}

/// iPhone: la configurazione arriva da --dart-define nella compilazione (segreti del repo), non da un file.
const _iosApiKey = String.fromEnvironment('FB_IOS_API_KEY');
const _iosAppId = String.fromEnvironment('FB_IOS_APP_ID');
const _fbSender = String.fromEnvironment('FB_SENDER_ID');
const _fbProgetto = String.fromEnvironment('FB_PROJECT_ID');

Future<void> preparaPush() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_iosApiKey.isEmpty) return; // compilato senza configurazione: niente push
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _iosApiKey,
          appId: _iosAppId,
          messagingSenderId: _fbSender,
          projectId: _fbProgetto,
          iosBundleId: 'it.triburba.app',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (_) {
    return; // niente google-services.json: niente push
  }
  _pronto = true;
  FirebaseMessaging.onBackgroundMessage(_inSottofondo);

  await _locali.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_notifica'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ),
    onDidReceiveNotificationResponse: (r) {
      final link = r.payload;
      if (link != null) _apriLink(link);
    },
  );
  await _locali.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_canale);

  // app aperta: la notifica la mostro io (Android non la mostra da solo) e aggiorno il contatore
  FirebaseMessaging.onMessage.listen((m) {
    final n = int.tryParse(m.data['nuove'] ?? '');
    if (n != null) stato.impostaNotifiche(n);
    final t = m.notification;
    if (t == null) return;
    _locali.show(
      id: m.hashCode & 0x7fffffff,
      title: t.title,
      body: t.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _canale.id,
          _canale.name,
          channelDescription: _canale.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notifica',
          color: const Color(0xFFE0663A),
          styleInformation: BigTextStyleInformation(t.body ?? ''),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: m.data['link'],
    );
  });
  // tocco su una notifica arrivata con l'app in sottofondo o chiusa
  FirebaseMessaging.onMessageOpenedApp.listen((m) => _apriLink(m.data['link'] ?? ''));
  final iniziale = await FirebaseMessaging.instance.getInitialMessage();
  if (iniziale != null) _apriLink(iniziale.data['link'] ?? '');
}

void _apriLink(String link) {
  final d = destinazioneDaLink(link);
  stato.apri(d ?? {'tipo': 'notifiche'});
}

/// Dopo l'accesso: chiede il permesso (Android 13+, iPhone) e manda al sito l'indirizzo di questo telefono.
Future<void> collegaPush() async {
  if (!_pronto) return;
  try {
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission();
    // l'indirizzo arriva (e cambia) da onRegistered: lo mando al sito ogni volta
    _registrazione ??= fm.onRegistered.listen((t) => stato.api.registraPush(t).catchError((_) {}));
    await fm.register();
  } catch (e) {
    debugPrint('push non collegate: $e');
  }
}

/// All'uscita l'indirizzo push si cancella dal telefono (il sito l'ha già tolto col token).
Future<void> scollegaPush() async {
  if (!_pronto) return;
  try {
    await FirebaseMessaging.instance.unregister();
  } catch (_) {}
}
