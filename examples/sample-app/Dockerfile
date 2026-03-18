FROM python:3.12-slim

WORKDIR /app

RUN pip install --no-cache-dir flask

COPY app.py .

EXPOSE 8080

RUN useradd -r -u 1000 appuser
USER appuser

CMD ["python", "app.py"]
