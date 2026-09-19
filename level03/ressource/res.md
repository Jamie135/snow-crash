# Level03

> Objectif du niveau : depuis le compte `level03`, réussir à exécuter le
> programme `getflag` **avec l'identité de `flag03`**, pour récupérer le token
> (= mot de passe de `level04`).

---

## Résumé en une phrase

Le home de `level03` contient un petit programme **setuid** (il s'exécute avec
les droits de son propriétaire `flag03`) qui, en interne, lance la commande
`echo` **sans préciser son chemin complet**. On remplace donc `echo` par notre
propre script qui appelle `getflag` : comme le programme tourne en `flag03`,
notre script tourne en `flag03` aussi. C'est une **attaque par détournement de
`$PATH`** (*PATH hijacking*).

---

## Démarche

### 1. Le détail qui change tout : le bit *setuid*

```bash
ls -l level03
file level03
```

`ls -l level03` affiche une ligne du type :

```
-rwsr-sr-x 1 flag03 flag03 8627 Mar  5  2016 level03
```

Deux choses à lire ici :

- **Propriétaire = `flag03`** (première colonne `flag03`). Le fichier appartient
  à l'utilisateur qu'on veut devenir.
- **Le `s` dans `rws`** (à la place du `x` habituel) = le bit **setuid**
  (*Set User ID*).

Rappel sur les permissions Unix : `r` = lecture, `w` = écriture, `x` =
exécution, regroupés par **propriétaire / groupe / autres**.

**Ce que fait le setuid, expliqué simplement :**

- Normalement, un programme s'exécute avec **tes** droits (ceux de `level03`).
- Avec le bit setuid, le programme s'exécute avec les droits de **son
  propriétaire** (`flag03`), **peu importe qui le lance**.

Analogie : c'est un badge d'accès prêté. Quand tu lances ce programme, tu
« empruntes » temporairement l'identité de `flag03` le temps qu'il tourne. Si on
arrive à lui faire faire ce qu'on veut, on agit en tant que `flag03`.

`file level03` confirme que c'est un **binaire compilé** (`ELF ... executable`),
donc illisible avec `cat` (ça n'affiche que du charabia : ce sont des
instructions machine, pas du texte).

### 2. Comprendre ce que fait le programme (sans le code source)

On ne dispose pas du code source, alors on observe le programme « de
l'extérieur » avec trois outils.

```bash
./level03            # 1) simplement le lancer pour voir sa sortie
strings level03      # 2) extraire les textes lisibles cachés dans le binaire
ltrace ./level03     # 3) espionner les fonctions qu'il appelle pendant qu'il tourne
```

- `./level03` : l'exécute. Il affiche simplement :

  ```
  Exploit me
  ```

- `strings level03` : parcourt le binaire et n'affiche **que** les suites de
  caractères imprimables (messages, noms de commandes…). Utile pour repérer des
  indices comme `echo`, `env`, etc.

- `ltrace ./level03` : **l'outil clé**. `ltrace` = *library trace*. Il lance le
  programme et affiche **en direct chaque appel de fonction de bibliothèque**
  qu'il effectue, avec les arguments. C'est un mouchard posé entre le programme
  et le système.

La sortie de `ltrace` révèle la ligne décisive :

```
system("/usr/bin/env echo Exploit me")
```

Traduction : pour afficher « Exploit me », le programme demande au système
(`system(...)`) de lancer la commande `/usr/bin/env echo Exploit me`.

### 3. La faille : le programme fait confiance au `$PATH`

Décomposons `/usr/bin/env echo Exploit me` :

- `env` est un utilitaire qui **cherche une commande et l'exécute**. Quand on lui
  dit `env echo`, il doit d'abord **trouver où se trouve `echo`**.
- Pour ça, `env` regarde la variable d'environnement **`$PATH`** : c'est la liste
  ordonnée des dossiers où le système cherche les commandes (par ex.
  `/usr/local/bin:/usr/bin:/bin`). Il prend **le premier `echo` qu'il trouve**.

