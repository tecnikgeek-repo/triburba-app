// Messaggi privati: elenco delle chat e delle richieste, e la chat con una persona.
// Stesse regole del sito (le decide il server): chat libera tra chi si segue a vicenda e tra residenti dello stesso
// quartiere, altrimenti richiesta; tra adulti e minorenni solo se ci si segue a vicenda; foto e testi filtrati.
import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import '../widget/segnala.dart';
import 'bloccati.dart';
import 'naviga.dart';

class SchermataMessaggi extends StatefulWidget {
  const SchermataMessaggi({super.key});

  @override
  State<SchermataMessaggi> createState() => _SchermataMessaggiState();
}

class _SchermataMessaggiState extends State<SchermataMessaggi> with SingleTickerProviderStateMixin {
  late final TabController _schede = TabController(length: 2, vsync: this);
  List<VoceChat>? _chat, _richieste;
  int _nChat = 0, _nRichieste = 0;
  String? _errore;
  Timer? _giro;

  @override
  void initState() {
    super.initState();
    _carica();
    _giro = Timer.periodic(const Duration(seconds: 20), (_) => _carica());
    stato.arrivoMessaggi.addListener(_carica);
  }

  @override
  void dispose() {
    _giro?.cancel();
    stato.arrivoMessaggi.removeListener(_carica);
    _schede.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    try {
      final (c, nc, nr) = await stato.api.chat();
      final (r, _, _) = await stato.api.chat(richieste: true);
      if (!mounted) return;
      setState(() {
        _chat = c;
        _richieste = r;
        _nChat = nc;
        _nRichieste = nr;
        _errore = null;
      });
      stato.impostaMessaggi(nc + nr);
    } on ErroreApi catch (e) {
      if (mounted && _chat == null) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _apri(VoceChat v) async {
    await apriChat(context, convId: v.id);
    _carica();
  }

  Widget _scheda(String nome, int n) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(nome),
        if (n > 0) ...[const SizedBox(width: 6), Badge(label: Text(n > 99 ? '99+' : '$n'), backgroundColor: terracotta)],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaggi'),
        bottom: TabBar(
          controller: _schede,
          tabAlignment: TabAlignment.fill,
          tabs: [_scheda('Chat', _nChat), _scheda('Richieste', _nRichieste)],
        ),
      ),
      body: _errore != null && _chat == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errore!, textAlign: TextAlign.center),
              ),
            )
          : _chat == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _schede,
              children: [
                _lista(
                  _chat!,
                  'Ancora nessuna chat',
                  'Apri il profilo di un vicino e tocca il fumetto per scrivergli. Chi vi seguite a vicenda o è residente nel tuo quartiere riceve subito; agli altri arriva una richiesta.',
                ),
                _lista(
                  _richieste!,
                  'Nessuna richiesta',
                  'Qui arrivano i messaggi di chi non segui e non è del tuo quartiere: decidi tu se accettarli.',
                ),
              ],
            ),
    );
  }

  Widget _lista(List<VoceChat> voci, String vuotoTitolo, String vuotoTesto) => RefreshIndicator(
    onRefresh: _carica,
    child: voci.isEmpty
        ? ListView(
            padding: const EdgeInsets.all(32),
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: terracotta),
              const SizedBox(height: 14),
              Text(vuotoTitolo, textAlign: TextAlign.center, style: titolo(18)),
              const SizedBox(height: 8),
              Text(
                vuotoTesto,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muto, height: 1.45),
              ),
            ],
          )
        : ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: voci.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
            itemBuilder: (_, i) {
              final v = voci[i];
              final nuova = v.nonLetti > 0;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: FotoProfilo(faccia: v.persona, lato: 48),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        v.persona.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (v.stato == 'richiesta' && v.mio) const _Etichetta('In attesa'),
                    if (v.stato == 'rifiutata') const _Etichetta('Non accettata'),
                  ],
                ),
                subtitle: Text(
                  '${v.mio ? 'Tu: ' : ''}${v.anteprima}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: nuova ? testo : muto, fontWeight: nuova ? FontWeight.w600 : FontWeight.w400),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(v.quando, style: const TextStyle(color: muto, fontSize: 12)),
                    if (nuova) ...[
                      const SizedBox(height: 4),
                      Badge(label: Text(v.nonLetti > 9 ? '9+' : '${v.nonLetti}'), backgroundColor: terracotta),
                    ],
                  ],
                ),
                onTap: () => _apri(v),
              );
            },
          ),
  );
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.t);
  final String t;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(6)),
    child: Text(
      t.toUpperCase(),
      style: const TextStyle(color: testo2, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .4),
    ),
  );
}

