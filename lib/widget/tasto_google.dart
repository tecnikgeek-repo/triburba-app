// «Continua con Google» (solo Android: su iPhone servirebbe anche «Accedi con Apple», linea guida 4.8).
// Il telefono chiede a Google un id_token per il client web di triburba; il server lo verifica e fa entrare
// oppure manda all'ultimo passo dell'iscrizione (quartiere, data di nascita, consenso).
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../dati/api.dart';
import '../dati/push.dart';
import '../dati/stato.dart';
import '../schermate/accesso.dart';
import '../tema.dart';

const _logo =
    '<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg"><path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"/><path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z"/></svg>';

Widget logoGoogle([double misura = 20]) => SvgPicture.string(_logo, width: misura, height: misura);

/// Il client web lo chiediamo al server una volta sola per avvio dell'app.
Future<String?>? _client;
bool _pronto = false;

class TastoGoogle extends StatefulWidget {
  const TastoGoogle({super.key, this.oppure = true});

  /// Mostra sotto la riga «oppure con la tua email».
  final bool oppure;

  @override
  State<TastoGoogle> createState() => _TastoGoogleState();
}

class _TastoGoogleState extends State<TastoGoogle> {
  String? _id;
  bool _occupato = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !Platform.isAndroid) return;
    _client ??= stato.api.clientGoogle().catchError((Object _) {
      _client = null; // al prossimo tentativo si richiede
      return null;
    });
    _client!.then((id) {
      if (mounted && id != null) setState(() => _id = id);
    });
  }

  Future<void> _entra() async {
    final id = _id;
    if (id == null || _occupato) return;
    setState(() => _occupato = true);
    try {
      final g = GoogleSignIn.instance;
      if (!_pronto) {
        await g.initialize(serverClientId: id);
        _pronto = true;
      }
      final account = await g.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError);
      final r = await stato.api.accediGoogle(token);
      // la prossima volta Google richiede quale account usare
      g.signOut().catchError((Object _) {});
      if (!mounted) return;
      if (r.io != null) {
        stato.entra(r.io!);
        collegaPush();
        Navigator.of(context).popUntil((x) => x.isFirst);
      } else {
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => SchermataIscrizione(google: (biglietto: r.biglietto!, proposta: r.proposta!))));
      }
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        messaggio(context, 'Google non ha risposto: riprova tra poco oppure entra con email e password.');
      }
    } on ErroreApi catch (e) {
      if (mounted) messaggio(context, e.messaggio);
    } catch (_) {
      if (mounted) messaggio(context, 'Google non ha risposto: riprova tra poco oppure entra con email e password.');
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_id == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // colori e forma come chiede Google per il tasto scuro
        Material(
          color: const Color(0xFF131314),
          shape: const StadiumBorder(side: BorderSide(color: Color(0xFF8E918F))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _occupato ? null : _entra,
            child: SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_occupato)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFFE3E3E3)))
                  else
                    logoGoogle(),
                  const SizedBox(width: 12),
                  const Text(
                    'Continua con Google',
                    style: TextStyle(color: Color(0xFFE3E3E3), fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.oppure)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('oppure con la tua email', style: TextStyle(color: muto, fontSize: 13)),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
      ],
    );
  }
}
