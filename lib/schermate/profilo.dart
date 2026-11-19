// Modifica del proprio profilo e impostazioni (regole, privacy, informazioni, esci, elimina account).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'bloccati.dart';
import '../dati/api.dart';
import '../dati/push.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import '../widget/nascita.dart';
import '../widget/ritaglio.dart';
import '../widget/scelta_tema.dart';
import 'admin.dart';
import 'legale.dart';
import 'preferenze_notifiche.dart';

class SchermataModificaProfilo extends StatefulWidget {
  const SchermataModificaProfilo({super.key, this.campo = ''});

  /// Campo da completare (da «Completa il tuo profilo» o dal promemoria): avatar, cover, bio, occupation.
  final String campo;

  @override
  State<SchermataModificaProfilo> createState() => _SchermataModificaProfiloState();
}

class _SchermataModificaProfiloState extends State<SchermataModificaProfilo> {
  late final _nome = TextEditingController(text: stato.io?.nome);
  late final _bio = TextEditingController(text: stato.io?.bio);
  late final _lavoro = TextEditingController(text: stato.io?.lavoro);
  late final _luogo = TextEditingController(text: stato.io?.luogo);
  late final _sito = TextEditingController(text: stato.io?.sitoWeb);
  late DateTime? _nascita = daIso(stato.io?.dataNascita);
  late bool _pubblico = stato.io?.compleannoPubblico ?? false;
  bool _salvo = false;
  bool _foto = false;

