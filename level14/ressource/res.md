# Level14

## Démarche

1. **Reconnaissance**

   Aucun fichier ni indice exploitable directement dans le home de `level14` :

   ```bash
   ls -la /home/user/level14/
   find / \( -user flag14 -o -group level14 \) 2>/dev/null
   # rien de concluant
   ```

   Faute de piste côté fichiers propres au niveau, on se tourne vers le
   binaire `getflag` lui-même 

   En désassemblant `getflag` (`gdb  getflag` puis `disassemble main`),
   on retrouve dans `main` une **comparaison de `getuid()` contre une liste
   d'UID codée en dur**:

   ```asm
   call getuid@plt
   ...
   cmp $0xbbe,%eax    ; 0xbbe = 3006
   je     ...
   cmp $0xbba,%eax    ; 0xbba = 3002
   je     ...
   ...
   ```

   Ces valeurs correspondent exactement aux UID trouvés dans `/etc/passwd` :

   ```
   flag00:x:3000:3000::/home/flag/flag00:/bin/bash
   flag01:...:3001:3001::/home/flag/flag01:/bin/bash
   flag02:x:3002:3002::/home/flag/flag02:/bin/bash
  
   ```
   Donc `flag14` correspond à l'UID **3014** , c'est cette valeur précise que
   `getflag` doit lire via `getuid()` pour libérer le bon token.

2. **Analyse**

   `getflag` (comme `level13`) commence par un `ptrace(PTRACE_TRACEME, ...)`
   , mécanisme anti-debug classique : un process qui se trace lui-même
   empêche un second traceur (comme `gdb`) de s'y attacher normalement.
   Lancé **sous `gdb`**, cet appel échoue systématiquement (`eax < 0`),
   ce qui fait quitter le programme immédiatement avant même d'atteindre
   la logique intéressante.

   Juste après, `main` appelle `getuid()` et compare son résultat
   (toujours dans `eax` à la sortie de l'appel) à la
   liste d'UID codée en dur, pour décider quel token afficher.

3. **Faille / principe**

   Le contrôle d'accès repose **entièrement** sur la valeur renvoyée par
   `getuid()` **au moment précis où `eax` est lu après l'appel** 
   Sous `gdb`, on peut **modifier directement le contenu d'un registre à
   l'exécution** , à n'importe quel point d'arrêt. Il suffit donc
   d'intercepter le programme à deux endroits :

   - juste après le `ptrace()`, pour forcer son retour à `0` (succès) et
     contourner l'anti-debug ;
   - juste après le `getuid()`, pour forcer `eax` à `3014` (l'UID de
     `flag14`), sans jamais avoir besoin d'être réellement connecté sous
     ce compte.

   Le programme croit alors s'exécuter avec l'UID de `flag14`, qui affiche le token.

4. **Contournement / implémentation**

   ```bash
   gdb ./getflag
   ```

   ```gdb
   break *<adresse juste après le call ptrace@plt>
   break *<adresse juste après le call getuid@plt>
   run
   ```

   Au premier breakpoint atteint (retour de `ptrace()`) :
   ```gdb
   set $eax = 0
   continue
   ```

   Au second breakpoint atteint (retour de `getuid()`) :
   ```gdb
   set $eax = 3014
   continue
   ```