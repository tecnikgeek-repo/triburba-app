// Modifica del proprio profilo e impostazioni (regole, privacy, informazioni, esci, elimina account).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../dati/api.dart';
import '../dati/push.dart';
import '../dati/stato.dart';
import '../tema.dart';
import '../widget/faccia.dart';
import 'admin.dart';
import 'legale.dart';
import 'preferenze_notifiche.dart';

class SchermataModificaProfilo extends StatefulWidget {
  const SchermataModificaProfilo({super.key});

  @override
  State<SchermataModificaProfilo> createState() => _SchermataModificaProfiloState();
}

class _SchermataModificaProfiloState extends State<SchermataModificaProfilo> {
  late final _nome = TextEditingController(text: stato.io?.nome);
  late final _bio = TextEditingController(text: stato.io?.bio);
  late final _lavoro = TextEditingController(text: stato.io?.lavoro);
  late final _luogo = TextEditingController(text: stato.io?.luogo);
  late final _sito = TextEditingController(text: stato.io?.sitoWeb);
  bool _salvo = false;
  bool _foto = false;

  @override
  void dispose() {
    for (final c in [_nome, _bio, _lavoro, _luogo, _sito]) {
      c.dispose();
    }
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

  Future<void> _cambiaFoto({bool copertina = false}) async {
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
          Center(
            child: Stack(
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
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _foto ? null : () => _cambiaFoto(copertina: true),
              icon: const Icon(Icons.wallpaper_outlined),
              label: const Text('Cambia copertina'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nome,
            maxLength: 64,
            decoration: const InputDecoration(labelText: 'Nome e cognome'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bio,
            maxLength: 240,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Due righe su di te'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lavoro,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Lavoro'),
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
          const Text(
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
              subtitle: Text('@${io.username} · ${io.email}', style: const TextStyle(color: muto)),
            ),
          const Divider(),
          _sezione('Notifiche'),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Scegli cosa ricevere'),
            subtitle: const Text('Commenti, reazioni, menzioni… in app e sul telefono', style: TextStyle(color: muto)),
            trailing: const Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SchermataPreferenzeNotifiche())),
          ),
          _sezione('Account'),
          ListTile(
            leading: const Icon(Icons.alternate_email_rounded),
            title: const Text('Username'),
            subtitle: Text(io != null ? '@${io.username}' : '', style: const TextStyle(color: muto)),
            trailing: const Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => cambiaUsername(context),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('Email'),
            subtitle: Text(io?.email ?? '', style: const TextStyle(color: muto)),
            trailing: const Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => cambiaEmail(context),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Password'),
            subtitle: const Text('Cambiala quando vuoi', style: TextStyle(color: muto)),
            trailing: const Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => cambiaPassword(context),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Scarica i miei dati'),
            subtitle: const Text('Un file con profilo, post, commenti e attività', style: TextStyle(color: muto)),
            trailing: const Icon(Icons.chevron_right_rounded, color: muto),
            onTap: () => scaricaDati(context),
          ),
          if (io?.admin == true)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined, color: oro),
              title: const Text('Pannello admin'),
              subtitle: const Text('Gestione, statistiche, iscritti, visite e registro', style: TextStyle(color: muto)),
              trailing: const Icon(Icons.chevron_right_rounded, color: muto),
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
            subtitle: const Text('Versione, licenza, codice sorgente', style: TextStyle(color: muto)),
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
            subtitle: const Text('Cancella per sempre profilo, post e dati', style: TextStyle(color: muto)),
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
      style: const TextStyle(color: muto, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6),
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
  return showDialog<List<String>>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titolo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nota != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(nota, style: const TextStyle(color: muto, height: 1.4))),
            for (var i = 0; i < campi.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: cc[i],
                  obscureText: campi[i].password,
                  keyboardType: campi[i].tipo,
                  autocorrect: false,
                  enableSuggestions: !campi[i].password,
                  autofocus: i == 0,
                  decoration: InputDecoration(labelText: campi[i].etichetta),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annulla')),
        FilledButton(onPressed: () => Navigator.pop(c, [for (final x in cc) x.text]), child: Text(ok)),
      ],
    ),
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
