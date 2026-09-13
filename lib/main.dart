import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() => runApp(const DelhiAirApp());

class DelhiAirApp extends StatelessWidget {
  const DelhiAirApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'KYRO',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006D77)),
          useMaterial3: true,
        ),
        home: const AirHome(),
      );
}

class Place {
  const Place(this.name, this.lat, this.lon);
  final String name;
  final double lat, lon;
}

const places = [
  Place('Delhi', 28.6139, 77.2090),
  Place('Noida', 28.5355, 77.3910),
  Place('Gurugram', 28.4595, 77.0266),
  Place('Ghaziabad', 28.6692, 77.4538),
  Place('Faridabad', 28.4089, 77.3178),
];

class AirSnapshot {
  AirSnapshot({required this.place, required this.updatedAt, required this.pm25, required this.pm10, required this.no2, required this.o3, required this.usAqi, required this.temp, required this.humidity, required this.wind, required this.hours});
  final Place place;
  final DateTime updatedAt;
  final double pm25, pm10, no2, o3, temp, humidity, wind;
  final int usAqi;
  final List<HourPoint> hours;
}

class HourPoint {
  HourPoint(this.time, this.aqi, this.pm25, this.temp, this.wind, this.rainChance);
  final DateTime time;
  final int aqi;
  final double pm25, temp, wind;
  final int rainChance;
}

class LiveDataService {
  static Future<Map<String, dynamic>> _json(Uri uri) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('Data service returned ${res.statusCode}');
      return jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<AirSnapshot> load(Place place) async {
    final q = {'latitude': '${place.lat}', 'longitude': '${place.lon}', 'timezone': 'Asia/Kolkata', 'forecast_days': '4'};
    final air = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      ...q,
      'current': 'pm10,pm2_5,nitrogen_dioxide,ozone,us_aqi',
      'hourly': 'pm2_5,us_aqi',
    });
    final weather = Uri.https('api.open-meteo.com', '/v1/forecast', {
      ...q,
      'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m',
      'hourly': 'temperature_2m,wind_speed_10m,precipitation_probability',
    });
    final results = await Future.wait([_json(air), _json(weather)]);
    final a = results[0], w = results[1];
    final ah = a['hourly'] as Map<String, dynamic>, wh = w['hourly'] as Map<String, dynamic>;
    final times = (ah['time'] as List).cast<String>();
    final now = DateTime.now();
    final points = <HourPoint>[];
    for (var i = 0; i < times.length && points.length < 72; i++) {
      final time = DateTime.parse(times[i]);
      if (time.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      points.add(HourPoint(time, _i(ah['us_aqi'][i]), _d(ah['pm2_5'][i]), _d(wh['temperature_2m'][i]), _d(wh['wind_speed_10m'][i]), _i(wh['precipitation_probability'][i])));
    }
    final c = a['current'] as Map<String, dynamic>, cw = w['current'] as Map<String, dynamic>;
    return AirSnapshot(place: place, updatedAt: DateTime.now(), pm25: _d(c['pm2_5']), pm10: _d(c['pm10']), no2: _d(c['nitrogen_dioxide']), o3: _d(c['ozone']), usAqi: _i(c['us_aqi']), temp: _d(cw['temperature_2m']), humidity: _d(cw['relative_humidity_2m']), wind: _d(cw['wind_speed_10m']), hours: points);
  }

  static double _d(dynamic v) => v is num ? v.toDouble() : 0;
  static int _i(dynamic v) => v is num ? v.round() : 0;
}

class AirHome extends StatefulWidget {
  const AirHome({super.key});
  @override
  State<AirHome> createState() => _AirHomeState();
}

