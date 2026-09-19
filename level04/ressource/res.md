# Level04

> Objectif : faire exécuter `getflag` avec l'identité de `flag04` pour récupérer
> le token (= mot de passe de `level05`). Ici, pas de binaire compilé : le home
> contient un **script Perl** lisible.

---

## Résumé en une phrase

Le home de `level04` contient `level04.pl`, un script Perl **setuid `flag04`**
servi par un petit serveur web (port 4747). Ce script prend un paramètre HTTP et
le colle **sans aucun filtrage** dans une commande shell. On y **injecte** donc
notre propre commande (`getflag`), qui s'exécute alors en `flag04`. C'est une
**injection de commande** (*command injection*).

---

## Reconnaissance

```bash
ls -la
```

```
-rwsr-sr-x  1 flag04  level04  152 Mar  5  2016 level04.pl
```

- **`.pl`** = script Perl → c'est du code, lisible (les `others` ont `r-x`).
- **`s`** dans `rws` = bit **setuid**, propriétaire **`flag04`** → le script
  s'exécute avec les droits de flag04, pas les nôtres.

Comme c'est un script, on lit directement son code :

```bash
cat level04.pl
```

---

## Le script

```perl
#!/usr/bin/perl
# localhost:4747
use CGI qw{param};
print "Content-type: text/html\n\n";
sub x {
  $y = $_[0];
  print `echo $y 2>&1`;
}
x(param("x"));
```

## Lecture ligne par ligne

- `#!/usr/bin/perl` : le fichier est interprété par Perl.
- `# localhost:4747` : commentaire, mais **indice capital** — le script est servi
  par un serveur web local sur le **port 4747**. On l'appellera donc via une
  requête HTTP (avec `curl`), pas en le lançant à la main.
- `use CGI qw{param};` : charge le module CGI, qui sait lire les **paramètres
  d'une requête HTTP** (ce qu'il y a après le `?` dans une URL).
- `print "Content-type: text/html\n\n";` : l'en-tête HTTP obligatoire d'une
  réponse web.
- `sub x { ... }` : définit une fonction nommée `x`.
- `$y = $_[0];` : `$y` reçoit le **premier argument** passé à la fonction.
- `` print `echo $y 2>&1`; `` : exécute la commande shell `echo $y` et affiche
  sa sortie.
- `x(param("x"));` : récupère le paramètre HTTP nommé `x` et le passe à la
  fonction. Autrement dit, **`$y` = ce que l'attaquant met dans l'URL**.

---

## Le point critique

Tout se joue sur cette ligne :

```perl
print `echo $y 2>&1`;
```

**1. Les backticks `` ` ` `` ne font pas qu'afficher du texte : ils lancent un
shell.**
En Perl comme en shell, entourer quelque chose de backticks signifie « exécute
ceci **dans un shell** et récupère le résultat ». Le contenu entre backticks
n'est donc pas une simple chaîne : c'est **une vraie commande système** qui va
tourner.

**2. Notre paramètre est inséré tel quel, avant l'exécution.**
Avant de lancer la commande, Perl remplace `$y` par sa valeur (c'est
l'*interpolation*). La commande réellement exécutée est donc construite en
**collant notre texte** au milieu de `echo … 2>&1`. Aucun filtrage, aucun
échappement : ce qu'on écrit devient une **portion de commande shell**.

Concrètement, selon ce qu'on envoie dans le paramètre `x` :

| Valeur de `x` (notre entrée) | Commande shell réellement exécutée | Résultat |
|---|---|---|
| `hello` | `` echo hello 2>&1 `` | affiche `hello` (usage prévu) |
| `` `getflag` `` | `` echo `getflag` 2>&1 `` | le shell **exécute `getflag`**, puis `echo` affiche sa sortie |
| `; getflag` | `` echo ; getflag 2>&1 `` | le `;` termine le `echo`, puis **`getflag` s'exécute** |

En résumé : `echo $y` était censé se contenter de **réafficher** notre texte.
Mais comme ce texte est placé **dans une commande shell exécutée en flag04**, il
suffit d'y glisser une commande (`getflag`) pour la faire tourner à la place du
simple affichage. On détourne un `echo` inoffensif en exécution de code. **C'est
ça, l'injection de commande** : mélanger des *données* (notre entrée) et du
*code* (la commande shell) sans les séparer proprement.

---

## L'idée de l'attaque

Faire exécuter `getflag` **côté serveur** (donc en `flag04`) en l'injectant dans
le paramètre `x`. Avec les backticks, la commande devient `` echo `getflag` `` :
le shell lance d'abord `getflag`, et le token remonte dans la réponse web.

---

## Exploitation

On appelle le serveur web avec `curl` :

```bash
curl 'localhost:4747/?x=`getflag`'
```

---

## Sécurité

- **Ne jamais mélanger une entrée utilisateur avec une commande shell.** Ici,
  interpoler `$y` dans des backticks revient à laisser l'utilisateur écrire une
  partie de la commande.
- **Séparer données et code** : passer les entrées comme *arguments* d'un
  programme (liste d'arguments, sans shell), pas comme morceaux d'une ligne de
  commande. En Perl, `system("echo", $y)` (forme liste) n'aurait pas déclenché
  de shell.
- **Filtrer / valider** toute donnée venant de l'extérieur (liste blanche de
  caractères autorisés). Perl propose même le *taint mode* (`perl -T`) qui
  refuse d'utiliser une donnée externe non nettoyée dans une commande.
- Comme au level03 : plus un programme est privilégié (setuid), moins il doit
  faire confiance à ce qui vient de l'extérieur.
