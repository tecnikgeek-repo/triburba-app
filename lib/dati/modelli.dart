// Dati che arrivano da triburba.it, con letture tipizzate sopra il JSON.

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String? _s(dynamic v) => v == null ? null : '$v';
List<String> _l(dynamic v) => v is List ? v.map((e) => '$e').toList() : const [];

/// Una persona come compare accanto a post e commenti.
class Faccia {
  Faccia(Map<String, dynamic> j)
    : username = _s(j['username']) ?? '',
      nome = _s(j['nome']) ?? _s(j['username']) ?? '',
      foto = _s(j['foto']),
      iniziali = _s(j['iniziali']) ?? '?',
      colori = _l(j['colori']),
      bot = j['bot'] == true,
      stemma = j['stemma'] is Map ? Stemma(j['stemma'] as Map<String, dynamic>) : null;

  final String username, nome, iniziali;
  final String? foto;
  final List<String> colori;
  final bool bot;
  final Stemma? stemma;
}

class Stemma {
  Stemma(Map<String, dynamic> j) : url = _s(j['url']) ?? '', nome = _s(j['nome']) ?? '', attesa = j['attesa'] == true;

  final String url, nome;
  final bool attesa;
}

class QuartiereBreve {
  QuartiereBreve(Map<String, dynamic> j) : nome = _s(j['nome']) ?? '', slug = _s(j['slug']), colore = _s(j['colore']) ?? '#e0663a';

  final String nome, colore;
  final String? slug;
}

class Reazioni {
  Reazioni(Map<String, dynamic> j) : n = _i(j['n']), mia = _s(j['mia']), top = _l(j['top']), chi = _s(j['chi']) ?? '';

  int n;
  String? mia;
  List<String> top;
  String chi;
}

class Portata {
  Portata(Map<String, dynamic> j)
    : livello = _s(j['livello']) ?? '',
      nome = _s(j['nome']) ?? '',
      slug = _s(j['slug']),
      colore = _s(j['colore']) ?? '#e0663a',
      attesa = j['attesa'] == true;

  final String livello, nome, colore;
  final String? slug;
  final bool attesa;
}

class AnteprimaLink {
  AnteprimaLink(Map<String, dynamic> j)
    : url = _s(j['url']) ?? '',
      titolo = _s(j['titolo']),
      descrizione = _s(j['descrizione']),
      immagine = _s(j['immagine']),
      sito = _s(j['sito']);

  final String url;
  final String? titolo, descrizione, immagine, sito;
}

class CommentoBreve {
  CommentoBreve(Map<String, dynamic> j)
    : id = _i(j['id']),
      testo = _s(j['testo']) ?? '',
      quando = _s(j['quando']) ?? '',
      autore = Faccia(j['autore'] as Map<String, dynamic>),
      likes = _i(j['likes']);

  final int id, likes;
  final String testo, quando;
  final Faccia autore;
}

class Post {
  Post(Map<String, dynamic> j)
    : id = _i(j['id']),
      tipo = _s(j['tipo']) ?? 'post',
      testo = _s(j['testo']) ?? '',
      quando = _s(j['quando']) ?? '',
      autore = Faccia(j['autore'] as Map<String, dynamic>),
      quartiere = j['quartiere'] is Map ? QuartiereBreve(j['quartiere'] as Map<String, dynamic>) : null,
      daComune = j['da_comune'] == true,
      immagine = _s(j['immagine']),
      sfocata = j['sfocata'] == true,
      reazioni = Reazioni(j['reazioni'] as Map<String, dynamic>),
      commenti = _i(j['commenti']),
      anteprima = (j['anteprima'] as List? ?? []).map((c) => CommentoBreve(c as Map<String, dynamic>)).toList(),
      portate = (j['portate'] as List? ?? []).map((p) => Portata(p as Map<String, dynamic>)).toList(),
      citta = j['citta'] == true,
      area = j['area'] == true,
      rilanci = _i(j['rilanci']),
      mioRilancio = j['mio_rilancio'] == true,
      soglia = _i(j['soglia']),
      link = j['link'] is Map ? AnteprimaLink(j['link'] as Map<String, dynamic>) : null,
      candidatura = j['candidatura'] is Map ? j['candidatura'] as Map<String, dynamic> : null,
      attivita = j['attivita'] is Map ? Attivita(j['attivita'] as Map<String, dynamic>) : null,
      sondaggio = j['sondaggio'] is Map ? Sondaggio(j['sondaggio'] as Map<String, dynamic>) : null,
      nascosto = _s(j['nascosto']),
      segnalato = j['segnalato'] == true,
      puoModificare = (j['puo'] as Map?)?['modifica'] == true,
      puoEliminare = (j['puo'] as Map?)?['elimina'] == true,
      puoSegnalare = (j['puo'] as Map?)?['segnala'] == true,
      puoTamtam = (j['puo'] as Map?)?['tamtam'] == true,
      url = _s(j['url']) ?? '/';

