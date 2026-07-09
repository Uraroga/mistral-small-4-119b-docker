# Mistral Small 4 119B distribuito su due PC con Docker e llama.cpp RPC

Esecuzione locale di **Mistral-Small-4-119B-2603-UD-Q3_K_M** su due computer x86_64 senza GPU, usando:

- Docker;
- `llama.cpp`;
- backend RPC;
- CPU con profili differenti;
- RAM distribuita tra un nodo principale e un nodo remoto.

Stato del progetto: **Progetto testato con successo su atlas5 e argo3.**

Il modello **Mistral-Small-4-119B-2603-UD-Q3_K_M** si è caricato correttamente nella configurazione collaudata:

- `atlas5` esegue `llama-server`;
- `argo3` esegue `ggml-rpc-server`;
- il collegamento RPC tra i due nodi è stato verificato;
- il modello è suddiviso in tre frammenti GGUF;
- la dimensione complessiva rilevata è circa **51 GiB**;
- il primo caricamento verificato usa **4096 token di contesto**.

La configurazione consigliata per l'uso normale è **8192 token di contesto**, mantenendo un solo slot parallelo e nessuna ottimizzazione aggiuntiva non già prevista dagli script. Aumentare ulteriormente il contesto solo dopo verifiche di memoria e stabilità.

## Architettura

```text
                              rete locale fidata
                    ┌────────────────────────────────┐
                    │                                │
                    │          RPC TCP 50052         │
                    │                                ▼
┌──────────────────────────────┐       ┌──────────────────────────────┐
│ atlas5                       │       │ argo3                        │
│                              │       │                              │
│ llama-server                 │◄─────►│ ggml-rpc-server              │
│ build AVX2                   │       │ build AVX                    │
│ modello GGUF locale          │       │ cache RPC locale             │
│ API HTTP su 127.0.0.1        │       │ nessuna API HTTP pubblica    │
│ porta HTTP 8080              │       │ porta RPC vincolata alla LAN │
└──────────────────────────────┘       └──────────────────────────────┘
```

`atlas5` è il nodo principale: contiene il modello GGUF e avvia `llama-server`.

`argo3` è il nodo RPC: esegue `ggml-rpc-server` e mette a disposizione memoria e calcolo tramite il backend RPC di `llama.cpp`.

I due binari devono essere costruiti dalla stessa identica revisione di `llama.cpp`, ma con profili CPU differenti:

| Nodo | Ruolo | CPU | Profilo |
|---|---|---|---|
| `atlas5` | nodo principale, `llama-server` | Intel Core i5-4590 | AVX2 |
| `argo3` | nodo remoto, `ggml-rpc-server` | Intel Core i3-3240 | AVX senza AVX2 |

## Sicurezza

Il backend RPC di `llama.cpp` non deve essere esposto su Internet.

Usarlo esclusivamente:

- su una rete locale fidata;
- con la porta RPC vincolata all'indirizzo LAN corretto;
- senza port forwarding sul router;
- senza inoltrare la porta `50052` dal router;
- senza pubblicazione su interfacce non necessarie;
- mai su reti pubbliche o non fidate.

La configurazione di esempio pubblica l'API HTTP del nodo principale solo su:

```text
127.0.0.1:8080
```

I due progetti indipendenti non devono essere eseguiti contemporaneamente con le stesse porte RPC e HTTP. Gli script di questa copia agiscono solo sui container:

- `mistral-small-4-server`;
- `mistral-small-4-rpc`.

Se una porta è già occupata, gli script mostrano un errore e non fermano automaticamente altri container.

## Modello

Il modello atteso su `atlas5` è:

```text
Mistral-Small-4-119B-2603-UD-Q3_K_M
```

La directory locale del modello usata nella configurazione collaudata è:

```text
/home/sergio/llama-cpp-models/Mistral-Small-4-119B-2603-UD-Q3_K_M
```

La directory locale del repository usata nella configurazione collaudata è:

```text
/home/sergio/Progetti/mistral-small-4-119b-docker
```

Questi percorsi sono esempi reali della configurazione collaudata e devono essere adattati dagli altri utenti nel proprio `.env`.

