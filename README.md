# AutoCAD Max Curvature Finder

Uno script AutoLISP per identificare automaticamente i punti di massima curvatura su polilinee 2D e 3D. Progettato specificamente per l'analisi di curve di livello topografiche, include filtri intelligenti per ignorare il rumore e le micro-ondulazioni della digitalizzazione.

## Caratteristiche
* **Campionamento Sotto-Soglia:** Trova i punti di massima curvatura anche se non coincidono con i vertici originali della polilinea.
* **Analisi a Lungo Raggio (Offset):** Filtra le piccole irregolarità analizzando la curvatura su una corda di lunghezza variabile.
* **Gestione Plateau:** Identifica il centro geometrico di archi a raggio costante.
* **Smoothing Parametrico:** Media mobile per stabilizzare i risultati su linee molto segmentate.
* **Layer Dedicato:** Crea e organizza i punti su un layer dedicato `PUNTI_CURVATURA`.

## Installazione
1. Scarica il file `MassimaCurvatura.lsp`.
2. In AutoCAD, digita il comando `APPLOAD`
3. Cerca e seleziona il file `MassimaCurvatura.lsp`.
4. Clicca sul tasto `Carica`
5. Si aprirà la finestra `Sicurezza - File eseguibile senza firma`, cliccare su `Carica sempre` per renderlo sempre disponibile in AutoCAD o su `Carica una volta` per installarlo solo nella sessione attuale.

## Utilizzo
1. Digita `MassimaCurvatura` nella riga di comando.
2. Inserisci i parametri desiderati e seleziona le polilinee da analizzare.
> [!TIP]
> È anche possibile selezionare le polilinee prima dell'esecuzione del comando.

> [!TIP]
> È possibile cambiare lo stile di visualizzazione dei punti con il comando `DDPTYEPE`

## Parametri di Configurazione
1. `Passo di Campionamento`: La distanza (in unità disegno) tra i punti di scansione lungo la linea. Un valore più piccolo aumenta la precisione ma rallenta l'elaborazione.
2. `Ampiezza Analisi (Offset)`: Il numero di passi da saltare per il calcolo della curvatura. Aumenta questo valore per ignorare il "rumore" e le micro-ondulazioni delle polilinee.
3. `Soglia Minima Curvatura`: Filtra le zone quasi rettilinee. Solo i punti con curvatura superiore a questa soglia verranno considerati.
4. `Smoothing Risultato`: Numero di campioni per la media mobile dei valori di curvatura (usare `1` per disattivarlo).

> [!CAUTION]
>È sconsigliato l'utilizzo su un grande numero di polilinee con parametri ad elevata precisione, questo potrebbe comportare tempi di esecuzione elevati e rallentamento del programma.
