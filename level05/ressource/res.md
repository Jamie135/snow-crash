# Level05

## Résumé en une phrase

Une tâche **cron** exécute périodiquement le script `/usr/sbin/openarenaserver`
**en tant que `flag05`**. Ce script lance **tous les fichiers** présents dans le
dossier `/opt/openarenaserver/`, or ce dossier est **inscriptible par level05**
(via une ACL). On y dépose donc un script qui lance `getflag` : au prochain
passage du cron, il s'exécute en `flag05`.

---

## Reconnaissance

À chaque niveau, la question est : *« qu'est-ce qui appartient à `flag05` mais
que je peux lire, exécuter ou influencer ? »*. On déroule l'inventaire habituel :

```bash
ls -la                              # mon home : rien d'exploitable ici
cat /var/mail/level05               # la boîte mail : contient un indice sur le cron
find / -user flag05 2>/dev/null     # les fichiers appartenant à flag05
```

`find / -user flag05` renvoie :

```
/usr/sbin/openarenaserver
/rofs/usr/sbin/openarenaserver
```

(La boîte mail `/var/mail/level05` menait au même endroit en décrivant la tâche
cron : deux portes vers la même faille.)

---

## Le script déclenché par le cron

```bash
cat /usr/sbin/openarenaserver
```

```sh
#!/bin/sh

for i in /opt/openarenaserver/* ; do
    (ulimit -t 5; bash -x "$i")
    rm -f "$i"
done
```

Ligne par ligne :

- `for i in /opt/openarenaserver/*` : boucle sur **chaque fichier** présent dans
  `/opt/openarenaserver/` (`$i` = un fichier à chaque tour).
- `(ulimit -t 5; bash -x "$i")` : **exécute** ce fichier comme un script bash,
  dans un sous-shell limité à 5 s de temps CPU. `bash -x` active le mode trace,
  mais l'essentiel est qu'il **exécute** le contenu du fichier.
- `rm -f "$i"` : supprime le fichier après exécution (le dossier sert de file
  d'attente à usage unique).

---

## Le point critique : pourquoi notre fichier tournera en `flag05`

**L'identité d'un processus vient de QUI le lance, pas de QUI a écrit le
fichier.** Ce n'est pas nous qui lançons notre fichier : c'est le script
`openarenaserver`, lui-même lancé par le **cron en tant que `flag05`**. Notre
fichier est donc exécuté **par un processus flag05** → il tourne en `flag05`.

La chaîne complète :

```
cron  ──lance──►  openarenaserver        (exécuté EN TANT QUE flag05)
                        │  "exécute chaque fichier de /opt/openarenaserver/"
                        ▼
                  notre_script.sh         (lancé PAR flag05  →  tourne EN flag05)
                        │  contient : getflag
                        ▼
                  getflag                 (s'exécute EN flag05  →  donne le token)
```

Deux conditions rendent l'attaque possible :

1. **On peut écrire dans le dossier** (`/opt/openarenaserver/`) → on peut y
   *déposer* un fichier.
2. **flag05 exécute automatiquement ce dossier** (cron + script) → c'est *lui*
   qui *lance* notre fichier.

*Nous = on dépose (droit d'écriture) ; flag05 = il exécute (le cron).* C'est le
croisement des deux qui crée la faille.

---

## Vérifier le droit d'écriture

```bash
getfacl /opt/openarenaserver/
```

```
user::rwx
user:level05:rwx        <-- level05 a bien r/w/x sur le dossier
user:flag05:rwx
group::r-x
mask::rwx               <-- le masque autorise rwx (donc le rwx de level05 est effectif)
other::r-x
default:...             <-- droits appliqués aux fichiers créés dans le dossier
```

La ligne **`user:level05:rwx`** confirme qu'on peut écrire dans le dossier,
malgré le `r-x` des « others ». Condition n°1 validée.

---

## Exploitation

### 1. Déposer le payload

```bash
echo 'getflag > /tmp/flag05.txt 2>&1; chmod 644 /tmp/flag05.txt' > /opt/openarenaserver/exploit.sh
```

Contenu du script déposé :

- `getflag` → sera exécuté **par flag05** → produit le token.
- `> /tmp/flag05.txt` → **redirige la sortie** vers un fichier. Nécessaire, car le
  cron tourne **sans écran** : sans redirection, le token s'afficherait dans le
  vide.
- `2>&1` → capture aussi les erreurs éventuelles dans le même fichier.
- `chmod 644 /tmp/flag05.txt` → le fichier est créé **par flag05** (donc lui
  appartient) ; ce `chmod` le rend **lisible par level05**.

Notes :
- Pas besoin de `chmod +x` : `openarenaserver` lance le fichier avec
  `bash -x "$i"`, donc bash lit le contenu directement.
- `exploit.sh` sera **supprimé automatiquement** après exécution (`rm -f` dans le
  script). C'est normal : il a déjà fait son travail.

### 2. Attendre le passage du cron (~1 à 2 minutes)

Après une à deux minutes affiche le fichier texte avec:
```bash
cat /tmp/flag05.txt
```

---

## Sécurité

- **Un dossier inscriptible par tous + une exécution privilégiée = danger.** Faire
  exécuter par un compte privilégié (`flag05`) tout le contenu d'un répertoire où
  n'importe qui peut écrire revient à donner un droit d'exécution arbitraire.
- **Corriger** : soit le dossier ne doit être inscriptible que par le compte
  privilégié lui-même, soit le script ne doit exécuter que des fichiers dont il
  vérifie strictement le propriétaire et les droits.
- Règle générale des tâches automatiques (cron) : bien contrôler **qui** peut
  influencer **ce qu'elles exécutent**.