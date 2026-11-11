// Collegamento a triburba.it: API dell'app (/app/v1/…) e azioni rapide del sito (/api/…), col token in X-Token.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'modelli.dart';

const sito = 'https://triburba.it';

/// Indirizzo completo di un percorso del sito («/storage/…» → «https://triburba.it/storage/…»).
String? assoluto(String? p) {
  if (p == null || p.isEmpty) return null;
  if (p.startsWith('http://') || p.startsWith('https://') || p.startsWith('data:')) return p;
  return '$sito${p.startsWith('/') ? '' : '/'}$p';
}

/// Errore da mostrare alla persona così com'è (il server scrive già in italiano).
class ErroreApi implements Exception {
  ErroreApi(this.messaggio, {this.codice = 0});

  final String messaggio;
  final int codice;

  bool get accessoScaduto => codice == 401;

  @override
  String toString() => messaggio;
}

class Api {
  Api({required this.versione, http.Client? client}) : _http = client ?? http.Client();

  final String versione;
  final http.Client _http;
  String? token;

  /// Chiamato quando il server dice che l'accesso non vale più (401): l'app torna alla schermata di accesso.
  void Function()? accessoScaduto;

  static const _chiaveToken = 'triburba_token';

  Future<void> caricaToken() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_chiaveToken);
  }

  Future<void> _salvaToken(String? t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    if (t == null) {
      await p.remove(_chiaveToken);
    } else {
      await p.setString(_chiaveToken, t);
    }
  }

  Map<String, String> get _testate => {
    'Accept': 'application/json',
    'User-Agent': 'triburba-app/$versione (${Platform.operatingSystem})',
    'X-Token': ?token,
  };

  Future<Map<String, dynamic>> _leggi(http.Response r) async {
    Map<String, dynamic>? j;
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map<String, dynamic>) j = d;
    } catch (_) {}
    if (r.statusCode == 401 && token != null) {
      await _salvaToken(null);
      accessoScaduto?.call();
    }
    if (j == null) {
      throw ErroreApi(
        r.statusCode >= 500 ? 'triburba non risponde in questo momento: riprova tra poco.' : 'Qualcosa non è andato: riprova.',
        codice: r.statusCode,
      );
    }
    if (r.statusCode >= 400 || j['ok'] == false) {
      throw ErroreApi((j['error'] ?? j['msg'] ?? 'Operazione non riuscita.').toString(), codice: r.statusCode);
    }
    return j;
  }

  Future<T> _rete<T>(Future<T> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 30));
    } on ErroreApi {
      rethrow;
    } on SocketException {
      throw ErroreApi('Sei senza connessione: controlla la rete e riprova.');
    } on HttpException {
      throw ErroreApi('Sei senza connessione: controlla la rete e riprova.');
    } on Exception {
      throw ErroreApi('triburba non risponde in questo momento: riprova tra poco.');
    }
  }

  Future<Map<String, dynamic>> get(String percorso, [Map<String, String>? query]) => _rete(() async {
    final u = Uri.parse('$sito$percorso').replace(queryParameters: query == null || query.isEmpty ? null : query);
    return _leggi(await _http.get(u, headers: _testate));
  });

  Future<Map<String, dynamic>> post(String percorso, [Map<String, dynamic>? dati]) => _rete(() async {
    final r = await _http.post(
      Uri.parse('$sito$percorso'),
      headers: {..._testate, 'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(dati ?? {}),
    );
    return _leggi(r);
  });

  /// Invio con file (foto del post, foto profilo).
  Future<Map<String, dynamic>> invia(String percorso, Map<String, String> campi, {String? campoFile, File? file}) => _rete(() async {
    final req = http.MultipartRequest('POST', Uri.parse('$sito$percorso'))
      ..headers.addAll(_testate)
      ..fields.addAll(campi);
    if (file != null && campoFile != null) req.files.add(await http.MultipartFile.fromPath(campoFile, file.path));
    final r = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 90)));
    return _leggi(r);
  });

  // ── Accesso ──

  String get _piattaforma => Platform.isIOS ? 'ios' : 'android';

  /// Rimanda il link di conferma dell'email (limite: uno ogni 2 minuti, 5 al giorno)
  Future<String> rimandaEmail() async => ((await post('/app/v1/email/rimanda'))['msg'] ?? '').toString();

  /// «Password dimenticata?»: il server risponde sempre allo stesso modo
  Future<String> passwordDimenticata(String email) async =>
      ((await post('/app/v1/password-dimenticata', {'email': email}))['msg'] ?? '').toString();

  Future<Io> accedi(String id, String password) async {
    final j = await post('/app/v1/accedi', {'id': id, 'password': password, 'piattaforma': _piattaforma, 'versione': versione});
    await _salvaToken(j['token'] as String);
    return Io(j['io']);
  }

  Future<DatiIscrizione> datiIscrizione() async => DatiIscrizione(await get('/app/v1/iscrizione'));

  /// Ritorna (io, messaggio di benvenuto).
  Future<(Io, String)> iscriviti(Map<String, dynamic> dati) async {
    final j = await post('/app/v1/iscriviti', {...dati, 'piattaforma': _piattaforma, 'versione': versione});
    await _salvaToken(j['token'] as String);
    return (Io(j['io']), (j['msg'] ?? '').toString());
  }

  Future<void> esci() async {
    try {
      await post('/app/v1/esci');
    } catch (_) {}
    await _salvaToken(null);
  }

  Future<Io> io() async => Io((await get('/app/v1/io'))['io']);

  /// Guida: «benvenuto» visto, carta «nascondi», «invito» fatto.
  Future<Map<String, dynamic>> guida(String azione) => post('/app/v1/guida', {'azione': azione});

  Future<void> registraPush(String fcm) => post('/app/v1/push', {'fcm': fcm, 'versione': versione});

  /// Preferenze delle notifiche: categorie con campanella e telefono
  Future<Map<String, dynamic>> preferenzeNotifiche() => get('/app/v1/notifiche/preferenze');
  Future<Map<String, dynamic>> salvaPreferenzeNotifiche(Map<String, dynamic> scelte) =>
      post('/app/v1/notifiche/preferenze', {'scelte': scelte});

  // ── Post ──

  Future<Pagina> feed(String scheda, {int prima = 0}) async {
    final j = await get('/app/v1/feed', {'scheda': scheda, if (prima > 0) 'prima': '$prima'});
    return Pagina(j);
  }

  Future<Post> leggiPost(int id) async => Post((await get('/app/v1/post/$id'))['post']);

  /// [extra]: tipo `attivita` o `sondaggio` con i loro campi (vedi Iniziative::campi sul sito).
  Future<(Post?, String)> pubblica(
    String testo, {
    File? foto,
    String portata = 'quartiere',
    bool senzaAnteprima = false,
    Map<String, String> extra = const {},
  }) async {
    final j = await invia(
      '/app/v1/pubblica',
      {'testo': testo, 'portata': portata, if (senzaAnteprima) 'senza_anteprima': '1', ...extra},
      campoFile: 'foto',
      file: foto,
    );
    return (j['post'] == null ? null : Post(j['post']), (j['msg'] ?? '').toString());
  }

  Future<Post?> modifica(int postId, String testo) async {
    final j = await post('/app/v1/post/modifica', {'post_id': postId, 'testo': testo});
    return j['post'] == null ? null : Post(j['post']);
  }

  Future<void> elimina(int postId) => post('/app/v1/post/elimina', {'post_id': postId});
  Future<void> togliAnteprima(int postId) => post('/app/v1/post/togli-anteprima', {'post_id': postId});
  Future<Map<String, dynamic>> compleanni() => get('/app/v1/compleanni');
  Future<String> auguri(int userId) async => '${(await post('/app/v1/compleanno/auguri', {'user_id': userId}))['msg'] ?? 'Auguri fatti!'}';
  Future<String> compleannoPubblico(bool si) async => '${(await post('/app/v1/compleanno/pubblico', {'si': si ? 1 : 0}))['msg'] ?? ''}';

  /// Ci sarò / mi ritiro da un'attività. Ritorna il messaggio.
  Future<String> partecipa(int postId) async => ((await post('/api/attivita/partecipa', {'post_id': postId}))['msg'] ?? '').toString();

  /// Voto (nessuna risposta = toglie il voto). Ritorna il messaggio.
  Future<String> vota(int postId, List<int> opzioni) async =>
      ((await post('/api/sondaggio/vota', {'post_id': postId, 'opzioni': opzioni}))['msg'] ?? '').toString();

  /// Reazione al post: stessa = la toglie, diversa = la cambia.
  Future<Map<String, dynamic>> reagisci(int postId, String reazione) => post('/api/like/toggle', {'post_id': postId, 'reazione': reazione});

  Future<(List<Commento>, bool)> commenti(int postId) async {
    final j = await get('/api/comment/list', {'post_id': '$postId'});
    return ((j['comments'] as List).map((c) => Commento(c)).toList(), j['puo_commentare'] == true);
  }

  Future<Commento> commenta(int postId, String testo, {int? rispostaA}) async {
    final j = await post('/api/comment/add', {'post_id': postId, 'content': testo, 'parent_id': ?rispostaA});
    return Commento(j['comment']);
  }

  Future<Map<String, dynamic>> reagisciCommento(int id, String reazione) =>
      post('/api/comment/like', {'comment_id': id, 'reazione': reazione});

  Future<void> eliminaCommento(int id) => post('/api/comment/delete', {'comment_id': id});

  Future<List<Map<String, dynamic>>> chiHaReagito(int postId) async =>
      ((await get('/api/post/reazioni', {'post_id': '$postId'}))['persone'] as List).cast<Map<String, dynamic>>();

  /// Tam-tam: dest = `c:1` (tutta la città), `q:ID` (altro quartiere), `m:ID` (municipalità).
  Future<String> tamtam(int postId, String dest) async =>
      ((await post('/api/porta', {'post_id': postId, 'dest': dest}))['msg'] ?? '').toString();

  /// Ritira un tam-tam fatto da me: {citta, rilanci, arrivato} oppure {livello, nome}, sempre con msg.
  Future<Map<String, dynamic>> ritiraTamtam(int postId, String dest) => post('/api/porta/ritira', {'post_id': postId, 'dest': dest});

  /// Segna la condivisione e restituisce quante persone hanno condiviso il post.
  Future<int> condiviso(int postId, String canale) async =>
      ((await post('/api/condiviso', {'post_id': postId, 'canale': canale}))['condivisioni'] as num? ?? 0).toInt();

  // ── Hashtag ──
  Future<Map<String, dynamic>> tag(String tag) => get('/app/v1/tag/${Uri.encodeComponent(tag)}');

  Future<Map<String, dynamic>> seguiTag(String tag) => post('/api/hashtag/segui', {'tag': tag});

  Future<String> segnala(int postId, String motivo) async =>
      ((await post('/api/segnala', {'post_id': postId, 'motivo': motivo}))['msg'] ?? '').toString();

  // ── Persone e quartieri ──

  Future<Map<String, dynamic>> segui(String username) => post('/api/follow/toggle', {'username': username});

  /// Blocca o sblocca una persona (requisito Play per i social: i suoi contenuti spariscono nei due sensi).
  Future<Map<String, dynamic>> blocca(String username, {bool sblocca = false}) =>
      post('/app/v1/blocca', {'username': username, 'azione': sblocca ? 'sblocca' : 'blocca'});

  Future<Map<String, dynamic>> bloccati() => get('/app/v1/bloccati');

  /// Chi suggerire quando si scrive @ (post e commenti)
  Future<Map<String, dynamic>> menzioni(String q, {int? postId}) =>
      get('/app/v1/menzioni', {'q': q, if (postId != null) 'post': '$postId'});

  Future<Map<String, dynamic>> cerca(String q) => get('/api/cerca', {'q': q});

  Future<Mappa> mappa() async => Mappa(await get('/app/v1/mappa'));

  Future<Map<String, dynamic>> quartiere(String slug, {int prima = 0}) =>
      get('/app/v1/quartiere/$slug', {if (prima > 0) 'prima': '$prima'});

  Future<Map<String, dynamic>> residenti(String slug) => get('/app/v1/quartiere/$slug/residenti');

  Future<Map<String, dynamic>> scegliCasa(int quartiereId) => post('/app/v1/quartiere/casa', {'quartiere_id': quartiereId});

  Future<Map<String, dynamic>> seguiQuartiere(int quartiereId) => post('/app/v1/quartiere/segui', {'quartiere_id': quartiereId});

  Future<Map<String, dynamic>> garantisci(int quartiereId, int userId, {bool conferma = false}) =>
      post('/app/v1/quartiere/garantisci', {'quartiere_id': quartiereId, 'user_id': userId, if (conferma) 'conferma': 1});

  Future<Map<String, dynamic>> chiediZona(String chiave) => post('/app/v1/comune/chiedi', {'chiave': chiave});

  /// Follower ('follower') o Seguiti ('seguiti') di una persona, 25 per pagina
  Future<Map<String, dynamic>> elencoFollow(String username, String tipo, {int pagina = 1}) =>
      get('/app/v1/utente/${Uri.encodeComponent(username)}/$tipo', {if (pagina > 1) 'pagina': '$pagina'});

  Future<Map<String, dynamic>> utente(String username, {int prima = 0}) =>
      get('/app/v1/utente/${Uri.encodeComponent(username)}', {if (prima > 0) 'prima': '$prima'});

  Future<Io> salvaProfilo(Map<String, String> dati) async => Io((await post('/app/v1/profilo', dati))['io']);

  // ── Account: username, email, password, i miei dati ──

  /// Ritorna (io aggiornato, messaggio).
  Future<(Io, String)> cambiaUsername(String username) async {
    final j = await post('/app/v1/account/username', {'username': username});
    return (Io(j['io']), (j['msg'] ?? '').toString());
  }

  Future<(Io, String)> cambiaEmail(String email, String password) async {
    final j = await post('/app/v1/account/email', {'email': email, 'password': password});
    return (Io(j['io']), (j['msg'] ?? '').toString());
  }

  Future<String> cambiaPassword(String attuale, String nuova, String conferma) async =>
      ((await post('/app/v1/account/password', {'attuale': attuale, 'nuova': nuova, 'conferma': conferma}))['msg'] ?? '').toString();

  /// I miei dati in un file JSON: (nome del file, contenuto).
  Future<(String, Map<String, dynamic>)> scaricaDati() async {
    final j = await get('/app/v1/account/dati');
    return ((j['nome_file'] ?? 'triburba-dati.json').toString(), (j['dati'] as Map).cast<String, dynamic>());
  }

  // ── Pannello admin (solo staff) e pagine legali ──

  Map<String, String> _q(Map<String, Object?> m) => {
    for (final e in m.entries)
      if (e.value != null && '${e.value}' != '') e.key: '${e.value}',
  };

  Future<Map<String, dynamic>> adminGestione({int pu = 1, int pp = 1, bool post7 = false}) =>
      get('/app/v1/admin/gestione', _q({'pu': pu, 'pp': pp, 'post7': post7 ? 1 : null}));
  Future<Map<String, dynamic>> adminSospendi(int userId, bool ban) => post('/app/v1/admin/utente/sospendi', {'user_id': userId, 'ban': ban ? 1 : 0});
  Future<Map<String, dynamic>> adminRuolo(int userId, String ruolo) => post('/app/v1/admin/utente/ruolo', {'user_id': userId, 'role': ruolo});
  Future<Map<String, dynamic>> adminEliminaPost(int postId) => post('/app/v1/admin/post/elimina', {'post_id': postId});
  Future<Map<String, dynamic>> adminImmagine(int postId, String azione) => post('/app/v1/admin/immagine', {'post_id': postId, 'azione': azione});
  Future<Map<String, dynamic>> adminResidente(int userId) => post('/app/v1/admin/residente', {'user_id': userId});
  Future<Map<String, dynamic>> adminZona(String tipo, int id, bool acceso) => post('/app/v1/admin/zona', {'tipo': tipo, 'id': id, 'acceso': acceso ? 1 : 0});
  Future<Map<String, dynamic>> adminSoglie(Map<String, int> valori) => post('/app/v1/admin/soglie', {'valori': valori});
  Future<Map<String, dynamic>> adminPubblicazione(Map<String, String> valori) => post('/app/v1/admin/pubblicazione', {'valori': valori});
  Future<Map<String, dynamic>> adminStatistiche() => get('/app/v1/admin/statistiche');
  Future<Map<String, dynamic>> adminIscritti({int giorni = 30, String cerca = '', int pn = 1, int pv = 1}) =>
      get('/app/v1/admin/iscritti', _q({'giorni': giorni, 'q': cerca, 'pn': pn, 'pv': pv}));
  Future<Map<String, dynamic>> adminVisite({int giorni = 30, String ordine = 'ultimo', int pa = 1}) =>
      get('/app/v1/admin/visite', _q({'giorni': giorni, 'ordine': ordine, 'pa': pa}));
  Future<Map<String, dynamic>> adminRegistro({String azione = '', int pg = 1}) => get('/app/v1/admin/registro', _q({'azione': azione, 'pg': pg}));
  Future<Map<String, dynamic>> adminCommenti({int pc = 1}) => get('/app/v1/admin/commenti', _q({'pc': pc}));
  Future<Map<String, dynamic>> adminEliminaCommento(int id) => post('/app/v1/admin/commento/elimina', {'comment_id': id});
  Future<Map<String, dynamic>> legale(String pagina) => get('/app/v1/legale/$pagina');

  // ── Da fare, nuovi vicini e benvenuto ──

  /// La fila «Da fare» di chi è collegato (uguale alla Home del sito): {voci: [...]}.
  Future<List<Map<String, dynamic>>> daFare() async =>
      ((await get('/app/v1/da-fare'))['voci'] as List).cast<Map<String, dynamic>>();

  /// Chi è arrivato nel mio quartiere negli ultimi 7 giorni: [{id, faccia, quando, salutato}].
  Future<List<Map<String, dynamic>>> nuoviVicini() async =>
      ((await get('/app/v1/nuovi-vicini'))['persone'] as List).cast<Map<String, dynamic>>();

  /// Benvenuto a un nuovo vicino (una volta sola): {msg}.
  Future<Map<String, dynamic>> benvenuto(int userId) => post('/app/v1/benvenuto', {'user_id': userId});

  // ── Moderatori e moderazione del quartiere ──

  Future<Map<String, dynamic>> moderazione(String slug) => get('/app/v1/quartiere/$slug/moderazione');

  /// Voto segreto a un candidato (rifarlo lo ritira): {votato, voti, eletto, msg}.
  Future<Map<String, dynamic>> votaCandidato(int quartiereId, int candidatoId) =>
      post('/app/v1/candidatura/vota', {'quartiere_id': quartiereId, 'candidato_id': candidatoId});

  /// Candidarsi o ritirare la candidatura: {candidato, msg}.
  Future<Map<String, dynamic>> candidatura(int quartiereId, {String motivazione = ''}) =>
      post('/app/v1/candidatura', {'quartiere_id': quartiereId, 'motivazione': motivazione});

  Future<Map<String, dynamic>> sfiducia(int quartiereId, int moderatoreId) =>
      post('/app/v1/moderatore/sfiducia', {'quartiere_id': quartiereId, 'moderatore_id': moderatoreId});

  Future<String> salvaRegole(int quartiereId, String regole) async =>
      ((await post('/app/v1/quartiere/regole', {'quartiere_id': quartiereId, 'regole': regole}))['msg'] ?? '').toString();

  Future<String> ripristina(int quartiereId, int postId) async =>
      ((await post('/app/v1/quartiere/ripristina', {'quartiere_id': quartiereId, 'post_id': postId}))['msg'] ?? '').toString();

  Future<String> decidiProposta(int quartiereId, int postId, String livello, bool accetta) async =>
      ((await post('/app/v1/quartiere/proposta', {'quartiere_id': quartiereId, 'post_id': postId, 'livello': livello, 'accetta': accetta}))['msg'] ?? '').toString();

  Future<Io> cambiaFoto(File foto, {bool copertina = false}) async =>
      Io((await invia('/app/v1/profilo/foto', {'tipo': copertina ? 'copertina' : 'avatar'}, campoFile: 'foto', file: foto))['io']);

  Future<void> eliminaAccount(String password) async {
    await post('/app/v1/account/elimina', {'password': password});
    await _salvaToken(null);
  }

  // ── Notifiche ──

  Future<(List<Notifica>, int)> notifiche() async {
    final j = await get('/app/v1/notifiche');
    return ((j['notifiche'] as List).map((n) => Notifica(n)).toList(), (j['nuove'] as num).toInt());
  }

  Future<int> segnaLette({int? id}) async =>
      ((await post('/app/v1/notifiche/lette', id == null ? {'tutte': 1} : {'id': id}))['nuove'] as num).toInt();
}
