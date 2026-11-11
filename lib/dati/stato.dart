// Stato condiviso dell'app: chi è collegato, quante notifiche nuove, e la richiesta di aprire una schermata
// (da una notifica push o da un link triburba.it).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;

import 'api.dart';
import 'modelli.dart';

class Stato extends ChangeNotifier {
  Stato(this.api) {
    api.accessoScaduto = () {
      io = null;
      notifyListeners();
    };
  }

  final Api api;
  Io? io;
  int notifiche = 0;

  /// Destinazione da aprire appena c'è la home: {tipo: post|utente|quartiere, …}
  Map<String, dynamic>? daAprire;

  // col token si entra anche senza rete: i dati della persona arrivano appena il sito risponde
  bool get collegato => api.token != null;

  void entra(Io nuovo) {
    io = nuovo;
    notifiche = nuovo.notifiche;
    _icona(notifiche);
    notifyListeners();
  }

  Future<void> ricarica() async {
    try {
      entra(await api.io());
    } catch (_) {}
  }

  void impostaNotifiche(int n) {
    _icona(n);
    if (n == notifiche) return;
    notifiche = n;
    notifyListeners();
  }

  void apri(Map<String, dynamic> vai) {
    daAprire = vai;
    notifyListeners();
  }

  Future<void> esci() async {
    await api.esci();
    io = null;
    notifiche = 0;
    _icona(0);
    notifyListeners();
  }

  /// iPhone: il numero rosso sull'icona lo scrive il push e resterebbe fermo; qui segue le notifiche non lette.
  static const _badge = MethodChannel('triburba/badge');
  void _icona(int n) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _badge.invokeMethod('imposta', n).catchError((_) {});
  }
}

late Stato stato;

/// Link del sito → destinazione nell'app («/u/mario#p12», «/q/vomero», «https://triburba.it/u/mario»).
Map<String, dynamic>? destinazioneDaLink(String link) {
  var l = link;
  if (l.startsWith(sito)) l = l.substring(sito.length);
  final pp = RegExp(r'^/p/(\d+)').firstMatch(l);
  if (pp != null) return {'tipo': 'post', 'id': int.parse(pp.group(1)!)};
  final tg = RegExp(r'^/tag/([^/?#]+)').firstMatch(l);
  if (tg != null) return {'tipo': 'tag', 'tag': Uri.decodeComponent(tg.group(1)!)};
  final p = RegExp(r'^/u/([^#/?]+)#p(\d+)').firstMatch(l);
  if (p != null) return {'tipo': 'post', 'id': int.parse(p.group(2)!), 'username': Uri.decodeComponent(p.group(1)!)};
  final u = RegExp(r'^/u/([^#/?]+)').firstMatch(l);
  if (u != null) return {'tipo': 'utente', 'username': Uri.decodeComponent(u.group(1)!)};
  final q = RegExp(r'^/q/([a-z0-9-]+)(?:\?t=(\w+))?').firstMatch(l);
  if (q != null) return {'tipo': 'quartiere', 'slug': q.group(1)!, 'scheda': q.group(2) ?? 'bacheca'};
  final st = RegExp(r'^/settings(?:\?campo=(\w+))?').firstMatch(l);
  if (st != null) return {'tipo': 'modifica_profilo', 'campo': st.group(1) ?? ''};
  if (l.startsWith('/admin')) return {'tipo': 'admin'};
  if (l.startsWith('/notifiche')) return {'tipo': 'notifiche'};
  if (l == '/quartieri' || l.startsWith('/mappa')) return {'tipo': 'mappa'};
  if (l.startsWith('/#compose')) return {'tipo': 'scrivi'};
  return null;
}
