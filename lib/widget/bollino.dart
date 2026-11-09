// Bollino tondo col numero sopra un'icona (commenti, condivisioni), come sul sito:
// sfumatura calda, numero bianco corto (999, 1k, 12k, 1M), piccolo «pop» quando sale.
import 'package:flutter/material.dart';

import '../tema.dart';

/// 999 → «999», 1000 → «1k», 12500 → «12k», 1200000 → «1M»
String numeroBreve(int n) => n < 1000 ? '$n' : (n < 1000000 ? '${n ~/ 1000}k' : '${n ~/ 1000000}M');

class IconaConBollino extends StatefulWidget {
  const IconaConBollino({super.key, required this.icona, required this.n, this.bordo = superficie});

  final Widget icona;
  final int n;

  /// Colore dell'anello intorno al bollino: quello del fondo della card.
  final Color bordo;

  @override
  State<IconaConBollino> createState() => _IconaConBollinoState();
}

class _IconaConBollinoState extends State<IconaConBollino> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final Animation<double> _scala = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.4, end: .92).chain(CurveTween(curve: Curves.easeInOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: .92, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
  ]).animate(_c);

  @override
  void didUpdateWidget(IconaConBollino vecchio) {
    super.didUpdateWidget(vecchio);
    if (widget.n > vecchio.n) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.n > 0 ? numeroBreve(widget.n) : '';
    final lato = t.length >= 3 ? 22.0 : 20.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.icona,
        if (t.isNotEmpty)
          Positioned(
            top: -9,
            right: -13,
            child: ScaleTransition(
              scale: _scala,
              child: Container(
                width: lato,
                height: lato,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [terracottaScura, terracotta, oro],
                  ),
                  border: Border.all(color: widget.bordo, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x4DE0663A), blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Text(
                  t,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: fontTesto,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -.3,
                    fontSize: t.length >= 3 ? 8 : (t.length == 2 ? 9.5 : 10.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
