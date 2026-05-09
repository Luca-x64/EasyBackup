# EasyBackup

Script Bash per backup incrementali tramite `rsync`, con supporto a snapshot manuali e hardlink (simile a Time Machine, ma controllato manualmente).

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


Struttura progetto
.
├── backup.sh
├── config/
│   ├── include.txt
│   └── include_phone.txt
Configurazione
File include (PC)

Modifica: `config/include.txt` 
aggiungendo le cartelle e i file che si vogliono salvare
Nota: 

Esempio:
Documents/
Desktop/
.bashrc

Regole
- una entry per riga
- `/` finale → directory ricorsiva
- file singoli supportati
- `#` → commenti

Telefono (opzionale)

Configura:

config/include_phone.txt

E imposta la sorgente:

PHONE_SRC=/path/telefono ./backup.sh

## Utilizzo
./backup.sh
Modalità
1 → Dry run (simulazione)
2 → Backup reale
Comportamento
crea uno snapshot con data corrente
riutilizza dati precedenti tramite hardlink
copia solo file modificati
Output

Gli snapshot vengono salvati in:

/mnt/<Device>/<YYYY-MM-DD>/

Esempio:

/mnt/Laptop/2026-05-10/
<details> <summary><strong>Come funziona</strong></summary>
Primo backup → copia completa
Backup successivi:
file invariati → hardlink
file modificati → copiati
ogni snapshot è indipendente e navigabile
</details>
<details> <summary><strong>Hardlink (concetto chiave)</strong></summary>
file identici condividono lo stesso inode
spazio occupato una sola volta
eliminando uno snapshot:
i file restano se referenziati da altri snapshot
</details>
Sicurezza
blocco esecuzione con sudo
verifica mount destinazione
validazione path
dry-run senza modifiche
Limitazioni
NTFS:
permessi non preservati completamente
comportamento hardlink meno prevedibile
mount non gestito automaticamente
nessuna pianificazione integrata
Best practice
eseguire sempre un dry-run prima
mantenere include.txt minimale
evitare directory inutili (.cache, .npm, ecc.)
creare snapshot solo quando serve (non automaticamente)
<details> <summary><strong>Troubleshooting</strong></summary>
Nessun file copiato

→ già presenti nello snapshot precedente (hardlink)

Backup molto veloce

→ comportamento normale (deduplicazione)

Permission denied

→ file non accessibili senza sudo

Repository not found

→ remote git errato o repo non esistente

</details>
