# Delhi-NCR Air Quality Intelligence — Android

This is a Flutter Android MVP using **only live provider data**. It needs no API key to run: weather and air-quality forecasts come from Open-Meteo. It deliberately does not generate placeholder AQI values.

## Included

- AirWise product branding and a live-data personal advisor
- Delhi, Noida, Gurugram, Ghaziabad and Faridabad selector
- Current PM2.5, PM10, NO₂, O₃ and US AQI
- Live 72-hour air-quality forecast chart
- Coupled weather context (temperature, humidity and wind)
- Threshold early warning at forecast AQI 151+
- Health guidance appropriate to the air-quality band, including "Can I go out?", mask, and cleaner-time answers

## Run it on Android

1. Install the current Flutter SDK and Android Studio.
2. In this folder, run `flutter create . --platforms=android` once. This generates the standard Android launcher files without replacing `lib/main.dart`.
3. Run `flutter pub get`.
4. Connect an Android phone with USB debugging enabled (or start an emulator), then run `flutter run`.

## Production data plan

The included zero-key provider gives live model data. For official Delhi station observations, add a server-side CPCB / data.gov.in connector when an API key is available; never put that key inside the Android binary. The AI forecaster should train on accumulated real 15-minute or hourly station observations together with weather features. Until enough history exists, retain the provider’s live forecast and label it as the baseline—as the app does now.

## Zero-cost public launch

Use a public GitHub repository to host the source code and GitHub Releases to publish an APK. GitHub Pages can host a Flutter web build as a shareable hackathon demo. No data API key is needed for the included live Open-Meteo source.

## Next production upgrades

- A small secure backend to ingest CPCB readings and retain time-series history
- Forecast model (LightGBM/XGBoost first, then sequence model if justified) and evaluation by location
- Android background notifications for persistent AQI alerts
- Station map and source/last-observed timestamps
