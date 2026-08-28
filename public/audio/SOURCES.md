# Sources audio

Les deux fichiers au rythme normal (`eole-inhale-normal.mp3` et
`eole-exhale-normal.mp3`) proviennent d'un enregistrement personnel fourni pour
Eole. Une prise naturelle de `2 s` a été sélectionnée pour chaque phase, sans
étirement temporel : inspiration `20,260–22,260 s`, expiration
`7,580–9,580 s`. Seuls un filtrage léger, des fondus courts et une normalisation
autour de `-34 LUFS` ont été appliqués.

## Rythmes lent et rapide

Les quatre sons respiratoires lent et rapide utilisés par Eole proviennent du fichier
**inhale-exhale** publié sur Pixabay par `Amber2023` :

- Page source :
  <https://pixabay.com/sound-effects/people-inhale-exhale-230173/>
- Fichier public utilisé :
  <https://cdn.pixabay.com/audio/2024/08/05/audio_5b806d63e5.mp3>
- Licence : Pixabay Content License. Elle autorise l'utilisation gratuite,
  l'adaptation et l'usage sans attribution, sous réserve de ses usages interdits,
  notamment la redistribution du contenu original sans travail créatif.
- Source reçue : MP3 stéréo 44,1 kHz de `3,631 s`, contenant une inspiration puis
  une expiration humaines.

L'inspiration (`0,12–0,88 s`) et l'expiration (`1,68–2,70 s`) ont été isolées puis
ajustées hors ligne à hauteur constante pour correspondre aux durées de `1,25 s`
et `3 s`. Les traitements restent légers :
filtrage passe-haut à 80 Hz, passe-bas à 14 kHz, homogénéisation de la dynamique,
fondus courts et normalisation autour de `-34,5 LUFS`. Les fichiers finaux sont en
MP3 mono 44,1 kHz à 96 kb/s et sont nommés
`eole-{inhale,exhale}-{fast,normal,slow}.mp3`.

## Musiques de fond

Les trois musiques sont de vraies compositions publiées sous licence Creative
Commons Zero (`CC0`) sur OpenGameArt. Elles peuvent donc être copiées, modifiées
et redistribuées, y compris commercialement :

- `eole-bambou.mp3` — **Forest Whisper Theme**, Cleyton Kauffman : flûte en bois,
  cordes et clochettes, composition annoncée comme bouclable (`1 min 22 s`).
  Source : <https://opengameart.org/content/forest-whisper-theme>
- `eole-meditation.mp3` — **First Light Particles**, Yoiyami : piano doux et
  nappes atmosphériques, sans percussion (`2 min 05 s` après bouclage).
  Source :
  <https://opengameart.org/content/first-light-particles-%E2%80%93-cc0-atmospheric-pianoambient-track>
- `eole-serenite.mp3` — **Somnium**, Adiutorium : composition lente et aérienne
  (`3 min 33 s` après bouclage).
  Source : <https://opengameart.org/content/somnium>

Les deux pistes qui n'étaient pas fournies comme boucles ont reçu un fondu croisé
de six secondes entre leur fin et leur début. Les trois fichiers sont encodés en
MP3 stéréo 44,1 kHz à `96 kb/s`, sans métadonnées personnelles.

Toutes les pistes livrées avec l'application sont rééquilibrées localement pour
éviter les écarts brusques de volume : les respirations visent `-34 LUFS` et les
musiques environ `-30 LUFS`. Mesures finales : bambou `-30,2 LUFS`, méditation
`-30,5 LUFS`, sérénité `-30,3 LUFS`; crêtes vraies inférieures à `-16 dBFS`.

La source BigSoundBank précédemment utilisée reste une référence de comparaison :
**Man Breathing**, son `#2195`, Joseph SARDIN, également sous licence CC0 :
<https://bigsoundbank.com/man-breathing-s2195.html>.
