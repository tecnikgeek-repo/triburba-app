// Icone di triburba disegnate come sul sito (stessi tratti di icon() in app/Core/helpers.php):
// contorno 1,9 con estremità arrotondate, viewBox 24×24. Così sito e app hanno le stesse icone.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _tratti = <String, String>{
  'heart': '<path d="M12 20.5s-7.5-4.6-9.3-9.2C1.5 8.1 3.6 4.5 7.2 4.5c2 0 3.6 1.1 4.8 2.8 1.2-1.7 2.8-2.8 4.8-2.8 3.6 0 5.7 3.6 4.5 6.8-1.8 4.6-9.3 9.2-9.3 9.2z"/>',
  'comment': '<path d="M21 12a8.5 8.5 0 0 1-12.4 7.6L3 21l1.4-5.1A8.5 8.5 0 1 1 21 12z"/>',
  'share': '<path d="M4 12v7a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-7"/><path d="m16 6-4-4-4 4"/><path d="M12 2v13"/>',
  'tamtam': '<ellipse cx="12" cy="9" rx="6" ry="2.3"/><path d="M6 9l1.3 8.6c.3 1.4 2.2 2.4 4.7 2.4s4.4-1 4.7-2.4L18 9"/>'
      '<path d="M8.6 11.4 12 19.6M15.4 11.4 12 19.6"/><path d="M4 5.5a4 4 0 0 0 0 6M20 5.5a4 4 0 0 1 0 6M2 3.5a7 7 0 0 0 0 10M22 3.5a7 7 0 0 1 0 10"/>',
};

class IconaTk extends StatelessWidget {
  const IconaTk(this.nome, {super.key, this.lato = 22, required this.colore});

  final String nome;
  final double lato;
  final Color colore;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.9" '
    'stroke-linecap="round" stroke-linejoin="round">${_tratti[nome] ?? ''}</svg>',
    width: lato,
    height: lato,
    colorFilter: ColorFilter.mode(colore, BlendMode.srcIn),
  );
}
