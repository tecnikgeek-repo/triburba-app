# triburba

**Ogni quartiere una voce, insieme una città.**

L'app per Android e iPhone di [triburba.it](https://triburba.it), il social dei quartieri di Napoli e dell'area metropolitana.
*Tribus + urbs*: la tribù della città.

- **La tua tribù**: scegli il quartiere dove abiti; due vicini già confermati garantiscono per te e puoi scrivere.
- **Feed come sul sito**: Per te, Quartiere, Municipalità, Napoli, Area metropolitana, Persone.
- **Tam-tam**: fai girare un post agli altri quartieri o rilancialo a tutta Napoli; arriva quando lo rilanciano residenti di quartieri diversi.
- **Mappa delle tribù**: le forme vere dei quartieri accesi; i comuni si accendono quando li chiede abbastanza gente.
- **Reazioni animate**, commenti con risposte, menzioni (`@nome`, `@tribu`), testo in grassetto e a colori, foto con controllo automatico.
- **Notifiche push istantanee** per commenti, reazioni, menzioni, garanzie e tam-tam.
- Elimina l'account dall'app quando vuoi, con tutti i tuoi dati.

## Compilare

Flutter 3.47.8 (Dart ^3.13.4):

```sh
flutter pub get
flutter test
flutter build apk --release
```

Le notifiche push istantanee usano Firebase: senza `android/app/google-services.json` (non incluso nel repository)
l'app funziona lo stesso e le notifiche restano nella scheda Notifiche.

## Licenza

Software libero: [GNU AGPL-3.0](COPYING) © 2026 Pietro De Filippis (TecnikGeek).
Il nome «triburba» e il logo non sono coperti dalla licenza.
Caratteri Inter e Bricolage Grotesque (SIL Open Font License, in `assets/font/`), emoji animate Noto (Apache 2.0).
