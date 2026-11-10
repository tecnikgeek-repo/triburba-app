// Dati finti del pannello admin e delle pagine legali, solo per le anteprime (nessun dato vero).

Map<String, int> _serie(List<int> v) {
  final inizio = DateTime(2026, 10, 12);
  return {
    for (var i = 0; i < v.length; i++)
      '${inizio.add(Duration(days: i)).year}-${inizio.add(Duration(days: i)).month.toString().padLeft(2, '0')}-${inizio.add(Duration(days: i)).day.toString().padLeft(2, '0')}':
          v[i],
  };
}

const _giorni = [0, 1, 0, 2, 1, 0, 3, 2, 1, 4, 2, 0, 1, 5, 3, 2, 6, 4, 3, 2, 7, 5, 4, 8, 6, 3, 9, 7, 5, 11];

final adminGestioneFinta = <String, dynamic>{
  'ok': true,
  'io': {'superadmin': true, 'id': 1},
  'stats': {'users': 128, 'posts': 342, 'comments': 911, 'likes': 1840, 'week': 57, 'attesa': 4, 'nascosti': 1},
  'immagini': <dynamic>[],
  'attesa': [
    {'id': 31, 'username': 'lucia.b', 'display_name': 'Lucia Bianchi', 'avatar_path': null, 'quartiere_nome': 'Borgo Fiorito', 'garanzie': 1},
  ],
  'nascosti': <dynamic>[],
  'telefoni': {'tot': 40, 'push': 31, 'android': 22, 'ios': 9, 'webapp': 6},
  'push_attive': true,
  'push_errori': <dynamic>[],
  'quartieri': [
    {'id': 1, 'nome': 'Borgo Fiorito', 'attivo': 1, 'mun_nome': 'I Municipalità', 'iscritti': 40},
    {'id': 2, 'nome': 'Colle Verde', 'attivo': 0, 'mun_nome': 'I Municipalità', 'iscritti': 0},
    {'id': 3, 'nome': 'Porto Vecchio', 'attivo': 1, 'mun_nome': 'II Municipalità', 'iscritti': 18},
  ],
  'comuni': [
    {'id': 101, 'nome': 'Comune Uno', 'attiva': 1, 'iscritti': 12},
    {'id': 102, 'nome': 'Comune Due', 'attiva': 0, 'iscritti': 0},
  ],
  'soglie': [
    {'chiave': 'garanzie_min', 'titolo': 'Garanzie per diventare residente', 'spiega': 'Quanti vicini confermati devono garantire per un nuovo residente.', 'valore': 3},
    {'chiave': 'soglia_apertura', 'titolo': 'Richieste per aprire un comune', 'spiega': 'Quando un comune spento raggiunge queste richieste si accende da solo.', 'valore': 3},
  ],
  'lancio': {'fino': '2026-12-08', 'dopo': 10},
  'pubblicazione': [
    {
      'chiave': 'pub_chi',
      'titolo': 'Chi può pubblicare',
      'spiega': 'Chi può scrivere post nel proprio quartiere.',
      'valore': 'confermati',
      'scelte': [
        {'valore': 'confermati', 'titolo': 'Solo residenti confermati'},
        {'valore': 'attesa', 'titolo': 'Anche chi è in attesa di conferma'},
      ],
    },
    {'chiave': 'pub_max_post', 'titolo': 'Lunghezza massima di un post', 'spiega': 'In caratteri.', 'valore': '3000', 'scelte': null},
  ],
  'utenti': [
    {'id': 1, 'username': 'marco.e', 'email': 'marco@esempio.invalid', 'role': 'superadmin', 'is_banned': 0, 'created_at': '2026-10-28 18:00:00', 'q_nome': 'Borgo Fiorito'},
    {'id': 7, 'username': 'anna.rossi', 'email': 'anna@esempio.invalid', 'role': 'user', 'is_banned': 0, 'created_at': '2026-11-02 10:12:00', 'q_nome': 'Borgo Fiorito'},
    {'id': 9, 'username': 'offerte.top', 'email': 'spam@esempio.invalid', 'role': 'user', 'is_banned': 1, 'created_at': '2026-11-05 09:00:00', 'q_nome': null},
  ],
  'tot_utenti': 128,
  'pu': 1,
  'post': [
    {'id': 50, 'content': 'Sabato la **festa del quartiere** in piazza: portate i bambini!', 'created_at': '2026-11-09 18:20:00', 'username': 'marco.e', 'q_nome': 'Borgo Fiorito'},
  ],
  'tot_post': 342,
  'pp': 1,
  'post7': false,
  'per_pagina': 25,
};

final adminStatisticheFinte = <String, dynamic>{
  'ok': true,
  'stat': {
    'iscritti': 128,
    'iscritti_7': 19,
    'post': 342,
    'post_7': 57,
    'reazioni': 1840,
    'residenti': 96,
    'attesa': 4,
    'attivi_7': 71,
    'iscrizioni_giorni': _serie(_giorni),
    'post_giorni': _serie(_giorni.map((x) => x * 2).toList()),
    'reazioni_giorni': _serie(_giorni.map((x) => x * 5).toList()),
    'quartieri_vivi': [
      {'nome': 'Borgo Fiorito', 'n': 140},
      {'nome': 'Porto Vecchio', 'n': 61},
    ],
    'quartieri_residenti': [
      {'nome': 'Borgo Fiorito', 'n': 40},
      {'nome': 'Porto Vecchio', 'n': 18},
    ],
    'reazioni_tipi': [
      {'nome': 'tribu', 'n': 900},
      {'nome': 'cuore', 'n': 520},
      {'nome': 'capito', 'n': 210},
    ],
    'post_top': [
      {'id': 50, 'nome': 'Sabato la festa del quartiere in piazza', 'n': 88},
    ],
    'comuni_richiesti': [
      {'nome': 'Comune Due', 'n': 2},
    ],
    'soglia_apertura': 3,
  },
  'nomi_reazioni': {'tribu': 'Mi piace', 'capito': 'Ho capito', 'cuore': 'Adoro'},
};

