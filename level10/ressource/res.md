# Level10

## Démarche

1. **Reconnaissance**

   ```bash
   ls -ll
   -rwsr-s---+ 1 flag10 level10 8617 ... level10
   -rw------- 1 flag10 flag10    26 ... token
   ```

   - Binaire setuid vers `flag10`.
   - Un fichier `token` de 26 octets, illisible directement, réservé au propriétaire `flag10`.

   ```bash
   strings level10
   # "%s file host"
   # "sends file to host if you have access to it"
   # "Connecting to %s:6969 .."
   # "Damn. Unable to open file"
   # "You don't have access to %s"
   ```

   Le binaire attend deux arguments (`file` et `host`), et échange des données réseau vers `host:6969` avant de lire et d'envoyer `file`.

2. **Analyse**

   Désassemblage de `main` (`objdump -d level10`) : 


                       LANCEMENT DU BINAIRE
                            │
                            ▼
                  ┌──────────────────┐
                  │      _start      │
                  └────────┬─────────┘
                           │
             Prépare argc / argv / stack
                           │
                           ▼
              ┌────────────────────────┐
              │  __libc_start_main()   │
              │      via la PLT        │
              └───────────┬────────────┘
                          │
              Initialisation du runtime C
                          │
             ┌────────────┴────────────┐
             ▼                         ▼
        Initialisation             constructeurs
        globale (_init)              globaux
             │                         │
             └────────────┬────────────┘
                          ▼
                 ┌────────────────┐
                 │      main      │
                 │   0x080486d4   │
                 └───────┬────────┘
                         │
                         ▼
              Vérification argc
                  argc > 2 ?
                 /          \
              NON            OUI
               │              │
               ▼              ▼
          printf usage     Récupère
          puis exit(1)     argv[1], argv[2]
                              │
                              ▼
                       access(argv[1], 4)
                              │
                    ┌─────────┴─────────┐
                    │                   │
                  ÉCHEC              SUCCÈS
                    │                   │
                    ▼                   ▼
                 printf             printf
                 erreur             message
                (PAS de exit,       + fflush
                 retour direct           │
                 vers le stack           ▼
                 check / ret)      socket(AF_INET,
                                    SOCK_STREAM, 0)
                                          │
                                          ▼
                                    Prépare sockaddr
                                    ├── famille = AF_INET
                                    ├── IP = argv[2]
                                    └── port = 0x1b39 (6969)
                                          │
                                          ▼
                                    connect(socket,...)
                                          │
                                ┌─────────┴─────────┐
                                │                   │
                             ÉCHEC              SUCCÈS
                                │                   │
                                ▼                   ▼
                             erreur            write(socket,
                             + exit(1)         banner, 8)
                                                     │
                                           ┌─────────┴─────────┐
                                           │                   │
                                        ÉCHEC              SUCCÈS
                                           │                   │
                                           ▼                   ▼
                                        erreur            open(argv[1],
                                        + exit(1)         O_RDONLY)
                                                                │
                                                      ┌─────────┴─────────┐
                                                      │                   │
                                                   ÉCHEC              SUCCÈS
                                                      │                   │
                                                      ▼                   ▼
                                                   puts()            read(fd,
                                                   erreur            buffer, 0x1000)
                                                   + exit(1)              │
                                                                ┌─────────┴─────────┐
                                                                │                   │
                                                             ÉCHEC              SUCCÈS
                                                                │                   │
                                                                ▼                   ▼
                                                          strerror(errno)      write(socket,
                                                          + printf erreur     buffer, n)
                                                          + exit(1)                │
                                                                                   ▼
                                                                                puts()
                                                                                   │
                                                                                   ▼
                                                                              retour
                                                                                   │
                                                                                   ▼
                                                                            stack check
                                                                                   │
                                                                                   ▼
                                                                                 ret

   **En synthèse** : `main` vérifie d'abord `argc`, récupère `file`/`host`, puis fait `access(file, R_OK)` , un contrôle basé sur l'UID **réel** de l'utilisateur, qui décide seul si le programme continue. S'il réussit, le programme ouvre une connexion réseau vers `host:6969`, envoie une petite bannière, **puis seulement à ce moment-là** appelle `open(file, ...)` avec les droits du setuid (`flag10`) sur le **même chemin `file`** qu'au moment du check, sans jamais le revalider. Tout ce qui se passe entre `access()` et `open()` (connexion réseau incluse) constitue la fenêtre pendant laquelle `file` peut être détourné.

   `access(file, R_OK)` est vérifié avec l'UID **réel** de l'appelant (comportement standard POSIX pour un setuid), puis `open(file, ...)` est exécuté plus tard avec les droits du setuid (`flag10`), sur le **même pointeur `file`**, sans jamais revalider le chemin entre les deux.

3. **Faille / principe**

   C'est un **TOCTOU** (*Time-Of-Check-To-Time-Of-Use*) : entre le `access()` et l'`open()`, on peut faire pointer `file` (via un lien symbolique) vers un fichier différent de celui validé par le check.

   La fenêtre est exploitable en pratique car elle contient un **`connect()` réseau** , un appel bloquant dont la durée dépend de l'hôte distant. En pointant `host` vers une machine qu'on contrôle et en lançant énormément de tentatives en parallèle, on maximise la probabilité qu'un `open()` tombe pendant que le lien pointe vers la cible protégée plutôt que vers le fichier légitime.

4. **Contournement / implémentation**

   - Un **racer** qui bascule un symlink en boucle entre un fichier légitime (`access()` passe) et le fichier protégé (`open()` doit tomber dessus).
   - Un **listener** (`nc -lk 6969`) qui capture ce que le binaire renvoie.
   - Plusieurs **workers en parallèle** qui relancent le binaire des milliers de fois, pour multiplier les tentatives par seconde.
   - À la fin, strings log extrait toutes les séquences de caractères imprimables du fichieret **grep -E '^[[:alnum:]]{10,40}$'** ne garde que les lignes entièrement alphanumériques de 10 à 40 caractères, ça élimine tout le bruit et devrait faire ressortir le token


   ```bash

   $>: scp -P 4242 ./level10/ressource/toctou.sh level10@<VM_IP>:/tmp/
   ````
    ```
    level10@SnowCrash:~$ cd /tmp
   level10@SnowCrash:/tmp$ bash toctou.sh
   ===  token ===
   woupa2yuojeeaaed06riuj63c
   ...
   ```