  final int id;
  final String tipo, quando, url;
  String testo;
  final Faccia autore;
  final QuartiereBreve? quartiere;
  final bool daComune, sfocata, citta, area, puoModificare, puoEliminare, puoTamtam;
  final String? immagine, nascosto;
  final Reazioni reazioni;
  int commenti;
  final List<CommentoBreve> anteprima;
  final List<Portata> portate;
  int rilanci, soglia;
  bool mioRilancio, segnalato, puoSegnalare;
  final AnteprimaLink? link;
  final Map<String, dynamic>? candidatura;

  /// Attività o sondaggio: cambiano dopo «Ci sarò» o un voto (si rilegge il post).
  Attivita? attivita;
  Sondaggio? sondaggio;
}

/// Un'attività: parte solo se entro la data limite confermano almeno [minimo] persone.
class Attivita {
  Attivita(Map<String, dynamic> j)
    : quando = _s(j['quando_testo']) ?? '',
      luogo = _s(j['luogo']),
      minimo = _i(j['minimo']),
      scadenza = _s(j['scadenza_testo']) ?? '',
      stato = _s(j['stato']) ?? 'raccolta',
      passata = j['passata'] == true,
      n = _i(j['n']),
      ciSono = j['ci_sono'] == true,
      aperta = j['aperta'] == true,
      facce = (j['facce'] as List? ?? []).map((f) => Faccia(f as Map<String, dynamic>)).toList();

  final String quando, scadenza, stato;
  final String? luogo;
  final int minimo, n;
  final bool passata, ciSono, aperta;
  final List<Faccia> facce;
}

class OpzioneSondaggio {
  OpzioneSondaggio(Map<String, dynamic> j)
    : id = _i(j['id']),
      testo = _s(j['testo']) ?? '',
      voti = j['voti'] == null ? null : _i(j['voti']),
      mia = j['mia'] == true;

  final int id;
  final String testo;

  /// null finché non si vedono i risultati (prima di votare)
  final int? voti;
  final bool mia;
}

class Sondaggio {
  Sondaggio(Map<String, dynamic> j)
    : opzioni = (j['opzioni'] as List? ?? []).map((o) => OpzioneSondaggio(o as Map<String, dynamic>)).toList(),
      votanti = _i(j['votanti']),
      multi = j['multi'] == true,
      soloResidenti = j['solo_residenti'] == true,
      chiude = _s(j['chiude_testo']),
      chiuso = j['chiuso'] == true,
      votato = j['votato'] == true,
      risultati = j['risultati'] == true,
      puo = j['puo'] == true,
      motivo = _s(j['motivo']);

  final List<OpzioneSondaggio> opzioni;
  final int votanti;
  final bool multi, soloResidenti, chiuso, votato, risultati, puo;
  final String? chiude, motivo;
}

class Pagina {
  Pagina(Map<String, dynamic> j)
    : post = (j['post'] as List).map((p) => Post(p as Map<String, dynamic>)).toList(),
      altri = j['altri'] == true,
      notifiche = j['notifiche'] == null ? null : _i(j['notifiche']);

