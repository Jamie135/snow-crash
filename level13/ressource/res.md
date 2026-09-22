# Level13

## Résumé en une phrase

Le home de `level13` contient un binaire **setuid `level13`** (propriétaire
`flag13`) qui **refuse de s'exécuter** tant que **`getuid()` ne vaut pas 4242** ;
or le token est **calculé à l'intérieur du binaire** (aucun fichier protégé à
lire), donc il n'y a **aucun privilège à obtenir** : il suffit de **mentir sur
l'UID**. On remplace `getuid()` par une version qui renvoie `4242` via
**`LD_PRELOAD`** — mécanisme ignoré sur un binaire setuid, d'où l'astuce : on
l'applique sur une **copie non-setuid** du binaire. C'est du **détournement de
fonction de bibliothèque (`LD_PRELOAD`) sur une copie**.

---

## Reconnaissance

```bash
ls -la
file level13
./level13 → UID 2013 started us but we we expect 4242
```

Le programme **lit mon UID réel** (`2013` = `level13`) et le compare à une valeur
codée en dur (**4242**). Comme ça ne correspond pas, il s'arrête. Le seul verrou
du niveau est **ce contrôle d'UID**.

```bash
ltrace ./level13
```

On voit un appel **`getuid()`** dont le retour est comparé à `4242`. C'est bien la
seule condition d'entrée.

```bash
strace -e trace=open ./level13
```

**Confirme qu'aucun fichier appartenant à `flag13` n'est ouvert** → le token n'est pas lu sur
le disque, il est **fabriqué en interne** par le programme.

➡️ Conséquence : je n'ai **pas besoin des droits de `flag13`**. Le token
apparaîtra dès que je **passe le contrôle `getuid() == 4242`**, sans aucun
privilège particulier. 
**Je peux donc créer ma propre `getuid()` qui retourne l'identité 4242.**

---

## Le point critique

`getuid()` est une fonction de la **libc**, quand on lance le programme, un petit intermédiaire appelé le chargeur (**ld.so**) fait le lien entre l'appel **getuid()** de ton programme sur la vraie fonction **getuid()** de la **libc**.

Il existe une variable d'environnement **`LD_PRELOAD`** qui est capable de dire au chargeur **ld.so**:  «Avant la libc, charge d'abord cette bibliothèque-là.».

**Le hic :** par sécurité, le chargeur dynamique **ignore `LD_PRELOAD` sur les
binaires setuid** (sinon on détournerait n'importe quel programme privilégié).
Donc `LD_PRELOAD=... ./level13` ne fait rien sur l'original.

**La solution** découle de l'observation précédente : puisque le token est calculé
en interne et ne demande aucun privilège, je n'ai pas besoin de la version setuid.
Je travaille sur une **copie que je possède** → elle **n'est plus setuid** → le
chargeur **respecte** alors mon `LD_PRELOAD`, et la copie produit **le même
token**.

---

## Exploitation

Le home n'étant pas inscriptible, on travaille dans `/tmp` :

```bash
mkdir -p /tmp/lol && cd /tmp/lol
```

### 1. Copier le binaire (la copie n'est plus setuid)

```bash
cp ~/level13 /tmp/lol/level13
ls -l /tmp/lol/level13      # -rwxr-xr-x : un 'x', plus de 's' -> plus de setuid
```

### 2. Écrire un faux `getuid()` (`fake.c`)

```c
#include <sys/types.h>

uid_t getuid(void)
{
    return 4242;
}
```

### 3. Compiler en bibliothèque partagée

```bash
gcc -shared -fPIC fake.c -o fake.so
```

- `-shared` : produit un `.so` (ce que `LD_PRELOAD` charge).
- `-fPIC` : code indépendant de la position, obligatoire pour une lib partagée.

### 4. Lancer la copie en injectant la lib

```bash
LD_PRELOAD=/tmp/lol/fake.so /tmp/lol/level13
```

- `LD_PRELOAD` charge **ma** `getuid()` en premier → elle renvoie `4242`.
- On lance **la copie** `/tmp/lol/level13`, jamais l'original setuid.

Le programme n'affiche plus « expect 4242 » mais une **chaîne** = le **mot de
passe de `flag13`**.

---

## Pourquoi ça marche

1. Le seul obstacle est un test **`getuid() == 4242`** ; le token est **calculé en
   interne**, donc aucun privilège de `flag13` n'est requis.
2. `getuid()` est résolue **dynamiquement** → on peut la **remplacer** avec
   `LD_PRELOAD`.
3. `LD_PRELOAD` est **neutralisé sur un binaire setuid** ; mais une **copie que je
   possède n'est pas setuid**, donc le chargeur l'accepte.
4. Ma fonction renvoie `4242` → le contrôle passe → le programme calcule et affiche
   le token, **identique** à celui de l'original (calcul interne).

---

## Sécurité

- **Ne jamais fonder une autorisation sur une fonction remplaçable côté client.**
  `getuid()` peut être détournée (`LD_PRELOAD`), patchée sous `gdb`, ou contournée
  sur une copie. Un contrôle d'accès sérieux se fait **côté noyau** (droits, UID
  effectif réellement appliqués), pas par un `if (getuid() == …)` en espace
  utilisateur.
- **Un secret calculable par le programme lui-même n'est pas un secret** : dès que
  le binaire est lisible/copiable, la logique (ici la génération du token) est
  reproductible sans aucun privilège. La barrière `getuid` n'était qu'un rideau.
- Le garde-fou `LD_PRELOAD`-ignoré-sur-setuid est une **bonne** protection du
  système ; la faille est côté **conception du programme**, qui croit qu'un test
  d'UID en espace utilisateur protège quoi que ce soit.
- Variante possible d'exploitation : sauter le test sous **`gdb`** — même leçon,
  puisque le token ne dépend pas des privilèges mais seulement du contrôle.