  /// Copertina appena ritagliata: si vede subito, col velo di caricamento, finché il server non risponde
  File? _copertinaNuova;
  final _fuocoBio = FocusNode();
  final _fuocoLavoro = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.campo == 'bio') _fuocoBio.requestFocus();
      if (widget.campo == 'occupation') _fuocoLavoro.requestFocus();
    });
  }

  /// Il pezzo che manca si accende con un bordo caldo.
  Widget _copertina(String? percorso) {
    final url = assoluto(percorso);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _foto ? null : _cambiaCopertina,
        child: AspectRatio(
          aspectRatio: proporzioneCopertina,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_copertinaNuova != null)
                Image.file(_copertinaNuova!, fit: BoxFit.cover)
              else if (url != null)
                CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
              else
                DecoratedBox(decoration: BoxDecoration(gradient: gradiente)),
              if (_copertinaNuova != null && _foto) const VeloCaricamento(),
              if (url == null && _copertinaNuova == null)
                const Center(
                  child: Text('Nessuna copertina', style: TextStyle(color: bianco, fontWeight: FontWeight.w700)),
                ),
              if (!(_foto && _copertinaNuova != null))
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xCC120D0B), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _foto
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: bianco))
                          : const Icon(Icons.photo_camera_outlined, color: bianco, size: 18),
                      const SizedBox(width: 8),
                      Text(url == null ? 'Aggiungi copertina' : 'Cambia copertina',
                          style: const TextStyle(color: bianco, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _evidenzia(String campo, Widget figlio) => widget.campo != campo
      ? figlio
      : Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: terracotta, width: 2)),
          child: figlio,
        );

  @override
  void dispose() {
    for (final c in [_nome, _bio, _lavoro, _luogo, _sito]) {
      c.dispose();
    }
    _fuocoBio.dispose();
    _fuocoLavoro.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    setState(() => _salvo = true);
    try {
      final io = await stato.api.salvaProfilo({
        'nome': _nome.text.trim(),
        'bio': _bio.text.trim(),
        'lavoro': _lavoro.text.trim(),
        'luogo': _luogo.text.trim(),
        'sito': _sito.text.trim(),
        if (_nascita != null) 'data_nascita': dataIso(_nascita)!,
        if (_nascita != null) 'compleanno_pubblico': _pubblico ? '1' : '0',
      });
      stato.entra(io);
      if (mounted) {
        messaggio(context, 'Profilo aggiornato.');
        Navigator.pop(context);
      }
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _salvo = false);
    }
  }

  /// Copertina: galleria o fotocamera, poi ritaglio 3:1 (quello che si vede è quello che esce sul profilo)
  Future<void> _cambiaCopertina() async {
    final f = await scegliCopertina(context, attuale: assoluto(stato.io?.copertina));
    if (f == null || !mounted) return;
    // la nuova si vede subito col velo; dopo il salvataggio resta quella locale (uguale), così niente lampo vuoto
    setState(() {
      _foto = true;
      _copertinaNuova = f;
    });
    try {
      stato.entra(await stato.api.cambiaFoto(f, copertina: true));
      if (mounted) messaggio(context, 'Copertina aggiornata.');
    } on ErroreApi catch (e) {
      if (mounted) {
        setState(() => _copertinaNuova = null);
        messaggio(context, e.messaggio);
      }
    } finally {
      if (mounted) setState(() => _foto = false);
    }
  }

  Future<void> _cambiaFoto({bool copertina = false}) async {
    if (copertina) return _cambiaCopertina();
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: copertina ? 2000 : 900,
      maxHeight: copertina ? 2000 : 900,
      imageQuality: 88,
    );
    if (x == null) return;
    setState(() => _foto = true);
    try {
      stato.entra(await stato.api.cambiaFoto(File(x.path), copertina: copertina));
      if (mounted) messaggio(context, copertina ? 'Copertina aggiornata.' : 'Foto aggiornata.');
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } finally {
      if (mounted) setState(() => _foto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final io = stato.io!;
    return Scaffold(
      appBar: AppBar(title: const Text('Modifica profilo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.campo == 'avatar' || widget.campo == 'cover')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.campo == 'avatar'
                    ? 'Metti una foto: i vicini ti riconoscono e si fidano di più a garantire per te.'
                    : 'Scegli una copertina: è la prima cosa che vede chi apre il tuo profilo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: testo2, height: 1.4),
              ),
            ),
          Center(
            child: _evidenzia('avatar', Stack(
              children: [
                FotoProfilo(faccia: io.faccia, lato: 96, anello: true),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: terracotta),
                    onPressed: _foto ? null : () => _cambiaFoto(),
                    icon: _foto
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: bianco))
                        : const Icon(Icons.photo_camera_outlined, color: bianco),
                    tooltip: 'Cambia foto',
                  ),
                ),
              ],
            )),
          ),
          const SizedBox(height: 16),
          // la copertina com'è sul profilo (3:1), tutta toccabile, con il tasto ben visibile
          _evidenzia('cover', _copertina(io.copertina)),
          const SizedBox(height: 12),
          TextField(
            controller: _nome,
            maxLength: 64,
            decoration: const InputDecoration(labelText: 'Nome e cognome'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            focusNode: _fuocoBio,
            maxLength: 240,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Due righe su di te'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lavoro,
            focusNode: _fuocoLavoro,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Lavoro'),
          ),
          const SizedBox(height: 8),
          CampoNascita(valore: _nascita, aiuto: 'Privata: non la vede nessuno', onCambia: (d) => setState(() => _nascita = d)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pubblico,
            onChanged: _nascita == null ? null : (v) => setState(() => _pubblico = v),
            title: const Text('Fai sapere ai vicini quando è il mio compleanno', style: TextStyle(fontSize: 14.5)),
            subtitle: const Text('Solo giorno e mese, mai l\'anno: quel giorno possono farti gli auguri', style: TextStyle(fontSize: 12.5)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _luogo,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Dove vivi'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sito,
            maxLength: 190,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Sito o pagina social'),
          ),
          const SizedBox(height: 12),
          BottoneCaldo(testo: 'Salva', occupato: _salvo, onPressed: _salva),
          const SizedBox(height: 14),
          Text(
            'Username, email e password si cambiano da Impostazioni → Account.',
            style: TextStyle(color: muto, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class SchermataImpostazioni extends StatelessWidget {
  const SchermataImpostazioni({super.key});


  Future<void> _esci(BuildContext context) async {
    if (!await conferma(
      context,
      'Vuoi uscire?',
      'Su questo telefono non riceverai più le notifiche finché non rientri.',
      si: 'Esci',
      pericolo: false,
    )) {
      return;
    }
    await scollegaPush();
    await stato.esci();
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _elimina(BuildContext context) async {
    final pw = await chiediTesto(context, 'Elimina l\'account', suggerimento: 'La tua password', ok: 'Elimina per sempre', password: true);
    if (pw == null || pw.isEmpty || !context.mounted) return;
    if (!await conferma(
      context,
      'Sei sicuro?',
      'Spariscono per sempre il profilo, tutti i tuoi post, commenti, reazioni e foto. Non si può annullare.',
    )) {
      return;
    }
    try {
      await stato.api.eliminaAccount(pw);
      await scollegaPush();
      await stato.esci();
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on ErroreApi catch (e) {
      if (context.mounted) messaggio(context, e.messaggio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final io = stato.io;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: [
          if (io != null)
            ListTile(
              leading: FotoProfilo(faccia: io.faccia, lato: 44),
              title: Text(io.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('@${io.username} · ${io.email}', style: TextStyle(color: muto)),
            ),
          const Divider(),
          _sezione('Aspetto'),
          ListTile(
            leading: Icon(Icons.palette_outlined, color: terracotta),
            title: const Text('Tema'),
            subtitle: Text('${tinta.nome} · ${tinta.scura ? 'scuro' : 'chiaro'}', style: TextStyle(color: muto)),
            trailing: Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => apriSceltaTema(context),
          ),
          _sezione('Notifiche'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Scegli cosa ricevere'),
            subtitle: Text('Commenti, reazioni, menzioni… in app e sul telefono', style: TextStyle(color: muto)),
            trailing: Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataPreferenzeNotifiche())),
          ),
          _sezione('Account'),
          ListTile(
            leading: const Icon(Icons.alternate_email_rounded),
            title: const Text('Username'),
            subtitle: Text(io != null ? '@${io.username}' : '', style: TextStyle(color: muto)),
            trailing: Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => cambiaUsername(context),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('Email'),
            subtitle: Text(io?.email ?? '', style: TextStyle(color: muto)),
            trailing: Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => cambiaEmail(context),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Password'),
            subtitle: Text('Cambiala quando vuoi', style: TextStyle(color: muto)),
            trailing: Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => cambiaPassword(context),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: const Text('Persone bloccate'),
            subtitle: Text('Chi hai bloccato non vede i tuoi post e tu non vedi i suoi', style: TextStyle(color: muto)),
            trailing: Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataBloccati())),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Scarica i miei dati'),
            subtitle: Text('Un file con profilo, post, commenti e attività', style: TextStyle(color: muto)),
            trailing: Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => scaricaDati(context),
          ),
          if (io?.admin == true)
            ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined, color: oro),
              title: const Text('Pannello admin'),
              subtitle: Text('Gestione, statistiche, iscritti, visite e registro', style: TextStyle(color: muto)),
              trailing: Icon(Icons.chevron_right_rounded, color: muto),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataAdmin())),
            ),
          _sezione('Regole e privacy'),
          ListTile(leading: const Icon(Icons.gavel_rounded), title: const Text('Regolamento'), onTap: () => apriLegale(context, 'regolamento')),
          ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Termini'), onTap: () => apriLegale(context, 'termini')),
          ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy'), onTap: () => apriLegale(context, 'privacy')),
          ListTile(leading: const Icon(Icons.cookie_outlined), title: const Text('Cookie'), onTap: () => apriLegale(context, 'cookie')),
          _sezione('App'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Informazioni'),
            subtitle: Text('Versione, licenza, codice sorgente', style: TextStyle(color: muto)),
            onTap: () => apriInformazioni(
              context,
              notaDati: 'Sul telefono restano solo il tuo accesso e le preferenze; i post stanno su triburba.it.',
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Esci', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => _esci(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: pompeiano),
            title: const Text(
              'Elimina l\'account',
              style: TextStyle(color: pompeiano, fontWeight: FontWeight.w700),
            ),
            subtitle: Text('Cancella per sempre profilo, post e dati', style: TextStyle(color: muto)),
            onTap: () => _elimina(context),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _sezione(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
    ),
  );
}


// ── Account: username, email, password e dati, tutto dentro l'app ──

/// Piccolo modulo a più campi in una finestra; ritorna i valori scritti oppure null se annullato.
Future<List<String>?> _modulo(
  BuildContext context,
  String titolo,
  List<({String etichetta, bool password, String iniziale, TextInputType tipo})> campi, {
  String ok = 'Salva',
  String? nota,
}) {
  final cc = [for (final c in campi) TextEditingController(text: c.iniziale)];
  final vedi = List<bool>.filled(campi.length, false);
  return showDialog<List<String>>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, aggiorna) => AlertDialog(
      title: Text(titolo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nota != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(nota, style: TextStyle(color: muto, height: 1.4))),
            for (var i = 0; i < campi.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: cc[i],
                  obscureText: campi[i].password && !vedi[i],
                  keyboardType: campi[i].tipo,
                  autocorrect: false,
                  enableSuggestions: !campi[i].password,
                  autofocus: i == 0,
                  decoration: InputDecoration(
                    labelText: campi[i].etichetta,
                    suffixIcon: campi[i].password
                        ? IconButton(
                            onPressed: () => aggiorna(() => vedi[i] = !vedi[i]),
                            icon: Icon(vedi[i] ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            tooltip: vedi[i] ? 'Nascondi la password' : 'Mostra la password',
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, [for (final x in cc) x.text]), child: Text(ok)),
      ],
    )),
  );
}

Future<void> cambiaUsername(BuildContext context) async {
  final v = await _modulo(context, 'Cambia username', [
    (etichetta: 'Nuovo username', password: false, iniziale: stato.io?.username ?? '', tipo: TextInputType.text),
  ], nota: 'Da 3 a 32 caratteri: lettere, numeri, punto e trattino basso. Il vecchio @nome non porterà più al tuo profilo.');
  if (v == null || !context.mounted) return;
  try {
    final (io, msg) = await stato.api.cambiaUsername(v[0].trim());
    stato.entra(io);
    if (context.mounted) messaggio(context, msg);
  } on ErroreApi catch (e) {
    if (context.mounted) messaggio(context, e.messaggio);
  }
}

Future<void> cambiaEmail(BuildContext context) async {
  final v = await _modulo(context, 'Cambia email', [
    (etichetta: 'Nuova email', password: false, iniziale: stato.io?.email ?? '', tipo: TextInputType.emailAddress),
    (etichetta: 'La tua password', password: true, iniziale: '', tipo: TextInputType.visiblePassword),
  ], nota: 'Per sicurezza serve la password. Con la nuova email potrai entrare al posto della vecchia.');
  if (v == null || !context.mounted) return;
  try {
    final (io, msg) = await stato.api.cambiaEmail(v[0].trim(), v[1]);
    stato.entra(io);
    if (context.mounted) messaggio(context, msg);
  } on ErroreApi catch (e) {
    if (context.mounted) messaggio(context, e.messaggio);
  }
}

Future<void> cambiaPassword(BuildContext context) async {
  final v = await _modulo(context, 'Cambia password', [
    (etichetta: 'Password attuale', password: true, iniziale: '', tipo: TextInputType.visiblePassword),
    (etichetta: 'Nuova password (almeno 8 caratteri)', password: true, iniziale: '', tipo: TextInputType.visiblePassword),
    (etichetta: 'Ripeti la nuova password', password: true, iniziale: '', tipo: TextInputType.visiblePassword),
  ]);
  if (v == null || !context.mounted) return;
  try {
    final msg = await stato.api.cambiaPassword(v[0], v[1], v[2]);
    if (context.mounted) messaggio(context, msg);
  } on ErroreApi catch (e) {
    if (context.mounted) messaggio(context, e.messaggio);
  }
}

/// I miei dati: il file arriva da triburba e si salva o si condivide con le app del telefono.
Future<void> scaricaDati(BuildContext context) async {
  messaggio(context, 'Preparo il file con i tuoi dati…');
  try {
    final (nome, dati) = await stato.api.scaricaDati();
    final byte = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(dati)));
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(byte, mimeType: 'application/json', name: nome)],
      fileNameOverrides: [nome],
      title: 'I miei dati di triburba',
    ));
  } on ErroreApi catch (e) {
    if (context.mounted) messaggio(context, e.messaggio);
  } catch (_) {
    if (context.mounted) messaggio(context, 'Non sono riuscito a preparare il file: riprova.');
  }
}