Il modello è suddiviso in tre file GGUF:

```text
Mistral-Small-4-119B-2603-UD-Q3_K_M-00001-of-00003.gguf
Mistral-Small-4-119B-2603-UD-Q3_K_M-00002-of-00003.gguf
Mistral-Small-4-119B-2603-UD-Q3_K_M-00003-of-00003.gguf
```

`MODEL_FILENAME` deve indicare il primo frammento:

```text
MODEL_FILENAME=Mistral-Small-4-119B-2603-UD-Q3_K_M-00001-of-00003.gguf
```

Gli altri frammenti devono trovarsi nella stessa cartella. Gli script riconoscono i nomi `00001-of-00003`, verificano tutti i frammenti, calcolano la dimensione totale e continuano a passare a `llama-server` solo il primo file. La dimensione totale rilevata attesa è circa **51 GiB**.

Sono supportati anche modelli GGUF composti da un solo file.

## Struttura

```text
.
├── argo3/
│   └── Dockerfile.rpc
├── atlas5/
│   └── Dockerfile.server
├── logs/
│   └── .gitkeep
├── scripts/
│   ├── avvia-argo3.sh
│   ├── avvia-atlas5.sh
│   ├── build-argo3.sh
│   ├── build-atlas5.sh
│   ├── installa-docker-ubuntu.sh
│   ├── lib-gguf.sh
│   ├── verifica-cpu.sh
│   ├── verifica-risorse-cluster.sh
│   └── verifica-rpc-atlas5.sh
├── .env.example
├── .gitignore
├── AGENTS.md
└── README.md
```

Il file `.env` contiene la configurazione locale e non deve essere pubblicato. Il file `.env.example` contiene solo valori di esempio generici.

Il modello GGUF, la cache RPC e le immagini Docker non fanno parte del repository.

Il progetto non usa `docker compose`: il file Compose vuoto è stato rimosso. L'avvio viene gestito dagli script Bash separati:

```text
scripts/avvia-argo3.sh
scripts/avvia-atlas5.sh
```

## Configurazione principale

Valori principali preparati per `atlas5`:

```dotenv
LLAMA_SERVER_IMAGE=local/mistral-small-4-llama-server-rpc-avx2:dev
LLAMA_RPC_IMAGE=local/mistral-small-4-rpc-server-avx:dev

MODEL_HOST_DIR=/home/sergio/llama-cpp-models/Mistral-Small-4-119B-2603-UD-Q3_K_M
MODEL_CONTAINER_DIR=/models
MODEL_FILENAME=Mistral-Small-4-119B-2603-UD-Q3_K_M-00001-of-00003.gguf

CONTEXT_SIZE=8192
DEFAULT_MAX_TOKENS=2048
FIT_CONTEXT=8192
SERVER_PARALLEL=1
SERVER_CACHE_RAM_MIB=0
SERVER_CACHE_PROMPT=false
LLAMA_SERVER_EXTRA_ARGS=--jinja
```

Restano configurabili in `.env`:

- indirizzi IP;
- porte;
- revisione `llama.cpp`;
- profili CPU;
- directory della cache RPC;
- parametri di distribuzione RPC.

## Profili CPU

Profilo `atlas5`:

```dotenv
MAIN_CPU_PROFILE=avx2
MAIN_GGML_NATIVE=OFF
MAIN_GGML_AVX=ON
MAIN_GGML_AVX2=ON
MAIN_GGML_FMA=ON
MAIN_GGML_F16C=ON
MAIN_GGML_BMI2=ON
```

Profilo `argo3`:

```dotenv
RPC_CPU_PROFILE=avx
RPC_GGML_NATIVE=OFF
RPC_GGML_AVX=ON
RPC_GGML_AVX2=OFF
RPC_GGML_FMA=OFF
RPC_GGML_F16C=ON
RPC_GGML_BMI2=OFF
```

Non usare una build AVX2 su `argo3`. Gli script eseguono `scripts/verifica-cpu.sh` prima della build e prima dell'avvio del container.

## Procedura

