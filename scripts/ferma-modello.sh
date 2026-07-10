#!/usr/bin/env bash

set -u

SERVER_CONTAINER="mistral-small-4-server"
RPC_CONTAINER="mistral-small-4-rpc"
RPC_HOST="argo3"
RPC_USER="sergio"

echo "== Arresto Mistral Small 4 =="

echo
echo "Arresto e rimozione server su atlas5..."

if sudo docker ps -a --format '{{.Names}}' | grep -Fxq "$SERVER_CONTAINER"; then
    sudo docker rm -f "$SERVER_CONTAINER"
    echo "OK: container $SERVER_CONTAINER arrestato e rimosso."
else
    echo "Il container $SERVER_CONTAINER non esiste."
fi

echo
echo "Arresto e rimozione nodo RPC su argo3..."

ssh -t "${RPC_USER}@${RPC_HOST}" "
    if sudo docker ps -a --format '{{.Names}}' | grep -Fxq '$RPC_CONTAINER'; then
        sudo docker rm -f '$RPC_CONTAINER'
        echo 'OK: container $RPC_CONTAINER arrestato e rimosso.'
    else
        echo 'Il container $RPC_CONTAINER non esiste.'
    fi
"

echo
echo "== Modello arrestato e container rimossi =="
echo "Le immagini Docker e i file del modello non sono stati cancellati."
