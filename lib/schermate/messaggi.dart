// Messaggi privati: elenco delle chat e delle richieste, e la chat con una persona.
// Stesse regole del sito (le decide il server): chat libera tra chi si segue a vicenda e tra residenti dello stesso
// quartiere, altrimenti richiesta; tra adulti e minorenni solo se ci si segue a vicenda; foto e testi filtrati.
import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
    _apri();
  }

  @override
  void dispose() {
    _giro?.cancel();
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
      if (nuovi.isEmpty && n.lettoAltro == _lettoAltro) return;
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
    if (m.eliminato) return;
    final scelta = await showModalBottomSheet<String>(
      context: context,
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.mio)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: pompeiano),
                title: const Text(
                  'Elimina per tutti',
                  style: TextStyle(color: pompeiano, fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(s, 'elimina'),
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: pompeiano),
                title: const Text(
                  'Segnala il messaggio',
                  style: TextStyle(color: pompeiano, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Lo staff legge solo i messaggi segnalati', style: TextStyle(color: muto, fontSize: 12.5)),
                onTap: () => Navigator.pop(s, 'segnala'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (scelta == null || !mounted) return;
    try {
      if (scelta == 'elimina') {
        if (!await conferma(context, 'Eliminare il messaggio?', 'Sparisce per tutti e due.')) return;
        await stato.api.eliminaMessaggio(m.id);
        if (mounted) {
          setState(() {
            m.eliminato = true;
            m.testo = '';
            m.foto = null;
          });
        }
      } else {
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
              if (c.fotoPermesse)
                IconButton(tooltip: 'Manda una foto', icon: const Icon(Icons.image_outlined), onPressed: _invio ? null : _scegliFoto),
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
                    onTap: _invio ? null : _manda,
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: _invio
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: CircularProgressIndicator(strokeWidth: 2, color: bianco),
                            )
                          : const Icon(Icons.send_rounded, color: bianco, size: 22),
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
