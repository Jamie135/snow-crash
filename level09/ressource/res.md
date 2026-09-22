# Level09

## Résumé en une phrase

Le home de `level09` contient un binaire **setuid `level09`** (propriétaire
`flag09`) qui **encode une chaîne** en décalant chaque caractère d'une quantité
égale à **sa position** dans la chaîne, et un fichier `token` **lisible par tout
le monde** mais dont le contenu est justement le mot de passe **passé dans cet
encodeur**. Le token n'est donc pas protégé par les droits mais par une simple
**obfuscation réversible** : il suffit d'**inverser le décalage** (retirer
l'indice) pour retrouver le mot de passe de `flag09`. C'est du **reverse d'un
chiffrement maison trivial** (décalage par position, inversible).

---

## Reconnaissance

```bash
ls -la
# -rwsr-sr-x 1 flag09 level09 ... level09   <- binaire setuid
# -rw-r--r-- 1 flag09 flag09  ... token     <- LISIBLE par tout le monde

file level09     # ELF -> binaire compilé
ls -l level09 token
```

Différence clé avec le level08 : cette fois le `token` est **`-rw-r--r--`**, donc
**je peux le lire**. Le secret n'est pas protégé par les permissions.

```bash
cat token
# charactere ilisible
```

Le contenu est illisible → il est **encodé**. Tout le niveau consiste à trouver
**comment le décoder**.

---

## Observation du comportement

Le binaire prend une chaîne et en renvoie une **version transformée** : c'est
**l'encodeur** qui a produit le token.

```bash
./level09
./level09 AAAAAAAAAA
```

En donnant une chaîne de **caractères identiques**, on isole l'effet de la
**position** : la sortie « grimpe » régulièrement alors que l'entrée est
constante. Chaque caractère est donc **décalé selon son indice** :

```
sortie[i] = entrée[i] + i        (i = position, à partir de 0)
```

Autrement dit : le 1er caractère est inchangé (+0), le 2e est décalé de +1, le 3e
de +2, etc.

---

## Le point critique

L'encodage est un **simple décalage réversible** :

- le fichier `token` = `mot_de_passe_flag09` passé dans cet encodeur, donc
  `token[i] = mot_de_passe[i] + i` ;
- l'opération inverse est immédiate : `mot_de_passe[i] = token[i] - i`.

Comme l'algorithme est **connu** (le binaire lui-même est l'encodeur) et
**inversible**, l'« encodage » n'offre **aucune sécurité** : on retrouve le clair
en retirant l'indice caractère par caractère.

---

## Exploitation

Le home n'étant pas inscriptible, on travaille dans `/tmp` :

```bash
mkdir -p /tmp/lol && cd /tmp/lol
```

### Version C (`decode.c`)

```c
#include <stdio.h>

int main(void)
{
    FILE *f = fopen("/home/user/level09/token", "r");
    int   c;
    int   i = 0;

    if (!f)
        return 1;
    while ((c = fgetc(f)) != EOF && c != '\n')
    {
        putchar(c - i);
        i++;
    }
    putchar('\n');
    fclose(f);
    return 0;
}
```

```bash
gcc decode.c -o decode
./decode                 # affiche le mot de passe de flag09
```

### Alternative en une ligne (sans fichier)

```bash
python -c "print(''.join(chr(ord(c)-i) for i,c in enumerate(open('/home/user/level09/token').read().strip())))"
```

---

## Pourquoi ça marche

1. Le `token` est **lisible** : aucune barrière de permission.
2. Il est seulement **obfusqué** par un décalage `+ i` (fonction de la position).
3. Cette transformation est **réversible** et son **algorithme est public** (le
   binaire `level09` *est* l'encodeur, on l'observe librement).
4. Il suffit d'appliquer l'inverse `- i` sur chaque octet du token pour
   reconstruire le mot de passe de `flag09`.

Contrairement aux niveaux précédents, il n'y a **pas** d'abus de privilège : c'est
purement du **reverse d'un encodage faible**.

---

## Sécurité

- **Obfuscation ≠ chiffrement.** Un décalage (César, XOR à clé fixe, encodage par
  position…) est **trivialement réversible** : ça ne protège rien, ça ralentit à
  peine un curieux. La *sécurité par l'obscurité* ne tient pas.
- **Ne jamais laisser un secret en clair « déguisé »** dans un fichier lisible.
  Si le token doit rester secret, il faut le **protéger par les droits** (comme au
  level08) et/ou un vrai mécanisme cryptographique avec **clé secrète**.
- **Publier l'algorithme équivaut à publier le décodeur** quand la transformation
  est inversible et sans clé : ici le binaire d'encodage donne gratuitement la
  méthode de décodage.
- Principe récurrent : la robustesse d'un secret ne doit **jamais** reposer sur le
  fait que « personne ne devinera comment c'est encodé ».
