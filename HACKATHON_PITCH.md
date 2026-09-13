# AirWise — Delhi-NCR Air Quality Intelligence

AirWise helps Delhi-NCR residents make safer daily decisions using live weather and air-quality information. It combines current pollutant readings, a 72-hour outlook, weather context, health guidance, and a question-driven advisor.

## Problem

Air-quality numbers alone do not answer the everyday question: “Can I go outside today?” People need understandable, timely guidance that accounts for pollution and weather together.

## Solution

AirWise converts live PM2.5, PM10, NO₂, O₃, AQI, wind, humidity and temperature signals into clear advice. The in-app AirWise advisor answers practical questions such as outdoor suitability, mask use, and the cleaner forecast window.

## Real data, not simulation

The MVP fetches live weather and air-quality forecasts from Open-Meteo without an API key. Advice is explainable and tied to the displayed readings; it does not invent pollutant values.

## Tech stack

- Flutter / Dart Android app
- Open-Meteo weather and air-quality APIs
- On-device explainable decision engine
- Planned: official CPCB station-ingestion backend and model training on real station history

## Roadmap

1. Add CPCB station observations through a protected backend.
2. Train and validate a 72-hour location-specific model from real historical data.
3. Add opt-in alerts, profile-based guidance and authenticated sync.