class _AirHomeState extends State<AirHome> {
  final service = LiveDataService();
  Place place = places.first;
  late Future<AirSnapshot> data = service.load(place);
  void refresh() => setState(() => data = service.load(place));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('KYRO • Delhi-NCR'), actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh live data')]),
        body: FutureBuilder<AirSnapshot>(
          future: data,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return _Error(message: '${snap.error}', retry: refresh);
            return _Dashboard(data: snap.requireData, selected: place, onPlace: (p) { setState(() { place = p; data = service.load(p); }); });
          },
        ),
      );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.data, required this.selected, required this.onPlace});
  final AirSnapshot data;
  final Place selected;
  final ValueChanged<Place> onPlace;
  @override
  Widget build(BuildContext context) {
    final risk = Risk.fromAqi(data.usAqi);
    final peak = data.hours.isEmpty ? data.usAqi : data.hours.map((x) => x.aqi).reduce((a, b) => a > b ? a : b);
    return RefreshIndicator(
      onRefresh: () async {
        onPlace(selected);
      },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Forecast. Protect. Breathe.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('KYRO uses live weather and pollution intelligence for safer daily decisions.'),
        const SizedBox(height: 16),
        DropdownButtonFormField<Place>(value: selected, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder()), items: places.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(), onChanged: (p) { if (p != null) onPlace(p); }),
        const SizedBox(height: 16),
        Card(color: risk.color, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${data.usAqi}', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('US AQI • ${risk.label}', style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8), Text(risk.advice, style: const TextStyle(color: Colors.white)),
        ]))),
        Text('Live update: ${_stamp(data.updatedAt)}', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        Row(children: [Metric('PM2.5', '${data.pm25.toStringAsFixed(1)} µg/m³'), Metric('PM10', '${data.pm10.toStringAsFixed(1)} µg/m³')]),
        Row(children: [Metric('NO₂', '${data.no2.toStringAsFixed(1)} µg/m³'), Metric('O₃', '${data.o3.toStringAsFixed(1)} µg/m³')]),
        const SizedBox(height: 16),
        Text('72-hour air-quality outlook', style: Theme.of(context).textTheme.titleLarge),
        const Text('Live model forecast; not simulated values.'),
        const SizedBox(height: 10), SizedBox(height: 170, child: AqiChart(data.hours)),
        const SizedBox(height: 12),
        Card(child: ListTile(leading: Icon(peak >= 151 ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: peak >= 151 ? Colors.orange : Colors.green), title: Text(peak >= 151 ? 'Early warning: unhealthy air is likely' : 'No unhealthy AQI peak forecast'), subtitle: Text('Highest forecast AQI in the next 72 hours: $peak. Alerts activate at AQI 151+.'),)),
        const SizedBox(height: 8),
        Text('Weather–pollution coupling', style: Theme.of(context).textTheme.titleLarge),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('Now: ${data.temp.toStringAsFixed(1)}°C • ${data.humidity.toStringAsFixed(0)}% humidity • ${data.wind.toStringAsFixed(1)} km/h wind. ${data.wind < 8 ? 'Low wind may allow pollutants to accumulate.' : 'Wind is helping disperse pollutants.'}'))),
        const SizedBox(height: 8),
        AirWiseAdvisor(data: data),
        const SizedBox(height: 8),
        const Text('Data: Open-Meteo live weather and air-quality model feeds. Add the optional official CPCB adapter after obtaining a data.gov.in API key.'),
      ]),
    );
  }
  String _stamp(DateTime d) => '${d.day}/${d.month}/${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} IST';
}

class AirWiseAdvisor extends StatefulWidget {
  const AirWiseAdvisor({required this.data, super.key});
  final AirSnapshot data;
  @override
  State<AirWiseAdvisor> createState() => _AirWiseAdvisorState();
}