  final List<Post> post;
  final bool altri;
  final int? notifiche;
}

class Commento {
  Commento(Map<String, dynamic> j)
    : id = _i(j['id']),
      padre = j['parent_id'] == null ? null : _i(j['parent_id']),
      testo = _s(j['content']) ?? '',
      creato = DateTime.tryParse(_s(j['created_at']) ?? ''),
      username = _s(j['username']) ?? '',
      nome = _s(j['nome']) ?? '',
      avatar = _s(j['avatar']),
      likes = _i(j['likes']),
      mia = _s(j['mia']),
      top = _l(j['top']),
      autoreDelPost = j['autore'] == true,
      mio = j['mio'] == true,
      puoEliminare = j['elimina'] == true,
      bot = j['bot'] == true,
      stemma = j['stemma'] is Map ? Stemma(j['stemma'] as Map<String, dynamic>) : null;

  final int id;
  final int? padre;
  final String testo, username, nome;
  final DateTime? creato;
  final String? avatar;
  int likes;
  String? mia;
  List<String> top;
  final bool autoreDelPost, mio, puoEliminare, bot;
  final Stemma? stemma;
}

class Notifica {
  Notifica(Map<String, dynamic> j)
    : id = _i(j['id']),
      tipo = _s(j['tipo']) ?? '',
      icona = _s(j['icona']) ?? 'bell',
      frase = _s(j['frase']) ?? '',
      chi = j['chi'] is Map ? Faccia(j['chi'] as Map<String, dynamic>) : null,
      testo = _s(j['testo']) ?? '',
      quando = _s(j['quando']) ?? '',
      letta = j['letta'] == true,
      vai = (j['vai'] as Map?)?.cast<String, dynamic>() ?? const {};

  final int id;
  final String tipo, icona, frase, testo, quando;
  final Faccia? chi;
  bool letta;
  final Map<String, dynamic> vai;
}

/// La persona che usa l'app, con permessi e impostazioni del sito.
class Io {
  Io(this.j);

  final Map<String, dynamic> j;

  Map<String, dynamic> get _u => j['utente'] as Map<String, dynamic>;
  Faccia get faccia => Faccia(_u);
  int get id => _i(_u['id']);
  String get username => _s(_u['username']) ?? '';
  String get nome => _s(_u['nome']) ?? username;
  String? get bio => _s(_u['bio']);
  String? get lavoro => _s(_u['lavoro']);
  String? get luogo => _s(_u['luogo']);
  String? get sitoWeb => _s(_u['sito']);
  String? get copertina => _s(_u['copertina']);
  String get email => _s(_u['email']) ?? '';
  String get ruolo => _s(_u['ruolo']) ?? 'user';

  Map<String, dynamic>? get casa => j['casa'] as Map<String, dynamic>?;
  String? get residenza => _s(j['residenza']);
  int get giorniCambio => _i(j['giorni_cambio']);
  int get garanzieMin => j['garanzie_min'] == null ? 2 : _i(j['garanzie_min']);

  /// Persone minime per un'attività (chi propone può chiederne di più).
  int get attivitaMin => j['attivita_min'] == null ? 3 : _i(j['attivita_min']);

  /// «tre vicini» (con la soglia vera del sito)
  String get viciniGaranti {
    const l = {1: 'un vicino', 2: 'due vicini', 3: 'tre vicini', 4: 'quattro vicini', 5: 'cinque vicini'};
    return l[garanzieMin] ?? '$garanzieMin vicini';
  }

  bool _puo(String k) => (j['puo'] as Map?)?[k] == true;
  bool get puoPubblicare => _puo('pubblicare');
  bool get puoCommentare => _puo('commentare');
  bool get residente => _puo('residente');
  bool get admin => _puo('admin');
  bool get fotoPost => _puo('foto');

  int get maxPost => _i((j['limiti'] as Map?)?['post']);
  int get maxCommento => _i((j['limiti'] as Map?)?['commento']);
  int get notifiche => _i(j['notifiche']);
  Map<String, dynamic> get conti => (j['conti'] as Map?)?.cast<String, dynamic>() ?? const {};

