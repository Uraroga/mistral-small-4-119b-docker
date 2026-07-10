#!/usr/bin/env bash
set -euo pipefail

gguf_formatta_byte() {
  local byte="$1"

  awk -v byte="$byte" '
    BEGIN {
      split("B KiB MiB GiB TiB PiB", unita, " ")
      valore = byte + 0
      indice = 1
      while (valore >= 1024 && indice < 6) {
        valore = valore / 1024
        indice++
      }
      if (indice == 1) {
        printf "%.0f %s", valore, unita[indice]
      } else {
        printf "%.2f %s", valore, unita[indice]
      }
    }
  '
}

gguf_rileva_modello() {
  local model_host_dir="$1"
  local model_filename="$2"
  local prefix=""
  local indice_iniziale=""
  local totale_testuale=""
  local totale_num=0
  local indice=0
  local frammento_nome=""
  local frammento_percorso=""
  local frammento_byte=0

  GGUF_MODEL_FIRST_PATH="$model_host_dir/$model_filename"
  GGUF_MODEL_TOTAL_BYTES=0
  GGUF_MODEL_TOTAL_READABLE=""
  GGUF_MODEL_SHARD_COUNT=1
  GGUF_MODEL_IS_SPLIT=false
  GGUF_MODEL_SHARDS=()

  if [[ "$model_filename" =~ ^(.+)-([0-9]{5})-of-([0-9]{5})\.gguf$ ]]; then
    prefix="${BASH_REMATCH[1]}"
    indice_iniziale="${BASH_REMATCH[2]}"
    totale_testuale="${BASH_REMATCH[3]}"
    totale_num=$((10#$totale_testuale))

    if [[ "$indice_iniziale" != "00001" ]]; then
      printf 'Errore: MODEL_FILENAME deve indicare il primo frammento, rilevato indice %s in %s.\n' "$indice_iniziale" "$model_filename" >&2
      return 1
    fi

    if (( totale_num < 2 )); then
      printf 'Errore: nome GGUF frammentato non valido, totale frammenti %s in %s.\n' "$totale_testuale" "$model_filename" >&2
      return 1
    fi

    GGUF_MODEL_IS_SPLIT=true
    GGUF_MODEL_SHARD_COUNT="$totale_num"

    for ((indice = 1; indice <= totale_num; indice++)); do
      printf -v frammento_nome '%s-%05d-of-%05d.gguf' "$prefix" "$indice" "$totale_num"
      frammento_percorso="$model_host_dir/$frammento_nome"

      if [[ ! -f "$frammento_percorso" ]]; then
        printf 'Errore: frammento GGUF mancante: %s\n' "$frammento_percorso" >&2
        return 1
      fi

      if [[ ! -r "$frammento_percorso" ]]; then
        printf 'Errore: frammento GGUF non leggibile: %s\n' "$frammento_percorso" >&2
        return 1
      fi

      frammento_byte="$(stat -c '%s' "$frammento_percorso")"
      GGUF_MODEL_TOTAL_BYTES=$((GGUF_MODEL_TOTAL_BYTES + frammento_byte))
      GGUF_MODEL_SHARDS+=("$frammento_percorso")
    done
  else
    if [[ ! -f "$GGUF_MODEL_FIRST_PATH" ]]; then
      printf 'Errore: modello GGUF non trovato: %s\n' "$GGUF_MODEL_FIRST_PATH" >&2
      return 1
    fi

    if [[ ! -r "$GGUF_MODEL_FIRST_PATH" ]]; then
      printf 'Errore: modello GGUF non leggibile: %s\n' "$GGUF_MODEL_FIRST_PATH" >&2
      return 1
    fi

    GGUF_MODEL_TOTAL_BYTES="$(stat -c '%s' "$GGUF_MODEL_FIRST_PATH")"
    GGUF_MODEL_SHARDS=("$GGUF_MODEL_FIRST_PATH")
  fi

  GGUF_MODEL_TOTAL_READABLE="$(gguf_formatta_byte "$GGUF_MODEL_TOTAL_BYTES")"
}
