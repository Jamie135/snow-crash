# Level06

## Résumé en une phrase

Le home de `level06` contient un script **PHP** (`level06.php`) exécuté avec les
droits de `flag06`. Ce script lit un fichier que **je** lui donne et utilise une
fonction PHP (`preg_replace`) avec une option spéciale — le modificateur `/e` —
qui **exécute comme du code** une partie de ce que contient mon fichier. En y
glissant du code PHP qui lance `getflag`, ce code tourne en `flag06`. C'est une
**injection de code** (comme au level04, mais côté PHP au lieu du shell).

---

## Reconnaissance

Le réflexe habituel de chaque niveau :

```bash
ls -la                              # que contient mon home ?
cat /var/mail/level06 2>/dev/null   # un indice y est parfois laissé
find / -user flag06 2>/dev/null     # fichiers appartenant à la cible
```

On repère dans le home un fichier `.php`. Comme c'est du code lisible, on le lit :

```bash
cat level06.php
```

---

## Le script (et sa traduction en français)

Le script ressemble à ceci :

```php
<?php
function y($m) {
  $m = preg_replace("/\./", " x ", $m);
  system($m);
}
function x($y, $z) {
  $a = file_get_contents($y);
  $a = preg_replace("/(\[x (.*)\])/e", "y(\"\\2\")", $a);
  echo $a;
}
x($argv[1], $argv[2]);
```

Décortiquons-le **ligne par ligne**:

- `function x($y, $z) { ... }` : définit une fonction nommée `x` qui reçoit deux
  entrées. C'est **elle qui est lancée en dernier** (voir plus bas).
- `$a = file_get_contents($y);` : `file_get_contents` **lit tout le contenu d'un
  fichier** et le range dans la variable `$a`. Ici `$y` est le **nom de fichier
  que je fournis** → donc `$a` = ce que **j'ai écrit** dans mon fichier.
- `$a = preg_replace(...);` : la ligne clé, expliquée juste après.
- `echo $a;` : affiche le résultat à l'écran.
- `x($argv[1], $argv[2]);` : **lance** la fonction `x` en lui donnant les
  arguments tapés sur la ligne de commande. Autrement dit : le fichier que je
  passe au programme se retrouve lu par `file_get_contents`.

---

## Comprendre `preg_replace` (rechercher-remplacer)

`preg_replace` est une fonction de **rechercher-remplacer**, comme dans un
traitement de texte, mais en plus puissant. Elle prend trois choses :

```php
preg_replace( MOTIF , REMPLACEMENT , TEXTE )
```

1. **MOTIF** : ce qu'on cherche, décrit avec une *expression régulière* (une
   façon de décrire des motifs de texte).
2. **REMPLACEMENT** : par quoi on remplace ce qui a été trouvé.
3. **TEXTE** : le texte dans lequel on cherche (ici `$a`, le contenu de mon
   fichier).

Le motif est écrit entre deux `/` : `"/.../"`. Après le second `/`, on peut
ajouter des **lettres d'option** qui changent le comportement. Regarde bien la
fin du motif du script :

```php
"/(\[x (.*)\])/e"
                ^  <-- cette lettre "e" change TOUT
```

---

## La faille : le modificateur `/e`

**Sans le `e`**, `preg_replace` fait juste du remplacement de texte : il colle
bêtement la chaîne de remplacement là où le motif a été trouvé. Inoffensif.

**Avec le `e`** (pour *eval* = « évaluer »), le remplacement n'est plus traité
comme du texte : PHP le **considère comme du code PHP et l'exécute**. C'est une
option historique, connue pour être dangereuse (elle a été rendue obsolète puis
**supprimée** dans les versions récentes de PHP, précisément à cause de failles
comme celle-ci).

Concrètement, le motif `(\[x (.*)\])` cherche dans mon fichier un morceau de la
forme `[x QUELQUE_CHOSE]` :
- `\[` et `\]` = les crochets littéraux `[` et `]`.
- `(.*)` = « n'importe quoi » — c'est **le texte que je contrôle**, capturé pour
  être réutilisé (on l'appelle `\\2`, le 2ᵉ groupe capturé).

Le remplacement est `y("\\2")`. À cause du `/e`, PHP **exécute** ce bout de code
en y ayant d'abord inséré mon texte à la place de `\\2`.

**En clair** : ce que je mets entre `[x ...]` dans mon fichier se retrouve
**injecté dans du code PHP qui est ensuite exécuté**. Je ne fournis plus des
*données*, je fournis du *code* → c'est l'injection.

---

## La fonction `y` : un petit piège à repérer

```php
function y($m) {
  $m = preg_replace("/\./", " x ", $m);   // remplace chaque point "." par " x "
  system($m);                              // exécute le résultat comme commande shell
}
```

Deux choses à comprendre :

- `system($m)` **exécute une commande système** (comme dans un terminal). C'est
  la porte de sortie : si on arrive à contrôler ce qui passe dans `system`, on
  exécute ce qu'on veut — **en tant que `flag06`**.
- Avant ça, `preg_replace("/\./", " x ", $m)` **remplace chaque point `.`** par
  ` x `. C'est le **piège** : il ne faut pas que ma payload contienne des points
  « utiles », sinon ils seront transformés et casseront la commande. À garder en
  tête au moment de fabriquer l'entrée.

---

## L'idée de l'attaque (piste, à compléter soi-même)

L'objectif : faire en sorte que le code PHP évalué par le `/e` finisse par
**lancer `getflag`** (qui, exécuté par un processus tournant en `flag06`, donne
le token).

La démarche à explorer :

1. **Créer un fichier** (par ex. dans `/tmp`, un dossier où j'ai le droit
   d'écrire) contenant un motif de la forme `[x ... ]`, où `...` est du code PHP
   qui déclenche l'exécution de `getflag`.
2. Réfléchir à **comment PHP évalue une chaîne** : dans une chaîne PHP, certaines
   syntaxes de type `${ ... }` sont elles-mêmes évaluées. C'est la piste à
   creuser pour faire exécuter une commande.

```bash
echo '[x ${`getflag`}]' > /tmp/exploit06
```

3. **Passer ce fichier au programme** en argument (`./level06 <mon_fichier>`) et
   observer la sortie.
4. Ne pas oublier le **piège des points** (fonction `y`) : tester, ajuster,
   recommencer — comme les rotations de César du level00.

```bash
./level06 /tmp/exploit06
```

---

## Sécurité

- **Ne jamais utiliser `preg_replace` avec le modificateur `/e`** (ni aucune
  fonction du type `eval`) sur des données venant de l'extérieur. Évaluer une
  entrée utilisateur comme du code, c'est lui donner les clés du programme.
- **Séparer les données et le code** : une entrée utilisateur doit rester une
  *donnée* (du texte affiché, comparé, stocké), jamais une *instruction*
  exécutée.
- **Valider / filtrer** toute entrée (liste blanche de caractères autorisés).
- Comme aux levels 03, 04 et 05 : plus un programme est privilégié, moins il doit
  faire confiance à ce qui vient de l'extérieur (arguments, fichiers, variables).
