// Sito finto per le prove: risponde come triburba.it con dati di esempio neutri.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> faccia(String u, String nome, {List<String> colori = const ['#e0663a', '#f0b34a'], bool stemma = false}) => {
  'username': u,
  'nome': nome,
  'foto': null,
  'iniziali': nome.split(' ').map((w) => w[0]).take(2).join(),
  'colori': colori,
  'bot': false,
  'stemma': stemma ? {'url': '/stemma/23.svg?v=1&m=1', 'nome': 'Borgo Fiorito', 'attesa': false} : null,
};

final _q = {'nome': 'Borgo Fiorito', 'slug': 'borgo-fiorito', 'colore': '#a5d42d'};

Map<String, dynamic> post(
  int id,
  String testo, {
  Map<String, dynamic>? autore,
  int reazioni = 0,
  String? mia,
  List<String> top = const [],
  String chi = '',
  int commenti = 0,
  List<Map<String, dynamic>> portate = const [],
  int rilanci = 0,
  bool citta = false,
  List<Map<String, dynamic>> anteprima = const [],
  Map<String, dynamic>? link,
}) => {
  'id': id,
  'tipo': 'post',
  'testo': testo,
  'creato': '2026-11-09T10:00:00+01:00',
  'quando': '$id h',
  'autore': autore ?? faccia('anna.rossi', 'Anna Rossi'),
  'quartiere': _q,
  'da_comune': false,
  'immagine': null,
  'sfocata': false,
  'reazioni': {'n': reazioni, 'mia': mia, 'top': top, 'chi': chi},
  'commenti': commenti,
  'anteprima': anteprima,
  'portate': portate,
  'citta': citta,
  'area': false,
  'rilanci': rilanci,
  'mio_rilancio': false,
  'soglia': 3,
  'link': link,
  'candidatura': null,
  'nascosto': null,
  'segnalato': false,
  'puo': {'modifica': false, 'elimina': false, 'segnala': true, 'tamtam': true},
  'url': '/u/anna.rossi#p$id',
};

