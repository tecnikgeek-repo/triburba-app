// Foto profilo (o iniziali sulla sfumatura, come sul sito), nome con stemma della tribù.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../dati/api.dart';
import '../dati/modelli.dart';
import '../tema.dart';

class FotoProfilo extends StatelessWidget {
  const FotoProfilo({super.key, required this.faccia, this.lato = 42, this.anello = false});

  /// Costruttore per i commenti dell'API del sito (avatar = indirizzo o SVG in data URI).
  FotoProfilo.da({super.key, required String nome, String? avatar, this.lato = 34, this.anello = false})
    : faccia = Faccia({'nome': nome, 'username': nome, 'foto': (avatar != null && avatar.startsWith('data:')) ? null : avatar});

  final Faccia faccia;
  final double lato;
  final bool anello;

  List<Color> get _colori {
    if (faccia.colori.length == 2) return [colore(faccia.colori[0]), colore(faccia.colori[1])];
    const tutti = [
      [Color(0xFFE0663A), Color(0xFFF0B34A)],
      [Color(0xFF1AA39A), Color(0xFF2B6CB0)],
      [Color(0xFFEF4B3F), Color(0xFFE0663A)],
      [Color(0xFF7B4BD6), Color(0xFFE0663A)],
      [Color(0xFF138A82), Color(0xFFF0B34A)],
      [Color(0xFFC2410C), Color(0xFFE0663A)],
    ];
    return tutti[faccia.nome.toLowerCase().hashCode.abs() % tutti.length];
  }

  String get _iniziali {
    if (faccia.iniziali != '?' && faccia.colori.length == 2) return faccia.iniziali;
    final p = faccia.nome.trim().split(RegExp(r'[\s._-]+')).where((w) => w.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first.characters.first + (p.length > 1 ? p.last.characters.first : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = assoluto(faccia.foto);
    final dentro = url != null
        ? CachedNetworkImage(
            imageUrl: url,
            width: lato,
            height: lato,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 150),
            errorWidget: (_, _, _) => _sfumatura(),
            placeholder: (_, _) => Container(color: superficie2),
          )
        : _sfumatura();
    return Container(
      width: lato + (anello ? 5 : 0),
      height: lato + (anello ? 5 : 0),
      padding: EdgeInsets.all(anello ? 2.5 : 0),
      decoration: anello ? const BoxDecoration(shape: BoxShape.circle, gradient: gradiente) : null,
      child: ClipOval(
        child: SizedBox(width: lato, height: lato, child: dentro),
      ),
    );
  }

  Widget _sfumatura() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _colori),
    ),
    alignment: Alignment.center,
    child: Text(
      _iniziali,
      style: TextStyle(color: bianco, fontWeight: FontWeight.w700, fontSize: lato * (_iniziali.length > 1 ? .4 : .46)),
    ),
  );
}

/// Piccolo stemma della tribù accanto al nome (sbiadito se la residenza è in attesa).
class StemmaMini extends StatelessWidget {
  const StemmaMini({super.key, required this.stemma, this.altezza = 16});

  final Stemma? stemma;
  final double altezza;

  @override
  Widget build(BuildContext context) {
    final s = stemma;
    if (s == null || s.url.isEmpty) return const SizedBox.shrink();
    return Tooltip(
      message: s.attesa ? 'In attesa di conferma a ${s.nome}' : 'Tribù di ${s.nome}',
      child: Opacity(
        opacity: s.attesa ? .45 : 1,
        child: SvgPicture.network(
          assoluto(s.url)!,
          height: altezza,
          width: altezza * 100 / 120,
          placeholderBuilder: (_) => SizedBox(height: altezza, width: altezza * 100 / 120),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Etichetta «prova» dei profili di prova.
class PillaProva extends StatelessWidget {
  const PillaProva({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: oro.withValues(alpha: .18), borderRadius: BorderRadius.circular(5)),
    child: const Text(
      'PROVA',
      style: TextStyle(color: oro, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .5),
    ),
  );
}
