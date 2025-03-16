import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class Mainpage extends StatefulWidget {
  const Mainpage({super.key});

  @override
  State<Mainpage> createState() => _MainpageState();
}

class _MainpageState extends State<Mainpage> {
  final TextEditingController _urlcontroller = TextEditingController();
  
  final apikey = dotenv.env['API_KEY']!;
  bool isDownloading = false;
  double downloadProgress = 0.0;

  Future<Map<String, dynamic>> getDownloadData(String url) async {
    final response = await http.post(
      Uri.parse(
          'https://social-download-all-in-one.p.rapidapi.com/v1/social/autolink'),
      headers: {
        'Content-Type': 'application/json',
        'X-RapidAPI-Key': apikey,
        'X-RapidAPI-Host': 'social-download-all-in-one.p.rapidapi.com',
      },
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode != 200) {
      throw 'Error: ${response.statusCode} - ${response.body}';
    }
    return jsonDecode(response.body);
  }

Future<void> requestPermissions() async {
  if (Platform.isAndroid) {
    if (Platform.version.startsWith('13') || Platform.version.startsWith('14')) {
      var videoStatus = await Permission.videos.request();
      if (!videoStatus.isGranted) {
        await showPermissionDialog();
      }
    } else {
      var storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        await showPermissionDialog();
      }
    }
  }
}


  Future<void> showPermissionDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
            'This app needs storage permission to save videos. Please grant it in app settings.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  
Future<void> downloadVideo(String videoUrl) async {
  try {
    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    final dir = Directory('/storage/emulated/0/Download');
    final filePath = "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4";

    await Dio().download(
      videoUrl,
      filePath,
      onReceiveProgress: (received, total) {
        if (total != -1) {
          setState(() {
            downloadProgress = received / total;
          });
        }
      },
    );

    setState(() {
      isDownloading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Video downloaded to: $filePath")),
    );
  } catch (e) {
    setState(() {
      isDownloading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Download failed: $e")),
    );
  }
}

  void fetchUrl() async {
    final url = _urlcontroller.text.trim();
    if (url.isNotEmpty) {
      try {
        final data = await getDownloadData(url);
        final videoUrl = data['medias']?[0]['url'];

        if (videoUrl != null) {
          await downloadVideo(videoUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No video URL found")));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter a valid URL")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Downloader'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Paste URL Here:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            TextField(
              controller: _urlcontroller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30))),
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                onPressed: isDownloading ? null : fetchUrl,
                child: const Text("Download Video"),
              ),
            ),
            if (isDownloading) ...[
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const Text("Downloading..."),
                    LinearProgressIndicator(value: downloadProgress),
                  ],
                ),
              )
            ],
          ],
        ),
      ),
    );
  }
}
