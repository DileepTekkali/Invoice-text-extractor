#!/bin/bash
source venv/bin/activate
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi
uvicorn app.main:app --host 0.0.0.0 --port $PORT