final adminIscrittiFinti = <String, dynamic>{
  'ok': true,
  'giorni': 30,
  'rapporto': {
    'passo': 1,
    'totale_ora': 128,
    'nuovi_periodo': 61,
    'via_periodo': 3,
    'residenti': 96,
    'nuovi_giorni': _serie(_giorni),
    'via_giorni': _serie(List.generate(30, (i) => i % 11 == 0 ? 1 : 0)),
    'totale_giorni': _serie(List.generate(30, (i) => 60 + i * 2 + (i > 20 ? i : 0))),
    'quartieri': [
      {'nome': 'Borgo Fiorito', 'n': 40},
      {'nome': 'Porto Vecchio', 'n': 18},
    ],
  },
  'nuovi': [
    {
      'id': 7,
      'username': 'anna.rossi',
      'display_name': 'Anna Rossi',
      'avatar_path': null,
      'created_at': '2026-11-09 18:10:00',
      'residenza': 'confermata',
      'iscritto_da': 'app',
      'ultimo_accesso': '2026-11-10 09:40:00',
      'q_nome': 'Borgo Fiorito',
    },
  ],
  'tot_nuovi': 61,
  'cancellati': <dynamic>[],
  'tot_cancellati': 0,
  'per_pagina': 25,
};

final adminVisiteFinte = <String, dynamic>{
  'ok': true,
  'giorni': 30,
  'rapporto': {
    'unici': 520,
    'viste': 4100,
    'entrati_oggi': 23,
    'unici_giorni': _serie(_giorni.map((x) => x * 3).toList()),
    'viste_giorni': _serie(_giorni.map((x) => x * 20).toList()),
    'attivi_giorni': _serie(_giorni.map((x) => x * 2).toList()),
    'canali': [
      {'nome': 'web', 'n': '2900', 'u': '380'},
      {'nome': 'app', 'n': '1200', 'u': '140'},
    ],
    'dispositivi': [
      {'nome': 'telefono', 'n': '3100', 'u': '410'},
      {'nome': 'computer', 'n': '1000', 'u': '110'},
    ],
    'provenienze': [
      {'nome': 'diretto', 'n': '900', 'u': '260'},
      {'nome': 'facebook', 'n': '400', 'u': '120'},
    ],
    'pagine': [
      {'nome': 'feed', 'n': '2100', 'u': '300'},
      {'nome': 'quartiere', 'n': '900', 'u': '210'},
    ],
  },
  'accessi': [
    {'id': 7, 'username': 'anna.rossi', 'display_name': 'Anna Rossi', 'avatar_path': null, 'created_at': '2026-11-02 10:12:00', 'ultimo_accesso': '2026-11-10 09:40:00', 'residenza': 'confermata', 'q_nome': 'Borgo Fiorito', 'giorni_30': 9},
  ],
  'tot_accessi': 128,
  'per_pagina': 25,
  'nomi_pagine': {'feed': 'Home e feed', 'quartiere': 'Pagine dei quartieri'},
  'nomi_provenienze': {'diretto': 'Diretto o app di messaggi', 'facebook': 'Facebook'},
  'nomi_canali': {'web': 'Sito web', 'app': 'App'},
  'nomi_dispositivi': {'telefono': 'Telefono', 'computer': 'Computer'},
};

final adminRegistroFinto = <String, dynamic>{
  'ok': true,
  'azione': '',
  'tipi': [
    {'chiave': 'accesso', 'titolo': 'Accesso', 'n': 230},
    {'chiave': 'post_creato', 'titolo': 'Post pubblicato', 'n': 342},
  ],
  'righe': [
    {'id': 3, 'user_id': 7, 'azione': 'post_creato', 'titolo': 'Post pubblicato', 'dettaglio': 'post #50', 'created_at': '2026-11-10 09:41:00', 'username': 'anna.rossi'},
    {'id': 2, 'user_id': 7, 'azione': 'accesso', 'titolo': 'Accesso', 'dettaglio': '', 'created_at': '2026-11-10 09:40:00', 'username': 'anna.rossi'},
  ],
  'tot': 2,
  'per_pagina': 25,
};

final legaleFinta = <String, dynamic>{
  'ok': true,
  'titolo': 'Cookie',
  'aggiornato': '10 novembre 2026',
  'html': '<h2>Nell\'app</h2><p>L\'app di triburba <b>non usa cookie</b>. Sul telefono tiene solo quello che serve a farla funzionare.</p>'
      '<h2>Se usi triburba dal browser</h2><p>Leggi anche la <a href="/privacy">privacy</a>.</p>'
      '<table><thead><tr><th>Nome</th><th>Tipo</th><th>Durata</th></tr></thead><tbody>'
      '<tr><td data-label="Nome"><code>tk_consenso</code></td><td data-label="Tipo">Cookie tecnico · Necessari</td><td data-label="Durata">12 mesi</td></tr>'
      '</tbody></table><ul><li>Niente pubblicità</li><li>Niente statistiche di terzi</li></ul>',
};