final feedFinto = [
  {
    ...post(
      4,
      'Sabato mattina ripuliamo insieme le aiuole della piazza: servono braccia, guanti e un po\' di buona volontà!',
      autore: faccia('marco.e', 'Marco Esposito', colori: ['#1aa39a', '#2b6cb0']),
      reazioni: 8,
      top: ['applauso', 'cuore'],
      chi: 'Anna Rossi e altre 7 persone',
      commenti: 3,
    ),
    'tipo': 'attivita',
    'attivita': {
      'quando': '2026-11-15T10:00:00+01:00',
      'quando_testo': 'sab 15 nov, 10:00',
      'luogo': 'Piazza Grande',
      'minimo': 6,
      'scadenza': '2026-11-14T10:00:00+01:00',
      'scadenza_testo': 'ven 14 nov, 10:00',
      'stato': 'raccolta',
      'passata': false,
      'n': 4,
      'ci_sono': false,
      'aperta': true,
      'facce': [
        faccia('anna.rossi', 'Anna Rossi'),
        faccia('giulia.f', 'Giulia Ferrara', colori: ['#7b4bd6', '#e0663a']),
        faccia('luca.m', 'Luca Marino', colori: ['#138a82', '#f0b34a']),
        faccia('sara.c', 'Sara Conte', colori: ['#ef4b3f', '#e0663a']),
      ],
    },
  },
  {
    ...post(
      5,
      'Festa di quartiere: che giorno preferite?',
      autore: faccia('giulia.f', 'Giulia Ferrara', colori: ['#7b4bd6', '#e0663a']),
      reazioni: 5,
      top: ['cuore'],
      chi: 'Luca Marino e altre 4 persone',
      commenti: 1,
    ),
    'tipo': 'sondaggio',
    'sondaggio': {
      'opzioni': [
        {'id': 1, 'testo': 'Sabato pomeriggio', 'voti': 12, 'mia': true},
        {'id': 2, 'testo': 'Domenica mattina', 'voti': 7, 'mia': false},
        {'id': 3, 'testo': 'Venerdì sera', 'voti': 3, 'mia': false},
      ],
      'votanti': 22,
      'multi': false,
      'solo_residenti': true,
      'chiude': '2026-11-12T18:00:00+01:00',
      'chiude_testo': 'Si chiude gio 12 nov, 18:00',
      'chiuso': false,
      'votato': true,
      'risultati': true,
      'puo': true,
      'motivo': null,
    },
  },
  post(
    1,
    'Domenica mattina **pulizia del parco** di via dei Tigli: portate guanti e sacchi, il comune ci dà i bidoni. {oro}Ci vediamo alle 9!{/} @tribu',
    reazioni: 14,
    mia: 'cuore',
    top: ['cuore', 'applauso', 'wow'],
    chi: 'Tu e altre 13 persone',
    commenti: 6,
    rilanci: 2,
    portate: [
      {'livello': 'municipalita', 'nome': 'VII Municipalità', 'slug': null, 'colore': '#1aa39a', 'attesa': false},
    ],
    anteprima: [
      {
        'id': 10,
        'testo': 'Io porto il caffè per tutti ☕',
        'quando': '2 h',
        'autore': faccia('marco.e', 'Marco Esposito', colori: ['#1aa39a', '#2b6cb0']),
        'likes': 3,
        'mia': null,
        'top': ['cuore'],
      },
    ],
  ),
  post(
    2,
    'Qualcuno sa se la farmacia di piazza Grande fa il turno di notte questa settimana?',
    autore: faccia('giulia.f', 'Giulia Ferrara', colori: ['#7b4bd6', '#e0663a']),
    reazioni: 3,
    top: ['wow'],
    chi: 'Marco Esposito e altre 2 persone',
    commenti: 2,
  ),
  post(
    3,
    'Riaperta la biblioteca di quartiere! Orari nuovi e una sala studio tutta rinnovata.',
    autore: faccia('luca.m', 'Luca Marino', colori: ['#138a82', '#f0b34a']),
    reazioni: 41,
    top: ['applauso', 'cuore', 'ridere'],
    chi: 'Anna Rossi e altre 40 persone',
    commenti: 12,
    citta: true,
    link: {
      'url': 'https://example.org/biblioteca',
      'titolo': 'La biblioteca di quartiere riapre con la sala studio',
      'descrizione': 'Nuovi orari dal lunedì al sabato, prestito libri e corsi gratuiti.',
      'immagine': null,
      'sito': 'example.org',
    },
  ),
];

final ioFinto = {
  'utente': {
    ...faccia('anna.rossi', 'Anna Rossi'),
    'id': 1,
    'email': 'anna@example.org',
    'bio': 'Maestra, amo il mio quartiere e i suoi giardini.',
    'lavoro': 'Insegnante',
    'luogo': null,
    'sito': null,
    'copertina': null,
    'ruolo': 'user',
    'dal': 'novembre 2026',
  },
  'casa': {
    'id': 23,
    'nome': 'Borgo Fiorito',
    'slug': 'borgo-fiorito',
    'colore': '#a5d42d',
    'municipalita': 'VII Municipalità',
    'citta': 'Napoli',
    'stemma': '/stemma/23.svg?v=1&m=1',
  },
  'residenza': 'confermata',
  'giorni_cambio': 0,
  'puo': {'pubblicare': true, 'commentare': true, 'residente': true, 'admin': false, 'foto': true},
  'limiti': {'post': 3000, 'commento': 500},
  'conti': {'followers': 12, 'following': 30, 'post': 8},
  'notifiche': 3,
  'schede': [
    {'id': 'perte', 'nome': 'Per te'},
    {'id': 'quartiere', 'nome': 'Quartiere'},
    {'id': 'municipalita', 'nome': 'Municipalità'},
    {'id': 'citta', 'nome': 'Napoli'},
    {'id': 'seguiti', 'nome': 'Persone'},
  ],
  'tamtam': {
    'titolo': 'alle altre tribù o a tutta Napoli',
    'grande': 'A tutta Napoli',
    'nota': 'Arriva quando lo rilanciano residenti di 3 quartieri diversi: il tuo voto conta come uno',
    'vicino': 'Nella tua municipalità arriva subito; negli altri quartieri',
  },
  'reazioni': {
    'cuore': 'Mi piace',
    'ridere': 'Che ridere',
    'wow': 'Wow',
    'triste': 'Che tristezza',
    'rabbia': 'Che rabbia',
    'applauso': 'Bravi!',
  },
  'motivi': ['Spam o pubblicità', 'Offese, odio o minacce'],
  'colori': {},
  'push': false,
};

