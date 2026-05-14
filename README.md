# EasyBackup

Script Bash per backup incrementali tramite `rsync`, con supporto a snapshot manuali e hardlink (simile a Time Machine, ma controllato manualmente).
<p>
Lo script è stato realizzato per automatizzare il processo di backup di più dispositivi (PC Linux e, in futuro, smartphone).


L'eseguibile è situato sul disco esterno e consente di eseguire rapidamente il salvataggio dei file importanti.
</p>

## Caratteristiche

- Backup selettivo basato su lista (`include.txt`)
- Snapshot manuali (creati ad ogni esecuzione)
- Hardlink tra snapshot → risparmio spazio
- Modalità:
  - Dry-run (simulazione)
  - Backup reale
- Validazione dei path prima dell’esecuzione
- Supporto multi-sorgente (PC, telefono)
- Nessuna dipendenza oltre a `rsync`

---

## Requisiti

- Linux
- `rsync`
- filesystem con supporto hardlink (EXT4 consigliato)

> Sistemi operativi Windows non supportati.
---

## Struttura progetto

```
.
├── backup.sh
├── config/
│ └── prod/
│ ├── <Device1>/
│ │ ├── env.conf
│ │ └── include.txt
│ ├── <Device2>/
│ │ ├── env.conf
│ │ └── include.txt
│ └── .../
```

---

## Configurazione
Il disco di backup è montato tipicamente in: ```/mnt```.

<details>
<summary><strong>Verifica mount disco</strong></summary>

Il disco `/mnt` non deve essere montato come root puro.

Problemi se montato male:
- file creati con owner `root`
- perdita accesso lettura/scrittura
- comportamento errato degli hardlink

Verifica:

```bash
mount | grep /mnt
```

Se vedi `uid=0` o `gid=0`, correggi `/etc/fstab`:

```bash
UUID=XXXX-XXXX /mnt ntfs3 uid=1000,gid=1000,umask=022,nofail 0 0
```
(ntf3 se disco in NTFS)
</details>

---

## Configurazione dispositivi

Ogni dispositivo ha una propria configurazione:

```
config/prod/<device>/
```

Contenuto:

- `env.conf` → parametri del dispositivo  
- `include.txt` → file/cartelle da salvare  

---

### Esempio `env.conf`

```bash
NAME="Device1"  
SRC="$HOME"
DEST="Device1Folder"   
DEST_BASE="/mnt"
REQUIRE_MOUNT=1
```

---

### Significato parametri

- `SRC` → sorgente dati  
- `DEST` →  Nome della cartella del dispositivo in `/mnt/Device1/`  
- `DEST_BASE` → percorso reale (es: `/mnt`)  
- `REQUIRE_MOUNT` → verifica che il disco sia montato  

---

### Esempio `include.txt`
```
Documents/
Desktop/
.bashrc
.config/
```

---


### Regole include

- una entry per riga  
- `/` finale → directory ricorsiva  
- file singoli supportati  
- `#` → commenti  

---

## Utilizzo

```bash
./backup.sh
```

### Modalità

- `1` → Dry run (simulazione)  
- `2` → Backup reale  

### Comportamento

- crea uno snapshot con data corrente  
- copia realmente solo i file modificati  

---

## Output

Gli snapshot vengono salvati in:

```
DEST_BASE/DEST/YYYY-MM-DD/
```

### Esempio

Configurazione:

```bash
DEST="Laptop"
DEST_BASE="/mnt"
```

```
/mnt/Laptop/2026-05-10/
```

---
<details>
<summary><strong>Logica snapshot</strong></summary>

- Primo backup → copia completa  
- Backup successivi:
  - file invariati → hardlink  
  - file modificati → copiati  
- ogni snapshot è indipendente e navigabile  

</details>


<details>
<summary><strong>Hardlink</strong></summary>

- file identici condividono lo stesso inode  
- spazio occupato una sola volta  
- eliminando uno snapshot:
  - i file restano se referenziati da altri snapshot  

</details>

---

## Sicurezza

- impedisce esecuzione con `sudo`  
- verifica mount destinazione  
- validazione path  
- dry-run senza modifiche  

---

## Limitazioni

- mount non gestito automaticamente
- configurazione manuale dispositivi  
- nessuna pianificazione integrata
- Disco non deve essere montato con i permessi di root (uid e gid != 0)

---

## Best practice

- eseguire sempre un dry-run prima  
- mantenere `include.txt` minimale  
- evitare directory inutili (`.cache`, `.npm`, ecc.)  
- Non usare percorsi assoluti in `DEST`

---

<details>
<summary><strong>Esempio di esecuzione</strong></summary>

![alt text](<Screenshot From 2026-05-10 20-30-33.png>)
![alt text](<Screenshot From 2026-05-10 20-29-23.png>)
![alt text](<Screenshot From 2026-05-10 20-28-51.png>)


</details>
<details>
<summary><strong>Troubleshooting</strong></summary>

### Nessun file copiato  
→ già presenti nello snapshot precedente (hardlink)

### Backup molto veloce  
→ comportamento normale (deduplicazione)

### Permission denied  
→ file non accessibili senza sudo

</details>

---

ROADMAP:
- compressione
- cifratura
- deduplicazione con hash
- scheduling automatico
- backup remoto (drive/NAS)
---
