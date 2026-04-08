#!/bin/bash
cd "$(dirname "$0")"

if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