// ── Chat ──

class SchermataChat extends StatefulWidget {
  const SchermataChat({super.key, this.convId, this.username});

  final int? convId;
  final String? username;

  @override
  State<SchermataChat> createState() => _SchermataChatState();
}

class _SchermataChatState extends State<SchermataChat> with WidgetsBindingObserver {
  ChatAperta? _chat;
  int? _conv;
  final List<Messaggio> _msg = [];
  bool _altriPrima = false, _caricaPrima = false, _invio = false;
  int _lettoAltro = 0;
  String? _errore;
  File? _foto;
  Timer? _giro;
  final _campo = TextEditingController();
  final _scorri = ScrollController();

  // vocale in registrazione
  AudioRecorder? _rec;
  DateTime? _inizioReg;
  Timer? _orologioReg;
  int _secondiReg = 0;

  int get _ultimo => _msg.isEmpty ? 0 : _msg.last.id;

  @override
  void initState() {
    super.initState();
    _conv = widget.convId;
    stato.chatAperta = _conv;
    WidgetsBinding.instance.addObserver(this);
    stato.arrivoMessaggi.addListener(_aggiorna);
    _scorri.addListener(() {
      if (_altriPrima && !_caricaPrima && _scorri.hasClients && _scorri.position.pixels >= _scorri.position.maxScrollExtent - 200) _prima();
    });
    _campo.addListener(() {
      if (mounted) setState(() {}); // casella vuota: microfono al posto di «Invia»
    });
    _apri();
  }

  @override
  void dispose() {
    _giro?.cancel();
    _orologioReg?.cancel();
    _rec?.cancel().catchError((_) {});
    _rec?.dispose();
    LettoreVocale.fermaTutto();
    if (stato.chatAperta == _conv) stato.chatAperta = null;
    stato.arrivoMessaggi.removeListener(_aggiorna);
    WidgetsBinding.instance.removeObserver(this);
    _campo.dispose();
    _scorri.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _aggiorna();
  }

  void _avviaGiro() {
    _giro?.cancel();
    if (_conv != null) _giro = Timer.periodic(const Duration(seconds: 4), (_) => _aggiorna());
  }