Preparare `.env` su entrambi i nodi partendo da `.env.example`:

```bash
cp .env.example .env
```

Su `argo3`, configurare almeno:

```dotenv
LLAMA_RPC_IMAGE=local/mistral-small-4-rpc-server-avx:dev
RPC_CPU_PROFILE=avx
RPC_HOST=<indirizzo-LAN-di-argo3>
RPC_BIND_HOST=0.0.0.0
RPC_PORT=50052
RPC_THREADS=4
RPC_CACHE_HOST_DIR=<directory-cache-fuori-dal-repository>
```

Su `atlas5`, configurare almeno:

```dotenv
LLAMA_SERVER_IMAGE=local/mistral-small-4-llama-server-rpc-avx2:dev
MAIN_CPU_PROFILE=avx2
RPC_HOST=<indirizzo-LAN-di-argo3>
RPC_PORT=50052
SERVER_PUBLISH_HOST=127.0.0.1
SERVER_PORT=8080
MODEL_HOST_DIR=/home/sergio/llama-cpp-models/Mistral-Small-4-119B-2603-UD-Q3_K_M
MODEL_FILENAME=Mistral-Small-4-119B-2603-UD-Q3_K_M-00001-of-00003.gguf
```

Costruire prima l'immagine RPC su `argo3`:

```bash
./scripts/build-argo3.sh
```

Avviare il container RPC su `argo3`:

```bash
./scripts/avvia-argo3.sh
```

Poi su `atlas5`, costruire l'immagine principale:

```bash
./scripts/build-atlas5.sh
```

Verificare che `atlas5` rilevi il dispositivo RPC remoto:

```bash
./scripts/verifica-rpc-atlas5.sh
```

Verificare le risorse del cluster e la dimensione totale del modello:

```bash
./scripts/verifica-risorse-cluster.sh
```

Avviare `llama-server` su `atlas5`:

```bash
./scripts/avvia-atlas5.sh
```

Per esecuzioni automatizzate consapevoli, gli script supportano `--yes`.

## Verifica rapida del server

Dopo il caricamento del modello, sul nodo principale verificare lo stato del server locale:

```bash
curl -s http://127.0.0.1:8080/health
```

Esempio essenziale per l'API compatibile OpenAI:

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Mistral-Small-4-119B-2603",
    "messages": [
      {
        "role": "user",
        "content": "Spiega in italiano che cosa significa eseguire un modello distribuito su due computer."
      }
    ],
    "temperature": 0.7,
    "max_tokens": 300
  }'
```

## Container e immagini

Container usati da questa copia:

```text
mistral-small-4-server
mistral-small-4-rpc
```

Immagini Docker:

```text
local/mistral-small-4-llama-server-rpc-avx2:dev
local/mistral-small-4-rpc-server-avx:dev
```

Gli script non usano container `privileged`, non montano il socket Docker e non eliminano container esistenti.

## Comandi utili

Log del server principale:

```bash
sudo docker logs -f mistral-small-4-server
```

Log del server RPC:

```bash
sudo docker logs -f mistral-small-4-rpc
```

Stato dei container:

```bash
sudo docker ps --filter name=mistral-small-4-server
sudo docker ps --filter name=mistral-small-4-rpc
```

Statistiche:

```bash
sudo docker stats --no-stream mistral-small-4-server
sudo docker stats --no-stream mistral-small-4-rpc
```

Arresto manuale:

```bash
sudo docker stop mistral-small-4-server
sudo docker stop mistral-small-4-rpc
```

## Note operative

- Non copiare i frammenti GGUF nel repository.
- Non pubblicare `.env`.
- Non modificare i profili CPU senza verificare i flag reali della CPU.
- Non esporre la porta RPC verso Internet.
- Non avviare contemporaneamente due progetti con le stesse porte.
- Non cambiare la configurazione di rete senza verificare prima l'esposizione effettiva delle porte.

## Licenza

Il codice di supporto di questo repository segue la licenza indicata in `LICENSE`.

Le licenze di `llama.cpp` e del modello utilizzato restano separate e devono essere rispettate.