class _AirWiseAdvisorState extends State<AirWiseAdvisor> {
  final input = TextEditingController();
  String question = 'Can I go outside today?';
  @override
  void dispose() { input.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFE8F5F3),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const CircleAvatar(child: Icon(Icons.auto_awesome)), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Ask KYRO', style: Theme.of(context).textTheme.titleLarge), const Text('Live-data health advisor')])]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in ['Can I go outside today?', 'Do I need a mask?', 'When will air be cleanest?'])
            ActionChip(label: Text(q), onPressed: () => setState(() => question = q)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: input, decoration: InputDecoration(hintText: 'Ask about today’s air…', suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: () { if (input.text.trim().isNotEmpty) setState(() => question = input.text.trim()); })), onSubmitted: (v) { if (v.trim().isNotEmpty) setState(() => question = v.trim()); }),
        const SizedBox(height: 12),
        Text(question, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(_answer(question, widget.data)),
        const SizedBox(height: 8),
        const Text('Guidance uses the live AQI and forecast; it is not medical advice.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    ),
  );

  String _answer(String q, AirSnapshot d) {
    final lower = q.toLowerCase();
    final outlook = d.hours;
    final best = outlook.isEmpty ? null : outlook.reduce((a, b) => a.aqi < b.aqi ? a : b);
    final level = Risk.fromAqi(d.usAqi);
    if (lower.contains('clean') || lower.contains('when')) {
      if (best == null) return 'The live forecast is still loading. Please refresh in a moment.';
      return 'The lowest forecast AQI is ${best.aqi} around ${_time(best.time)}. ${best.aqi <= 100 ? 'That is your better outdoor window.' : 'Air quality remains elevated, so keep outdoor activity short.'}';
    }
    if (lower.contains('mask')) {
      return d.usAqi > 100 ? 'Yes. AQI ${d.usAqi} is ${level.label.toLowerCase()}; consider a well-fitted N95/KN95 if you must be outdoors for long.' : 'A mask is not generally needed for air pollution at AQI ${d.usAqi}, but follow any personal medical advice.';
    }
    return d.usAqi <= 100
      ? 'Yes, ordinary outdoor activity is reasonable in ${d.place.name}. Current AQI is ${d.usAqi} (${level.label}). Check the cleaner-time suggestion if you are sensitive to pollution.'
      : 'Limit prolonged outdoor activity today. Current AQI is ${d.usAqi} (${level.label}); choose shorter trips and avoid heavy exercise outdoors. ${d.wind < 8 ? 'Low wind may keep pollution trapped.' : 'Wind may improve dispersion later.'}';
  }
  String _time(DateTime d) => '${d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour)} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

class Metric extends StatelessWidget {
  const Metric(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label), const SizedBox(height: 4), Text(value, style: Theme.of(context).textTheme.titleMedium)]))));
}

class AqiChart extends StatelessWidget {
  const AqiChart(this.points, {super.key});
  final List<HourPoint> points;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ChartPainter(points), child: const SizedBox.expand());
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.p); final List<HourPoint> p;
  @override void paint(Canvas c, Size s) {
    if (p.length < 2) return;
    final max = p.map((e) => e.aqi).reduce((a,b) => a > b ? a : b).clamp(100, 300).toDouble();
    final grid = Paint()..color = Colors.grey.shade300..strokeWidth = 1;
    for (var i=1;i<4;i++) c.drawLine(Offset(0, s.height*i/4), Offset(s.width, s.height*i/4), grid);
    final path = Path();
    for (var i=0;i<p.length;i++) { final x=s.width*i/(p.length-1); final y=(s.height-(p[i].aqi/max*s.height).clamp(0, s.height)).toDouble(); i==0 ? path.moveTo(x,y) : path.lineTo(x,y); }
    c.drawPath(path, Paint()..color=const Color(0xFF006D77)..style=PaintingStyle.stroke..strokeWidth=3);
  }
  @override bool shouldRepaint(covariant _ChartPainter old) => old.p != p;
}

class Risk {
  const Risk(this.label, this.color, this.advice); final String label, advice; final Color color;
  static Risk fromAqi(int aqi) {
    if (aqi <= 50) return const Risk('Good', Color(0xFF2E7D32), 'Air quality is satisfactory for outdoor activity.');
    if (aqi <= 100) return const Risk('Moderate', Color(0xFFF9A825), 'Sensitive people may consider reducing prolonged outdoor exertion.');
    if (aqi <= 150) return const Risk('Unhealthy for sensitive groups', Color(0xFFEF6C00), 'Children, older adults and people with respiratory illness should limit outdoor exposure.');
    if (aqi <= 200) return const Risk('Unhealthy', Color(0xFFC62828), 'Limit time outdoors; wear a well-fitting mask if travel is essential.');
    return const Risk('Very unhealthy', Color(0xFF6A1B9A), 'Avoid outdoor activity where possible and keep indoor air filtered.');
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.retry}); final String message; final VoidCallback retry;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off, size: 48), const SizedBox(height: 12), const Text('Live data could not be reached.'), Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: retry, child: const Text('Try again'))])));
}
