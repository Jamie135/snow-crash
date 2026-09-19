# Level00

## Démarche

1. **Connexion** : `ssh level00@<IP> -p 4242`

2. **Reconnaissance** : `id`, `cat /etc/passwd` (confirme le home de
   `flag00`, mais accès direct refusé : `Permission denied`).

3. **Piste trouvée** : recherche des fichiers appartenant à `flag00` :
   ```bash
   find / -user flag00 2>/dev/null
   find / -group flag00 2>/dev/null
   # /usr/sbin/john
   # /rofs/usr/sbin/john
   ```

4. **Faille** :
   ```bash
   ls -l /usr/sbin/john
   # ----r--r-- 1 flag00 flag00 15 Mar  5  2016 /usr/sbin/john
   ```
   Lecture des permissions :
   ```
   ---          r--       r--
    |            |         |
   propriétaire  groupe   other
   ```
   - `flag00` (1ère occurrence) = le **propriétaire** du fichier
   - `flag00` (2e occurrence) = le **groupe** auquel appartient le fichier

   Le propriétaire n'a aucun droit sur son propre fichier, mais le groupe
   et *other* ont un droit de lecture. N'importe quel
   utilisateur du système y compris `level00` peut donc lire ce
   fichier normalement privé.

   ```bash
   cat /usr/sbin/john
   # cdiiddwpgswtgt
   ```

5. **Mot de passe brut invalide** : `su flag00` avec cette valeur échoue
   (`Authentication failure`). Le nom du fichier suggère un contenu chiffré.

6. **Résolution** : test par tâtonnement des rotations de César,
   automatisé via deux scripts `try_su.exp` et `bruteforce_rot.sh`

   Le script bash génère jusqu'à 25 variantes du mot trouvé (une par
   décalage de César), et pour chacune, de manière incrémentale :
   - connexion SSH avec le compte `level00`
   - tentative de changement d'utilisateur (`su flag00`)
   - au prompt de mot de passe, envoi de la rotation candidate
   - si `Don't forget to launch getflag` apparaît → succès, on garde
     ce mot de passe
   - si `Authentication failure` apparaît → échec, on passe à la
     rotation suivante

   Mot de passe chiffré trouvé : **`nottoohardhere`**
