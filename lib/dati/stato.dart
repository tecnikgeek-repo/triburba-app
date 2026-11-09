// Stato condiviso dell'app: chi è collegato, quante notifiche nuove, e la richiesta di aprire una schermata
// (da una notifica push o da un link triburba.it).
import 'package:flutter/foundation.dart';

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
    notifyListeners();
  }

  Future<void> ricarica() async {
    try {
      entra(await api.io());
    } catch (_) {}
  }

  void impostaNotifiche(int n) {
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
    notifyListeners();
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
  final q = RegExp(r'^/q/([a-z0-9-]+)').firstMatch(l);
  if (q != null) return {'tipo': 'quartiere', 'slug': q.group(1)!};
  return null;
}