  Future<void> _apri() async {
    try {
      final c = await stato.api.apriChat(convId: _conv, username: widget.username);
      if (!mounted) return;
      setState(() {
        _chat = c;
        _conv = c.convId;
        _msg
          ..clear()
          ..addAll(c.messaggi);
        _altriPrima = c.altriPrima;
        _lettoAltro = c.lettoAltro;
        _errore = null;
      });
      stato.chatAperta = _conv;
      _avviaGiro();
      if (_conv != null) stato.ricarica();
    } on ErroreApi catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _aggiorna() async {
    final conv = _conv, c = _chat;
    if (conv == null || c == null || !mounted) return;
    try {
      final n = await stato.api.apriChat(convId: conv, dopo: _ultimo);
      if (!mounted) return;
      // la richiesta è stata accettata (o è cambiato qualcosa): ricarico tutto
      if (n.puoScrivere != c.puoScrivere || n.richiestaRicevuta != c.richiestaRicevuta || n.fotoPermesse != c.fotoPermesse) {
        _apri();
        return;
      }
      final nuovi = n.messaggi.where((m) => !_msg.any((x) => x.id == m.id)).toList();
      // eliminati dall'altro mentre guardo: ritirati spariscono, gli altri diventano «Messaggio eliminato»
      var cambiato = false;
      for (final c in n.cambiati) {
        final i = _msg.indexWhere((x) => x.id == c.id);
        if (i < 0) continue;
        if (c.sparito) {
          _msg.removeAt(i);
          cambiato = true;
        } else if (!_msg[i].eliminato) {
          _msg[i]
            ..eliminato = true
            ..testo = ''
            ..foto = null
            ..audio = null;
          cambiato = true;
        }
      }
      if (nuovi.isEmpty && n.lettoAltro == _lettoAltro && !cambiato) return;
      setState(() {
        _msg.addAll(nuovi);
        _lettoAltro = n.lettoAltro;
      });
      if (nuovi.isNotEmpty) stato.ricarica();
    } catch (_) {}
  }

  Future<void> _prima() async {
    final conv = _conv;
    if (conv == null || _msg.isEmpty) return;
    setState(() => _caricaPrima = true);
    try {
      final n = await stato.api.apriChat(convId: conv, prima: _msg.first.id);
      if (!mounted) return;
      setState(() {
        _msg.insertAll(0, n.messaggi.where((m) => !_msg.any((x) => x.id == m.id)));
        _altriPrima = n.altriPrima;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _caricaPrima = false);
    }
  }

  Future<void> _scegliFoto() async {
    final da = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(s, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta una foto'),
              onTap: () => Navigator.pop(s, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (da == null) return;
    final x = await ImagePicker().pickImage(source: da, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
    if (x != null && mounted) setState(() => _foto = File(x.path));
  }

  Future<void> _manda() async {
    final t = _campo.text.trim();
    if ((t.isEmpty && _foto == null) || _invio) return;
    setState(() => _invio = true);
    try {
      final (conv, m, statoChat) = await stato.api.mandaMessaggio(
        convId: _conv,
        username: _conv == null ? widget.username : null,
        testo: t,
        foto: _foto,
      );
      if (!mounted) return;
      final nuova = _conv == null;
      setState(() {
        _conv = conv;
        if (!_msg.any((x) => x.id == m.id)) _msg.add(m);
        _campo.clear();
        _foto = null;
      });
      stato.chatAperta = conv;
      if (nuova || statoChat != 'attiva') {
        _apri(); // avviso aggiornato (richiesta: al massimo 3 messaggi)
      } else if (_giro == null) {
        _avviaGiro();
      }
      if (_scorri.hasClients) _scorri.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _invio = false);
    }
  }

  bool get _registra => _inizioReg != null;

  Future<void> _iniziaVocale() async {
    final r = _rec ??= AudioRecorder();
    try {
      if (!await r.hasPermission()) {
        if (mounted) messaggio(context, 'Per mandare un vocale consenti a triburba di usare il microfono dalle impostazioni del telefono.');
        return;
      }
      LettoreVocale.fermaTutto();
      final dir = await getTemporaryDirectory();
      final percorso = '${dir.path}/registrazione-${DateTime.now().millisecondsSinceEpoch}.m4a';
      // Microfono del telefono, mai quello Bluetooth «da telefonata» (cuffie, auto, orologio): registra a 8-16 kHz e la voce
      // esce robotica. Qualità piena (48 kHz, 128 kbit/s): il server la tiene così com'è, senza ricomprimerla.
      await r.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 48000,
          numChannels: 1,
          androidConfig: AndroidRecordConfig(manageBluetooth: false, audioSource: AndroidAudioSource.mic),
          iosConfig: IosRecordConfig(categoryOptions: [IosAudioCategoryOption.defaultToSpeaker, IosAudioCategoryOption.allowBluetoothA2DP]),
        ),
        path: percorso,
      );
      if (!mounted) return;
      setState(() {
        _inizioReg = DateTime.now();
        _secondiReg = 0;
      });
      _orologioReg = Timer.periodic(const Duration(milliseconds: 250), (_) {
        final s = DateTime.now().difference(_inizioReg!).inSeconds;
        if (s != _secondiReg && mounted) setState(() => _secondiReg = s);
        if (s >= 180) _fermaVocale(manda: true); // al massimo 3 minuti
      });
    } catch (_) {
      if (mounted) messaggio(context, 'Il microfono non risponde: riprova tra poco.');
    }
  }

  Future<void> _fermaVocale({required bool manda}) async {
    final r = _rec, inizio = _inizioReg;
    if (r == null || inizio == null) return;
    _orologioReg?.cancel();
    final durata = DateTime.now().difference(inizio);
    setState(() => _inizioReg = null);
    try {
      if (!manda) {
        await r.cancel();
        return;
      }
      final percorso = await r.stop();
      if (percorso == null) return;
      if (durata.inMilliseconds < 800) {
        if (mounted) messaggio(context, 'Il vocale è troppo corto: tocca il microfono e parla.');
        return;
      }
      await _mandaVocale(File(percorso));
    } catch (_) {
      if (mounted) messaggio(context, 'Il vocale non si è registrato bene: riprova.');
    }
  }

  Future<void> _mandaVocale(File f) async {
    setState(() => _invio = true);
    try {
      final (conv, m, statoChat) = await stato.api.mandaMessaggio(
        convId: _conv,
        username: _conv == null ? widget.username : null,
        vocale: f,
      );
      if (!mounted) return;
      final nuova = _conv == null;
      setState(() {
        _conv = conv;
        if (!_msg.any((x) => x.id == m.id)) _msg.add(m);
      });
      stato.chatAperta = conv;
      if (nuova || statoChat != 'attiva') {
        _apri();
      } else if (_giro == null) {
        _avviaGiro();
      }
      if (_scorri.hasClients) _scorri.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      f.delete().catchError((_) => f);
      if (mounted) setState(() => _invio = false);
    }
  }

  Future<void> _rispondi(bool accetta) async {
    final conv = _conv;
    if (conv == null) return;
    try {
      final msg = await stato.api.rispondiRichiesta(conv, accetta);
      if (!mounted) return;
      messaggio(context, msg);
      if (accetta) {
        _apri();
      } else {
        Navigator.pop(context);
      }
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  Future<void> _azioniMessaggio(Messaggio m) async {
    Widget voce(String chiave, IconData ico, String titolo, String sotto, {bool rosso = false}) => ListTile(
      leading: Icon(ico, color: rosso ? pompeiano : testo2),
      title: Text(
        titolo,
        style: TextStyle(color: rosso ? pompeiano : testo, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(sotto, style: const TextStyle(color: muto, fontSize: 12.5)),
      onTap: () => Navigator.pop(context, chiave),
    );
    final scelta = await showModalBottomSheet<String>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.mio && !m.eliminato)
              voce(
                'tutti',
                Icons.delete_outline,
                'Elimina per tutti',
                'Entro un minuto dall\'invio sparisce senza lasciare traccia; dopo resta «Messaggio eliminato».',
                rosso: true,
              ),
            voce('me', Icons.visibility_off_outlined, 'Elimina per me', 'Sparisce solo dalla tua chat.'),
            if (!m.mio && !m.eliminato)
              voce('segnala', Icons.flag_outlined, 'Segnala il messaggio', 'Lo staff legge solo i messaggi segnalati.', rosso: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (scelta == null || !mounted) return;
    try {
      switch (scelta) {
        case 'tutti':
          final sparito = await stato.api.eliminaMessaggio(m.id);
          if (!mounted) return;
          setState(() {
            if (sparito) {
              _msg.removeWhere((x) => x.id == m.id);
            } else {
              m
                ..eliminato = true
                ..testo = ''
                ..foto = null
                ..audio = null;
            }
          });
          messaggio(context, sparito ? 'Messaggio ritirato: non resta traccia.' : 'Messaggio eliminato per tutti.');
        case 'me':
          await stato.api.nascondiMessaggio(m.id);
          if (mounted) setState(() => _msg.removeWhere((x) => x.id == m.id));
        case 'segnala':
          final motivi = await stato.api.motiviMessaggio();
          if (!mounted) return;
          final motivo = await scegliMotivo(
            context,
            intestazione: 'Perché segnali il messaggio?',
            spiega: 'La segnalazione arriva allo staff entro 24 ore. Chi l\'ha scritto non lo sa.',
            motivi: motivi,
          );
          if (motivo == null || !mounted) return;
          final msg = await stato.api.segnalaMessaggio(m.id, motivo);
          if (mounted) messaggio(context, msg);
      }
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    }
  }

  Future<void> _menu() async {
    final c = _chat;
    if (c == null) return;
    final scelta = await showModalBottomSheet<String>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Vedi il profilo'),
              onTap: () => Navigator.pop(s, 'profilo'),
            ),
            if (_conv != null)
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Elimina la chat'),
                subtitle: const Text('Sparisce solo per te', style: TextStyle(color: muto, fontSize: 12.5)),
                onTap: () => Navigator.pop(s, 'cancella'),
              ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: pompeiano),
              title: Text(
                'Blocca ${c.persona.nome}',
                style: const TextStyle(color: pompeiano, fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(s, 'blocca'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (scelta == null || !mounted) return;
    switch (scelta) {
      case 'profilo':
        apriUtente(context, c.persona.username);
      case 'cancella':
        if (!await conferma(
          context,
          'Eliminare la chat?',
          'Sparisce solo per te. Se ${c.persona.nome} ti scrive ancora, la chat ricompare con i messaggi nuovi.',
        )) {
          return;
        }
        try {
          await stato.api.cancellaChat(_conv!);
          if (mounted) Navigator.pop(context);
        } on ErroreApi catch (e) {
          if (mounted) messaggio(context, e.messaggio);
        }
      case 'blocca':
        if (await bloccaPersona(context, c.persona.username, c.persona.nome) && mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _chat;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: c == null
            ? const Text('Messaggi')
            : InkWell(
                onTap: () => apriUtente(context, c.persona.username),
                child: Row(
                  children: [
                    FotoProfilo(faccia: c.persona, lato: 36),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.persona.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text('@${c.persona.username}', style: const TextStyle(color: muto, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [if (c != null) IconButton(tooltip: 'Altre azioni', icon: const Icon(Icons.more_vert), onPressed: _menu)],
      ),
      body: _errore != null && c == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_errore!, textAlign: TextAlign.center),
              ),
            )
          : c == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _flusso()),
                if (c.richiestaRicevuta) _richiesta(c),
                if (c.puoScrivere) ...[
                  if (c.avviso.isNotEmpty) _avviso(c.avviso),
                  _casella(c),
                ] else
                  SafeArea(top: false, child: _avviso(c.avviso.isEmpty ? 'Non puoi scrivere a questa persona.' : c.avviso)),
              ],
            ),
    );
  }

  /// Messaggi dal basso (il più recente in fondo), con i separatori dei giorni
  Widget _flusso() {
    if (_msg.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Scrivi il primo messaggio. Sii gentile: dall\'altra parte c\'è un vicino.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muto),
          ),
        ),
      );
    }
    final ultimoMio = _msg.last.mio ? _msg.last.id : null;
    return ListView.builder(
      controller: _scorri,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      itemCount: _msg.length + (_caricaPrima ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _msg.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final idx = _msg.length - 1 - i;
        final m = _msg[idx];
        final giornoNuovo = idx == 0 || _msg[idx - 1].giorno != m.giorno;
        return Column(
          crossAxisAlignment: m.mio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (giornoNuovo) _giorno(m.giorno),
            _bolla(m),
            if (m.id == ultimoMio)
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 4),
                child: Text(_lettoAltro >= m.id ? 'Visto' : 'Inviato', style: const TextStyle(color: muto, fontSize: 11.5)),
              ),
          ],
        );
      },
    );
  }

