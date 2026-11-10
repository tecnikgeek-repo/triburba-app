// Ogni link usato dalle notifiche e dalla fila «Da fare» deve portare alla schermata giusta dell'app.
import 'package:flutter_test/flutter_test.dart';
import 'package:triburba/dati/api.dart';
import 'package:triburba/dati/stato.dart';

void main() {
  final casi = <String, Map<String, dynamic>>{
    '/p/245': {'tipo': 'post', 'id': 245},
    '$sito/p/12': {'tipo': 'post', 'id': 12},
    '/u/mario.rossi#p7': {'tipo': 'post', 'id': 7, 'username': 'mario.rossi'},
    '/u/mario.rossi': {'tipo': 'utente', 'username': 'mario.rossi'},
    '/q/san-pietro-a-patierno': {'tipo': 'quartiere', 'slug': 'san-pietro-a-patierno', 'scheda': 'bacheca'},
    '/q/vomero?t=residenti': {'tipo': 'quartiere', 'slug': 'vomero', 'scheda': 'residenti'},
    '/q/vomero?t=moderatori': {'tipo': 'quartiere', 'slug': 'vomero', 'scheda': 'moderatori'},
    '/q/vomero?t=proposti': {'tipo': 'quartiere', 'slug': 'vomero', 'scheda': 'proposti'},
    '/q/vomero?t=segnalati': {'tipo': 'quartiere', 'slug': 'vomero', 'scheda': 'segnalati'},
    '/q/vomero?t=regole': {'tipo': 'quartiere', 'slug': 'vomero', 'scheda': 'regole'},
    '/tag/festadelquartiere': {'tipo': 'tag', 'tag': 'festadelquartiere'},
    '/settings?campo=avatar': {'tipo': 'modifica_profilo', 'campo': 'avatar'},
    '/settings': {'tipo': 'modifica_profilo', 'campo': ''},
    '/admin': {'tipo': 'admin'},
    '/admin#immagini': {'tipo': 'admin'},
    '/notifiche': {'tipo': 'notifiche'},
    '/quartieri': {'tipo': 'mappa'},
    '/#compose': {'tipo': 'scrivi'},
  };
  for (final c in casi.entries) {
    test('link ${c.key}', () => expect(destinazioneDaLink(c.key), c.value));
  }
  test('link sconosciuto: nessuna destinazione', () => expect(destinazioneDaLink('/strano'), isNull));
}
