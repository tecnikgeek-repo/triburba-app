// Notifiche push istantanee con Firebase Cloud Messaging.
// Se l'app è compilata senza google-services.json (chi compila dal sorgente), Firebase non parte e l'app
// funziona lo stesso: le notifiche restano visibili nella scheda Notifiche.
import 'dart:async';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'stato.dart';

final _locali = FlutterLocalNotificationsPlugin();
StreamSubscription<String>? _registrazione;
AppLifecycleListener? _ciclo;
DateTime? _ultimoInvio;
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

/// Dopo l'accesso (e a ogni avvio da collegato): chiede il permesso (Android 13+, iPhone) e manda al sito
/// il token FCM di questo telefono. ATTENZIONE: register()/onRegistered danno il Firebase Installation ID,
/// che l'API di invio NON accetta (risponde UNREGISTERED e il sito cancellava l'indirizzo): serve getToken().
Future<void> collegaPush() async {
  if (!_pronto) return;
  try {
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission();
    await _mandaToken(forza: true);
    // il token può cambiare: lo rimando ogni volta
    // ignore: deprecated_member_use
    _registrazione ??= fm.onTokenRefresh.listen((t) => _invia(t));
    // quando l'app torna in primo piano ricontrollo (al massimo ogni 6 ore), così il sito ha sempre l'indirizzo giusto
    _ciclo ??= AppLifecycleListener(onResume: () => _mandaToken());
  } catch (e) {
    debugPrint('push non collegate: $e');
  }
}

Future<void> _mandaToken({bool forza = false}) async {
  if (!_pronto || stato.api.token == null) return;
  if (!forza && _ultimoInvio != null && DateTime.now().difference(_ultimoInvio!) < const Duration(hours: 6)) return;
  try {
    final fm = FirebaseMessaging.instance;
    // iPhone: il token FCM esiste solo dopo quello di Apple (APNs), che arriva qualche istante dopo il permesso
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var i = 0; i < 10 && await fm.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    // ignore: deprecated_member_use
    final t = await fm.getToken();
    if (t != null && t.isNotEmpty) await _invia(t);
  } catch (e) {
    debugPrint('token push non disponibile: $e');
  }
}

Future<void> _invia(String t) async {
  try {
    await stato.api.registraPush(t);
    _ultimoInvio = DateTime.now();
  } catch (_) {}
}

/// All'uscita l'indirizzo push si cancella dal telefono (il sito l'ha già tolto col token).
Future<void> scollegaPush() async {
  if (!_pronto) return;
  _ultimoInvio = null;
  try {
    // ignore: deprecated_member_use
    await FirebaseMessaging.instance.deleteToken();
  } catch (_) {}
}
