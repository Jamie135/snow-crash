# Level08

## Résumé en une phrase

Le home de `level08` contient un binaire **setuid `level08`** (propriétaire
`flag08`) qui **affiche le contenu du fichier passé en argument**, mais **refuse
tout argument dont le nom contient la sous-chaîne `token`**. Juste à côté se
trouve un fichier `token` lisible **uniquement par `flag08`**. Le filtre ne teste
que **le texte du nom** (`strstr`), jamais le fichier réellement ouvert : on le
contourne avec un **lien symbolique** portant un nom sans `token` qui pointe vers
le vrai fichier. C'est une **liste noire sur le nom de fichier contournée par lien
symbolique** (confusion nom ↔ inode, famille TOCTOU).

---

## Reconnaissance

```bash
ls -la
# -rwsr-sr-x 1 flag08 level08 ... level08   <- binaire setuid
# -rw------- 1 flag08 flag08  ... token     <- lisible seulement par flag08

file level08     # ELF -> binaire compilé, illisible avec cat
cat token        # Permission denied : le fichier appartient à flag08
```

Deux fichiers qui **vont ensemble** : un binaire setuid `flag08`, et un fichier
`token` que **moi (`level08`) je ne peux pas lire**. Le binaire est donc le seul
moyen d'accéder au contenu de `token`, puisque lui s'exécute avec les droits de
`flag08`.

Vérification du bit setuid :

```
-rwsr-sr-x 1 flag08 level08 ... level08
```

Le `s` de `rws` = **setuid**, propriétaire **`flag08`** → le programme tourne en
`flag08` quel que soit celui qui le lance.

---

## Observation du comportement

```bash
./level08
# ./level08 [file to read]

./level08 token
# You may not access 'token'
```

Le programme **attend un nom de fichier** et en affiche le contenu, mais
**refuse** dès qu'on lui demande `token`. Pour comprendre *comment* il refuse, on
l'espionne avec `ltrace` :

```bash
ltrace ./level08 token
```

Ligne décisive :

```
strstr("token", "token")   = "token"
```

Traduction :

- **`strstr(botte, aiguille)`** cherche si **l'aiguille** apparaît **quelque part
  dans la botte de foin**, et renvoie un pointeur non-nul si oui.
- **1er argument** `"token"` = **la chaîne que j'ai passée** en argument.
- **2e argument** `"token"` = le **mot interdit**, codé en dur dans le binaire.
- Résultat non-nul → la sous-chaîne est trouvée → **le programme refuse**.

Le test, en clair : *« si le nom fourni contient `token`, je refuse »*. Et c'est
**tout** ce qu'il vérifie : uniquement **le texte de l'argument**, jamais
l'identité du fichier réellement ouvert.

---

## Le point critique

Le filtre juge le fichier sur **son nom** (la chaîne tapée), pas sur **son
identité** (son inode). Or je peux faire pointer **deux noms différents vers le
même fichier** grâce à un **lien symbolique** : un fichier « raccourci » qui dit
*« en réalité, lis ce fichier-là »*.

Il me faut donc un chemin qui satisfait **deux conditions à la fois** :

1. **Son nom ne contient pas `token`** → il franchit le `strstr` sans déclencher
   le refus.
2. **Il désigne quand même le vrai fichier `token`** → le programme, en `flag08`,
   ouvre les bons octets.

Un lien symbolique, créé dans un dossier où j'ai le droit d'écrire (`/tmp`), avec
un nom **sans** `token`, coche les deux cases.

> ⚠️ Le nom du lien ne doit contenir `token` **nulle part** (donc pas `nottoken`,
> pas `mytoken`… car ils contiennent la sous-chaîne `token`).

---

## Exploitation

1. **Créer un lien symbolique** vers le vrai fichier, avec un nom sans `token`.
   On utilise `~/token` : le shell développe `~` en **chemin absolu** avant
   d'appeler `ln`, ce qui est indispensable (le lien vit dans `/tmp`, sa cible
   doit être absolue) :

   ```bash
   ln -s ~/token /tmp/lol
   ```

2. **Vérifier** que le lien pointe bien vers la cible :

   ```bash
   ls -l /tmp/lol
   # /tmp/lol -> /home/user/level08/token
   ```

3. **Lancer le binaire** en lui passant **le nom du lien** :

   ```bash
   ./level08 /tmp/lol
   ```

   - `strstr("/tmp/lol", "token")` → NULL (aucun `token` dans le nom) → **pas de
     refus**.
   - Le programme, en `flag08`, **suit le lien** et affiche le contenu de `token`.

4. **(Preuve, facultatif)** confirmer *quel* fichier est réellement ouvert :

   ```bash
   strace -e trace=open,openat,readlink ./level08 /tmp/lol
   ```

   `strace` montre l'ouverture du vrai `token` alors que le `strstr` n'a pas
   bronché → contournement validé.

Le contenu de `token` s'affiche : c'est le **mot de passe de `flag08`**.

5. **Devenir `flag08`** avec ce mot de passe, puis lire le flag :

   ```bash
   su flag08
   # (coller le contenu de token comme mot de passe)
   getflag
   ```

---

## Pourquoi ça marche

1. Le binaire tourne en **`flag08`** (bit setuid) et sait donc lire `token`.
2. Sa protection est une **liste noire sur le nom** : il rejette la chaîne si elle
   **contient** `token` (`strstr`).
3. Mais il **vérifie le nom** et **ouvre le fichier** en deux temps distincts : le
   filtre regarde la chaîne, l'`open()` suit le lien symbolique. **Les deux ne
   parlent pas du même objet.**
4. Un lien symbolique bien nommé (sans `token`) **passe le filtre** tout en
   **redirigeant** l'ouverture vers le vrai `token` → lecture du fichier protégé
   en `flag08`.

C'est la confusion **nom ↔ identité réelle du fichier** (famille TOCTOU) : juger
un fichier par son nom au lieu de son inode.

---

## Sécurité

- **Ne jamais valider un fichier sur la chaîne de son nom.** Un contrôle par nom
  (`strstr`, extension, préfixe…) se contourne trivialement (lien symbolique,
  chemin relatif, `./`, `//`, chemin absolu alternatif, etc.).
- **Valider le fichier réellement ouvert** : ouvrir d'abord (`open`), puis
  vérifier via le descripteur (`fstat`, comparaison inode/périphérique), ou
  refuser les liens symboliques avec `O_NOFOLLOW` / un contrôle `lstat`.
- **Se méfier des courses TOCTOU** (*Time Of Check To Time Of Use*) : entre
  l'instant où l'on vérifie un chemin et celui où on l'ouvre, la cible peut
  changer.
- **Principe récurrent des niveaux** : un programme setuid ne doit faire confiance
  ni à l'environnement (level07), ni au `PATH` (level03), ni ici au **nom de
  fichier fourni par l'utilisateur**. Plus un programme a de privilèges, moins il
  doit croire ce qui vient de l'extérieur.
