# Prompt Gemini (Nano Banana 2) — HÉROS pour rig 2D

**But** : générer un mecha héros peint par Gemini, dans une **pose découpable** (membres séparés),
pour que je le découpe en morceaux (torse, 2 bras, 2 jambes, tête, arme) et monte un **squelette 2D**
animé (marche, visée 360°, recul de tir) en Godot.

## Mode d'emploi
1. Génère l'image en **1:1 (1024² ou +)** dans Nano Banana 2.
2. Dépose le PNG dans `mecha-forge/refs/hero_gemini/hero1.png`.
3. Je découpe les morceaux + je rig + je te montre une marche/visée en jeu.

---

## LE PROMPT (à copier-coller)

> Mecha héros bipède de jeu vidéo, **vue de dessus 3/4 (caméra ~55° au-dessus de l'horizon)**,
> style sci-fi stylisé-réaliste peint à la main (pas photoréaliste), armure bleu-acier brossée avec
> liserés cyan, **cœur réacteur cyan lumineux au centre du torse**, proportions héroïques et lisibles.
>
> **POSE (crucial) : debout, symétrique, membres BIEN ÉCARTÉS et NON superposés** — bras droit tendu
> vers l'avant tenant un canon-blaster, **bras gauche écarté du corps** (coude sorti, espace net entre
> le bras et le torse), **jambes écartées à largeur d'épaules** avec un espace clair entre les deux et
> avec le torse, **tête bien dégagée au-dessus des épaules**. Chaque membre doit être **détachable
> visuellement** (petits espaces de fond visibles entre torse, bras, jambes, tête).
>
> UN SEUL personnage centré et isolé, **sur un fond UNI plat d'une seule couleur nette bien
> contrastée** (ni dégradé, ni sol, ni ombre portée sur le fond, ni décor), corps entier visible,
> pas de texte, haute définition, cohérent avec un jeu de mecha survivor sombre.

---

## Astuces qualité (si le 1er jet colle mal)
- Si les bras/jambes se **touchent** → ajoute *« membres nettement séparés, espaces de fond visibles
  entre chaque partie, comme un model-sheet pour rigging »*.
- Si trop **photoréaliste** → *« style jeu vidéo peint à la main, cel-shaded léger, pas photo »*.
- Si tu veux tester **plusieurs designs** → change juste la couleur/silhouette (« armure rouge-orange
  agressive », « mecha fin et rapide », « lourd et massif ») et garde le reste du prompt.
- Fond conseillé : **gris moyen uni** ou **magenta uni** (les deux se détourent bien).

## (Optionnel) 2e image utile pour le rig
Une **vue de FACE bien à plat** (moins 3/4) du même héros aide à découper les bras/jambes plus
proprement. Si tu veux, génère aussi `hero1_face.png` avec *« vue de face à plat, membres écartés »*.
Sinon la 3/4 seule suffit pour le prototype.