// due forme di esempio (unità di mappa)
const _f1 = 'M10 10 L60 5 L80 40 L50 70 L15 55 Z';
const _f2 = 'M60 5 L120 15 L125 60 L80 40 Z';

final mappaFinta = {
  'ok': true,
  'gruppi': [
    {
      'id': 7,
      'numero': '7',
      'nome': 'VII Municipalità',
      'quartieri': [
        {
          'id': 23,
          'nome': 'Borgo Fiorito',
          'slug': 'borgo-fiorito',
          'colore': '#a5d42d',
          'residenti': 48,
          'post': 120,
          'citta': 'Napoli',
          'stemma': null,
          'copertina': null,
          'forma': _f1,
          'box': [10, 5, 80, 70],
          'centro': [45, 38],
        },
        {
          'id': 24,
          'nome': 'Colle Alto',
          'slug': 'colle-alto',
          'colore': '#e0663a',
          'residenti': 21,
          'post': 37,
          'citta': 'Napoli',
          'stemma': null,
          'copertina': null,
          'forma': _f2,
          'box': [60, 5, 125, 60],
          'centro': [95, 30],
        },
      ],
    },
  ],
  'seguiti': [24],
  'casa': 23,
  'giorni_cambio': 0,
  'spenti': [
    {'id': 101, 'nome': 'Comune Uno', 'richieste': 7, 'mia': false},
    {'id': 102, 'nome': 'Comune Due', 'richieste': 2, 'mia': true},
  ],
  'soglia_apertura': 10,
  'crediti': 'Confini: © OpenStreetMap (ODbL) · ISTAT / openpolis (CC BY)',
};

final notificheFinte = {
  'ok': true,
  'nuove': 2,
  'notifiche': [
    {
      'id': 1,
      'tipo': 'commento',
      'icona': 'comment',
      'frase': 'ha commentato il tuo post',
      'chi': faccia('marco.e', 'Marco Esposito', colori: ['#1aa39a', '#2b6cb0']),
      'testo': 'Io porto il caffè per tutti',
      'quando': '2 h',
      'letta': false,
      'vai': {'tipo': 'post', 'id': 1},
    },
    {
      'id': 2,
      'tipo': 'garanzia',
      'icona': 'handshake',
      'frase': 'ha garantito per te',
      'chi': faccia('luca.m', 'Luca Marino', colori: ['#138a82', '#f0b34a']),
      'testo': 'Borgo Fiorito',
      'quando': 'ieri',
      'letta': false,
      'vai': {'tipo': 'quartiere', 'slug': 'borgo-fiorito'},
    },
    {
      'id': 3,
      'tipo': 'residente',
      'icona': 'check',
      'frase': 'Sei residente confermato',
      'chi': null,
      'testo': 'Ora puoi pubblicare a Borgo Fiorito',
      'quando': 'ieri',
      'letta': true,
      'vai': {'tipo': 'quartiere', 'slug': 'borgo-fiorito'},
    },
    {
      'id': 4,
      'tipo': 'reazione',
      'icona': 'heart',
      'frase': 'ha reagito al tuo post',
      'chi': faccia('giulia.f', 'Giulia Ferrara', colori: ['#7b4bd6', '#e0663a']),
      'testo': 'Domenica mattina pulizia del parco…',
      'quando': '3 g',
      'letta': true,
      'vai': {'tipo': 'post', 'id': 1},
    },
  ],
};