  List<(String, String)> get schede => (j['schede'] as List? ?? []).map((s) => ('${(s as Map)['id']}', '${s['nome']}')).toList();

  Map<String, String> get tamtam => (j['tamtam'] as Map? ?? {}).map((k, v) => MapEntry('$k', '$v'));
  Map<String, String> get reazioni => (j['reazioni'] as Map? ?? {}).map((k, v) => MapEntry('$k', '$v'));
  List<String> get motivi => _l(j['motivi']);
}

class DatiIscrizione {
  DatiIscrizione(Map<String, dynamic> j)
    : gruppi = (j['gruppi'] as List)
          .map(
            (g) => (
              '${(g as Map)['nome']}',
              (g['quartieri'] as List).map((q) => ('${(q as Map)['id']}', '${q['nome']}', '${q['colore']}')).toList(),
            ),
          )
          .toList(),
      spenti = (j['spenti'] as List).map((c) => (_s((c as Map)['chiave']) ?? 'c${c['id']}', '${c['nome']}', _i(c['richieste']))).toList(),
      soglia = _i(j['soglia']);

  /// (nome municipalità, [(id, nome, colore)])
  final List<(String, List<(String, String, String)>)> gruppi;

  /// (chiave `c12` comune o `q34` quartiere di Napoli, nome, richieste)
  final List<(String, String, int)> spenti;
  final int soglia;
}

class QuartiereMappa {
  QuartiereMappa(Map<String, dynamic> j)
    : id = _i(j['id']),
      nome = _s(j['nome']) ?? '',
      slug = _s(j['slug']) ?? '',
      colore = _s(j['colore']) ?? '#e0663a',
      residenti = _i(j['residenti']),
      post = _i(j['post']),
      citta = _s(j['citta']) ?? '',
      stemma = _s(j['stemma']),
      copertina = _s(j['copertina']),
      forma = _s(j['forma']),
      box = (j['box'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      centro = (j['centro'] as List?)?.map((e) => (e as num).toDouble()).toList();

  final int id, residenti, post;
  final String nome, slug, colore, citta;
  final String? stemma, copertina, forma;
  final List<double>? box, centro;
}

class Mappa {
  Mappa(Map<String, dynamic> j)
    : gruppi = (j['gruppi'] as List)
          .map((g) => ('${(g as Map)['nome']}', (g['quartieri'] as List).map((q) => QuartiereMappa(q as Map<String, dynamic>)).toList()))
          .toList(),
      municipalita = (j['gruppi'] as List)
          .where((g) => _i((g as Map)['id']) > 0)
          .map((g) => (id: _i((g as Map)['id']), nome: '${g['nome']}'))
          .toList(),
      seguiti = (j['seguiti'] as List? ?? []).map(_i).toSet(),
      casa = j['casa'] == null ? null : _i(j['casa']),
      giorniCambio = _i(j['giorni_cambio']),
      spenti = (j['spenti'] as List? ?? [])
          .map(
            (c) => (
              chiave: _s((c as Map)['chiave']) ?? 'c${c['id']}',
              nome: '${c['nome']}',
              richieste: _i(c['richieste']),
              mia: c['mia'] == true,
            ),
          )
          .toList(),
      sogliaApertura = _i(j['soglia_apertura']),
      crediti = _s(j['crediti']) ?? '';

  final List<(String, List<QuartiereMappa>)> gruppi;

  /// Municipalità di Napoli (il gruppo dei comuni ha id 0 e non c'è).
  final List<({int id, String nome})> municipalita;
  final Set<int> seguiti;
  final int? casa;
  final int giorniCambio, sogliaApertura;

  /// Comuni e quartieri di Napoli ancora spenti, da chiedere (chiave `c12` o `q34`).
  final List<({String chiave, String nome, int richieste, bool mia})> spenti;
  final String crediti;

  List<QuartiereMappa> get tutti => [for (final g in gruppi) ...g.$2];
}
