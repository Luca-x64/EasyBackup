# EasyBackup

Script Bash per backup incrementali tramite `rsync`, con supporto a snapshot manuali e hardlink (simile a Time Machine, ma controllato manualmente).
<p>
Lo script lo ho realizzato per automatizzare il processo di backup dei miei dispositivi (pc linux e smartphone).

L'eseguibile è situato sul disco esterno di backup e mi permette rapidamente di eseguire un salvataggio dei file importanti.
</p>

ROADMAP:
- estendere il supporto per Android
- Compressione
- Cifratura
- dedup file con hash
- scheduling automatico backup
- backup su drive
---

## Caratteristiche

- Backup selettivo basato su lista (`include.txt`)
- Snapshot manuali (creati quando esegui lo script)
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

> NTFS funziona ma con limitazioni (permessi e comportamento hardlink)

> Sistemi operativi Windows non supportati.
---

## Struttura progetto

```
.
├── backup.sh
├── config/
│   ├── include.txt
│   └── include_phone.txt
```

---

## Configurazione
`/mnt` disco di backup

<details>
<summary><strong>VERIFICARE CHE IL DISCO SIA MONTATO SENZA I PERMESSI DI ROOT</strong></summary>

Il disco di destinazione `/mnt` **non deve essere montato come root puro**, altrimenti:

- i file verranno creati con owner `root`
- potresti perdere accesso in lettura/scrittura
- gli hardlink possono comportarsi in modo incoerente

Verifica mount: `bash mount | grep /mnt`
se user_id=0,group_id=0 => mount effettuato come root → configurazione non corretta

modifica `/etc/fstab`
```bash
UUID=XXXX-XXXX /mnt ntfs3 uid=1000,gid=1000,umask=022,nofail 0 0
```
(ntf3 se disco in NTFS)
</details>

<details>
<summary><strong>PC Linux</strong></summary>

Modifica `config/include.txt` aggiungendo le cartelle e i file che vuoi salvare.

Esempio:

```
Documents/
Desktop/
.bashrc
```


### Regole

- una entry per riga  
- `/` finale → directory ricorsiva  
- file singoli supportati  
- `#` → commenti  

<details>
<summary><strong>VERIFICARE CHE IL DISCO SIA MONTATO SENZA I PERMESSI DI ROOT</strong></summary>

Il disco di destinazione `/mnt` **non deve essere montato come root puro**, altrimenti:

- i file verranno creati con owner `root`
- potresti perdere accesso in lettura/scrittura
- gli hardlink possono comportarsi in modo incoerente

Verifica mount: `bash mount | grep /mnt`
se user_id=0,group_id=0 => mount effettuato come root → configurazione non corretta

modifica `/etc/fstab`
`UUID=XXXX-XXXX /mnt ntfs3 uid=1000,gid=1000,umask=022,nofail 0 0`

(ntf3 se disco in NTFS)
</details>

</details>
<details>
<summary><strong>Telefono (WIP)</strong></summary>

Configura:

```
config/include_phone.txt
```

E imposta la sorgente:

```bash
PHONE_SRC=/path/telefono ./backup.sh
```

</details>

## Utilizzo

```bash
./backup.sh
```

### Modalità

- `1` → Dry run (simulazione)  
- `2` → Backup reale  

### Comportamento

- crea uno snapshot con data corrente  
- riutilizza dati precedenti tramite hardlink  
- copia solo file modificati  

---

## Output

Gli snapshot vengono salvati in:

```
/mnt/<Device>/<YYYY-MM-DD>/
```

Esempio:

```
/mnt/Laptop/2026-05-10/
```


<p>`Device` è il nome della cartella del disco di backup che conterrà i backup di un determinato dispositivo (da creare manualmente)</p>

---
<details>
<summary><strong>Come funziona</strong></summary>

- Primo backup → copia completa  
- Backup successivi:
  - file invariati → hardlink  
  - file modificati → copiati  
- ogni snapshot è indipendente e navigabile  

</details>


<details>
<summary><strong>Hardlink (concetto chiave)</strong></summary>

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
- nessuna pianificazione integrata
- Disco non deve essere montato con i permessi di root (uid e gid != 0)

---

## Best practice

- eseguire sempre un dry-run prima  
- mantenere `include.txt` minimale  
- evitare directory inutili (`.cache`, `.npm`, ecc.)  

---

<details>
<summary><strong>Troubleshooting</strong></summary>

### Nessun file copiato  
→ già presenti nello snapshot precedente (hardlink)

### Backup molto veloce  
→ comportamento normale (deduplicazione)

### Permission denied  
→ file non accessibili senza sudo

</details>