**Le problème :** le programme dit « lance `echo` » **sans préciser lequel**
(il n'écrit pas le chemin complet `/bin/echo`). Il fait donc **aveuglément
confiance au `$PATH`**.

Or le `$PATH`, c'est **moi** (level03) qui le contrôle. Donc si je :

1. fabrique mon **propre** programme appelé `echo`,
2. et que je place son dossier **en tête** du `$PATH`,

alors c'est **mon** `echo` qui sera exécuté à la place du vrai — et comme c'est
le binaire **setuid** qui le lance, mon `echo` tournera **en tant que `flag03`**.

Il suffit que mon faux `echo` lance… `getflag`.

### 4. Exploitation

Tout se fait **sur la VM**, dans la session `level03` (le binaire, `getflag` et
`flag03` n'existent que là).

```bash
cd /tmp                    # se placer dans un dossier où level03 a le droit d'écrire
echo 'getflag' > echo      # créer notre faux "echo" : son seul rôle = lancer getflag
chmod +x echo              # le rendre exécutable
export PATH=/tmp:$PATH     # mettre /tmp EN PREMIER dans le PATH -> notre echo gagne
which echo                 # vérifier : doit répondre /tmp/echo (et non /bin/echo)
~/level03                  # lancer le binaire setuid
```

Commande par commande :

- `cd /tmp` : on va dans `/tmp`, un dossier public inscriptible par tous
  (on n'a pas le droit d'écrire dans le home ou dans `/bin`).
- `echo 'getflag' > echo` : crée un fichier nommé `echo` dont le contenu est le
  mot `getflag`. Quand ce fichier sera exécuté, il lancera la commande `getflag`.
  *(Un fichier sans en-tête `#!` est repris par le shell, qui exécute donc bien
  la ligne `getflag`.)*
- `chmod +x echo` : ajoute le droit d'**exécution** (`+x`) à notre fichier, sinon
  le système refuse de le lancer.
- `export PATH=/tmp:$PATH` : redéfinit le `$PATH` en plaçant `/tmp` **devant**
  tout le reste. Résultat : quand on cherche `echo`, `/tmp/echo` (le nôtre) est
  trouvé **avant** `/bin/echo` (le vrai).
- `which echo` : montre quel `echo` sera utilisé. On veut voir `/tmp/echo`
  (preuve que le détournement fonctionne).
- `~/level03` : lance le binaire vulnérable. `~` = le home de `level03`.

**Ce qui se passe alors :** le binaire (identité `flag03`) exécute
`env echo …` → `env` cherche `echo` dans le `$PATH` → trouve **`/tmp/echo`** →
l'exécute **en tant que `flag03`** → notre fichier lance **`getflag`**, lui aussi
en `flag03`.

### 6. Récupération du flag

Le lancement de `~/level03` affiche directement le résultat de `getflag` :

```
Check flag.Here is your token : <TOKEN>
```

---

## Pourquoi ça marche

1. Le binaire tourne **en `flag03`** (bit setuid).
2. Il lance une commande externe **par son nom** (`echo` via `env`), pas par
   chemin absolu.
3. La résolution du nom passe par le **`$PATH`**, que l'attaquant contrôle.
4. Donc l'attaquant substitue la commande → **exécution de code arbitraire en
   `flag03`**.

C'est la combinaison **setuid + commande non qualifiée + $PATH modifiable** qui
crée la faille. Enlever un seul de ces trois ingrédients suffirait à la fermer.

---

## Sécurité
Un programme privilégié (setuid) ne doit **jamais** :

- appeler une commande externe par son **nom seul** (`echo`) → toujours par
  **chemin absolu** (`/bin/echo`) ;
- faire confiance à un **environnement hérité** (`$PATH`, `IFS`, `LD_PRELOAD`…) →
  il doit **nettoyer/réinitialiser** ces variables au démarrage ;
- idéalement, éviter `system()` (qui passe par un shell) au profit d'appels plus
  stricts comme `execve()` avec un chemin explicite et un environnement maîtrisé.

Autrement dit : plus un programme a de privilèges, moins il doit faire confiance
à ce qui vient de l'extérieur (arguments, variables d'environnement, fichiers).