final commentiFinti = {
  'ok': true,
  'puo_commentare': true,
  'comments': [
    {
      'id': 10,
      'parent_id': null,
      'content': 'Io porto il caffè per tutti ☕',
      'created_at': '2026-11-09 08:00:00',
      'username': 'marco.e',
      'nome': 'Marco Esposito',
      'avatar': null,
      'likes': 3,
      'mia': null,
      'top': ['cuore'],
      'autore': false,
      'mio': false,
      'elimina': false,
      'bot': false,
      'stemma': null,
    },
    {
      'id': 11,
      'parent_id': 10,
      'content': 'Grande Marco! **Grazie**',
      'created_at': '2026-11-09 08:20:00',
      'username': 'anna.rossi',
      'nome': 'Anna Rossi',
      'avatar': null,
      'likes': 1,
      'mia': 'cuore',
      'top': ['cuore'],
      'autore': true,
      'mio': true,
      'elimina': true,
      'bot': false,
      'stemma': null,
    },
    {
      'id': 12,
      'parent_id': null,
      'content': 'Ci sarò con i bambini, portiamo anche i rastrelli.',
      'created_at': '2026-11-09 09:00:00',
      'username': 'giulia.f',
      'nome': 'Giulia Ferrara',
      'avatar': null,
      'likes': 0,
      'mia': null,
      'top': [],
      'autore': false,
      'mio': false,
      'elimina': false,
      'bot': false,
      'stemma': null,
    },
  ],
};

final quartiereFinto = {
  'ok': true,
  'altri': false,
  'post': feedFinto.take(2).toList(),
  'quartiere': {
    'id': 23,
    'nome': 'Borgo Fiorito',
    'slug': 'borgo-fiorito',
    'colore': '#a5d42d',
    'municipalita': 'VII Municipalità',
    'citta': 'Napoli',
    'copertina': null,
    'stemma': null,
    'regole': 'Rispetto per tutti. Niente pubblicità. Le segnalazioni le guardano i moderatori eletti.',
    'stats': {'residenti': 48, 'attesa': 3, 'post': 120, 'seguaci': 15},
    'moderatori': [
      faccia('luca.m', 'Luca Marino', colori: ['#138a82', '#f0b34a']),
    ],
    'facce': [
      faccia('anna.rossi', 'Anna Rossi'),
      faccia('marco.e', 'Marco Esposito', colori: ['#1aa39a', '#2b6cb0']),
      faccia('giulia.f', 'Giulia Ferrara', colori: ['#7b4bd6', '#e0663a']),
    ],
    'casa': true,
    'residente': true,
    'segui': false,
    'giorni_cambio': 0,
    'garanzie_min': 2,
    'attivita_min': 3,
    'puo_moderare': false,
  },
};

final utenteFinto = {
  'ok': true,
  'altri': false,
  'post': feedFinto.take(1).toList(),
  'utente': {
    ...faccia('anna.rossi', 'Anna Rossi'),
    'bio': 'Maestra, amo il mio quartiere e i suoi giardini.',
    'lavoro': 'Insegnante',
    'luogo': null,
    'sito': null,
    'copertina': null,
    'dal': 'novembre 2026',
    'casa': _q,
    'residente': true,
    'conti': {'followers': 12, 'following': 30, 'post': 8},
    'attivita': {'reazioni': 120, 'commenti': 40, 'portati': 5, 'rilanci': 9},
    'io': true,
    'seguo': false,
  },
};

http.Client clientFinto() => MockClient((r) async {
  final p = r.url.path;
  Object j = {'ok': false, 'error': 'non previsto: $p'};
  if (p == '/app/v1/io') j = {'ok': true, 'io': ioFinto};
  if (p == '/app/v1/feed') j = {'ok': true, 'scheda': 'perte', 'post': feedFinto, 'altri': false, 'notifiche': 3};
  if (p.startsWith('/app/v1/post/')) j = {'ok': true, 'post': feedFinto.first};
  if (p == '/api/comment/list') j = commentiFinti;
  if (p == '/app/v1/mappa') j = mappaFinta;
  if (p == '/app/v1/notifiche') j = notificheFinte;
  if (p.startsWith('/app/v1/quartiere/')) j = quartiereFinto;
  if (p.startsWith('/app/v1/utente/')) j = utenteFinto;
  return http.Response.bytes(utf8.encode(jsonEncode(j)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
});