  Widget _giorno(String g) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(99)),
      child: Text(
        g.toUpperCase(),
        style: const TextStyle(color: muto, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .4),
      ),
    ),
  );

  Widget _bolla(Messaggio m) {
    final largo = MediaQuery.sizeOf(context).width * .78;
    final foto = assoluto(m.foto);
    return GestureDetector(
      onLongPress: () => _azioniMessaggio(m),
      child: Container(
        constraints: BoxConstraints(maxWidth: largo),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.fromLTRB(foto != null ? 4 : 12, foto != null ? 4 : 8, foto != null ? 4 : 12, 6),
        decoration: BoxDecoration(
          gradient: m.mio ? gradienteBottone : null,
          color: m.mio ? null : superficie2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(m.mio ? 18 : 6),
            bottomRight: Radius.circular(m.mio ? 6 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.eliminato)
              Text(
                'Messaggio eliminato',
                style: TextStyle(color: m.mio ? bianco.withValues(alpha: .8) : muto, fontStyle: FontStyle.italic),
              )
            else ...[
              if (foto != null)
                GestureDetector(
                  onTap: () => apriFoto(context, foto, testate: stato.api.testateFoto),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: foto,
                      httpHeaders: stato.api.testateFoto,
                      width: largo - 8,
                      height: 240,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(width: largo - 8, height: 240, color: superficie),
                      errorWidget: (_, _, _) => Container(
                        width: largo - 8,
                        height: 120,
                        color: superficie,
                        alignment: Alignment.center,
                        child: const Text('Foto non disponibile', style: TextStyle(color: muto)),
                      ),
                    ),
                  ),
                ),
              if (m.audio != null) LettoreVocale(url: m.audio!, durata: m.durata, mio: m.mio),
              if (m.testo.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(foto != null ? 8 : 0, foto != null ? 6 : 0, foto != null ? 8 : 0, 0),
                  child: SelectableText(m.testo, style: TextStyle(color: m.mio ? bianco : testo, fontSize: 15, height: 1.35)),
                ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(top: 2, right: foto != null ? 8 : 0),
                child: Text(m.ora, style: TextStyle(color: (m.mio ? bianco : testo).withValues(alpha: .65), fontSize: 10.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _richiesta(ChatAperta c) => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: terracotta.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: terracotta.withValues(alpha: .35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${c.persona.nome} vuole scriverti. ',
                style: const TextStyle(fontWeight: FontWeight.w700, color: testo),
              ),
              const TextSpan(
                text: 'Non vi seguite a vicenda: se accetti potete scrivervi e mandarvi foto. Se rifiuti non riceve nessun avviso.',
              ),
            ],
          ),
          style: const TextStyle(color: testo2, height: 1.4),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: BottoneCaldo(testo: 'Accetta', onPressed: () => _rispondi(true)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(onPressed: () => _rispondi(false), child: const Text('Rifiuta')),
            ),
          ],
        ),
        TextButton(
          onPressed: () async {
            if (await bloccaPersona(context, c.persona.username, c.persona.nome) && mounted) Navigator.pop(context);
          },
          child: Text('Blocca ${c.persona.nome}', style: const TextStyle(color: pompeiano)),
        ),
      ],
    ),
  );

  Widget _avviso(String t) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(10)),
    child: Text(t, style: const TextStyle(color: testo2, fontSize: 13, height: 1.4)),
  );

  /// Casella vuota e niente foto: al posto di «Invia» c'è il microfono (vocali solo nelle chat accettate)
  bool _microfono(ChatAperta c) => c.fotoPermesse && _foto == null && _campo.text.trim().isEmpty;

  Widget _casella(ChatAperta c) => SafeArea(
    top: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_foto != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: superficie2, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_foto!, width: 56, height: 56, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('La foto passa dal controllo automatico prima di partire.', style: TextStyle(color: muto, fontSize: 12.5)),
                ),
                IconButton(tooltip: 'Togli la foto', icon: const Icon(Icons.close), onPressed: () => setState(() => _foto = null)),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (c.fotoPermesse && !_registra)
                IconButton(tooltip: 'Manda una foto', icon: const Icon(Icons.image_outlined), onPressed: _invio ? null : _scegliFoto),
              if (_registra)
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    decoration: BoxDecoration(
                      color: superficie2,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: linea2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.fiber_manual_record, color: pompeiano, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          _mmss(_secondiReg),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Sto registrando…', style: TextStyle(color: testo2)),
                        ),
                        TextButton(onPressed: () => _fermaVocale(manda: false), child: const Text('Annulla')),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: TextField(
                    controller: _campo,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Scrivi un messaggio…',
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Material(
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: const BoxDecoration(gradient: gradienteBottone),
                  child: InkWell(
                    onTap: _invio
                        ? null
                        : _registra
                        ? () => _fermaVocale(manda: true)
                        : (_microfono(c) ? _iniziaVocale : _manda),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: _invio
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: CircularProgressIndicator(strokeWidth: 2, color: bianco),
                            )
                          : Icon(
                              _microfono(c) && !_registra ? Icons.mic_none_rounded : Icons.send_rounded,
                              color: bianco,
                              size: 22,
                              semanticLabel: _microfono(c) && !_registra ? 'Registra un vocale' : 'Invia',
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _mmss(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

/// Lettore di un messaggio vocale: tocco per ascoltare/fermare, barra e tempo. Uno solo suona alla volta.
class LettoreVocale extends StatefulWidget {
  const LettoreVocale({super.key, required this.url, required this.durata, required this.mio});

  final String url;
  final int durata;
  final bool mio;

  static _LettoreVocaleState? _attivo;
  static void fermaTutto() => _attivo?._ferma();

  @override
  State<LettoreVocale> createState() => _LettoreVocaleState();
}

class _LettoreVocaleState extends State<LettoreVocale> {
  AudioPlayer? _p;
  bool _suona = false, _carica = false;
  Duration _pos = Duration.zero;
  StreamSubscription<Duration>? _subPos;
  StreamSubscription<PlayerState>? _subStato;

  @override
  void dispose() {
    if (LettoreVocale._attivo == this) LettoreVocale._attivo = null;
    _subPos?.cancel();
    _subStato?.cancel();
    _p?.dispose();
    super.dispose();
  }

  void _ferma() {
    _p?.pause();
    if (mounted) setState(() => _suona = false);
  }

  Future<void> _tocca() async {
    if (_carica) return;
    if (_suona) {
      _ferma();
      return;
    }
    if (LettoreVocale._attivo != this) LettoreVocale._attivo?._ferma();
    LettoreVocale._attivo = this;
    try {
      if (_p == null) {
        setState(() => _carica = true);
        final f = await stato.api.scaricaVocale(widget.url);
        final p = AudioPlayer();
        await p.setFilePath(f.path);
        _p = p;
        _subPos = p.positionStream.listen((d) {
          if (mounted) setState(() => _pos = d);
        });
        _subStato = p.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed) {
            p.pause();
            p.seek(Duration.zero);
            if (mounted) setState(() => _suona = false);
          }
        });
      }
      if (!mounted) return;
      setState(() {
        _carica = false;
        _suona = true;
      });
      await _p!.play();
    } on ErroreApi catch (e) {
      if (mounted) {
        setState(() => _carica = false);
        messaggio(context, e.messaggio);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _carica = false);
        messaggio(context, 'Il vocale non si riesce ad ascoltare: riprova tra poco.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tot = (_p?.duration ?? Duration(seconds: widget.durata)).inMilliseconds;
    final quota = tot > 0 ? (_pos.inMilliseconds / tot).clamp(0.0, 1.0) : 0.0;
    final colore = widget.mio ? bianco : testo;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Material(
            color: widget.mio ? bianco : terracotta,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _tocca,
              child: SizedBox(
                width: 38,
                height: 38,
                child: _carica
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: widget.mio ? terracottaScura : bianco),
                      )
                    : Icon(
                        _suona ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: widget.mio ? terracottaScura : bianco,
                        semanticLabel: _suona ? 'Ferma il vocale' : 'Ascolta il vocale',
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: quota, minHeight: 4, color: colore, backgroundColor: colore.withValues(alpha: .25)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _mmss(_suona || _pos > Duration.zero ? _pos.inSeconds : widget.durata),
            style: TextStyle(color: colore.withValues(alpha: .85), fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}
