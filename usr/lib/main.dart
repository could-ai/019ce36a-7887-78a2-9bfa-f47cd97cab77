import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const ShellyApp());
}

class ShellyApp extends StatelessWidget {
  const ShellyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shelly 1 Gen 4 Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const ShellyControllerScreen(),
      },
    );
  }
}

class ShellyControllerScreen extends StatefulWidget {
  const ShellyControllerScreen({super.key});

  @override
  State<ShellyControllerScreen> createState() => _ShellyControllerScreenState();
}

class _ShellyControllerScreenState extends State<ShellyControllerScreen> {
  // Shelly cihazınızın varsayılan IP adresini buraya girebilirsiniz
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.100');
  bool _isLoading = false;
  String _statusMessage = 'Bağlantı bekleniyor...';
  bool? _isOn;

  @override
  void initState() {
    super.initState();
    // Uygulama açıldığında durumu kontrol etmeyi dener
    _checkStatus();
  }

  // Shelly Gen 4 (Plus/Pro/Gen4) cihazları RPC API kullanır
  Future<void> _sendCommand(String command, {bool? on}) async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() => _statusMessage = 'Lütfen bir IP adresi girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'İstek gönderiliyor...';
    });

    try {
      // Shelly RPC API URL yapısı
      String url = 'http://$ip/rpc/$command?id=0';
      if (on != null) {
        url += '&on=$on';
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = 'Komut başarıyla iletildi!';
        });
        // Komut sonrası güncel durumu çek
        await _checkStatus();
      } else {
        setState(() => _statusMessage = 'Hata: HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Bağlantı hatası. Cihaz IP\\'sini kontrol edin.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Rölenin anlık durumunu sorgulama
  Future<void> _checkStatus() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;

    try {
      final response = await http
          .get(Uri.parse('http://$ip/rpc/Switch.GetStatus?id=0'))
          .timeout(const Duration(seconds: 3));
          
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          // Gen 4 RPC API'sinde röle durumu 'output' değişkeninde tutulur
          _isOn = data['output'];
          _statusMessage = 'Bağlantı başarılı.';
        });
      }
    } catch (e) {
      setState(() {
        _isOn = null;
        _statusMessage = 'Cihaza ulaşılamadı.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelly 1 Gen 4 Kontrol'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkStatus,
            tooltip: 'Durumu Yenile',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Shelly Cihaz IP Adresi:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Örn: 192.168.1.100',
                prefixIcon: const Icon(Icons.wifi),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: _checkStatus,
                ),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _checkStatus(),
            ),
            const SizedBox(height: 32),
            
            // Durum Göstergesi
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _isOn == null 
                    ? Colors.grey.withOpacity(0.1) 
                    : (_isOn! ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOn == null 
                      ? Colors.grey 
                      : (_isOn! ? Colors.green : Colors.red),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isOn == null 
                        ? Icons.help_outline 
                        : (_isOn! ? Icons.lightbulb : Icons.lightbulb_outline),
                    color: _isOn == null 
                        ? Colors.grey 
                        : (_isOn! ? Colors.green : Colors.red),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isOn == null 
                        ? 'DURUM BİLİNMİYOR' 
                        : (_isOn! ? 'RÖLE AÇIK (ON)' : 'RÖLE KAPALI (OFF)'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _isOn == null 
                          ? Colors.grey 
                          : (_isOn! ? Colors.green : Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Kontrol Butonları
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _sendCommand('Switch.Set', on: true),
                    icon: const Icon(Icons.power),
                    label: const Text('AÇ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _sendCommand('Switch.Set', on: false),
                    icon: const Icon(Icons.power_off),
                    label: const Text('KAPAT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _sendCommand('Switch.Toggle'),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('DURUMU DEĞİŞTİR (TOGGLE)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Bilgi Mesajı
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
            ),
            
            const Spacer(),
            
            // Uyarı Notu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Not: Bu uygulamanın çalışması için cihazınızın Shelly ile aynı yerel ağda (Wi-Fi) olması gerekir.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}