# Level01

## Démarche


1. **Piste déjà repérée au level00** : en lisant `/etc/passwd` (fichier
   lisible par tous), la ligne de `flag01` contient un hash de mot de
   passe **directement en clair** au lieu du `x` habituel :
   ```
   flag01:42hDRfypTqqnw:3001:3001::/home/flag/flag01:/bin/bash
   ```

3. **Faille** : `/etc/passwd` devrait uniquement contenir un `x` (le vrai
   hash étant stocké dans `/etc/shadow`, protégé). Ici, le hash complet
   est exposé, lisible par n'importe quel utilisateur du système.

4. **Identification du format** : `42hDRfypTqqnw` (13 caractères) est un
   hash **DES crypt(3) traditionnel**,  un format ancien et faible

5. **Cassage hors ligne** avec John the Ripper, exécuté sur la machine
   hôte (pas sur la VM) :
   ```bash
   echo 'flag01:42hDRfypTqqnw' > flag01.hash
   john flag01.hash
   ```
   Résultat  :
   ```
   abcdefg
   ```