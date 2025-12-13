import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrDisplayPage extends StatefulWidget {
  final String qrData;
  final String eventName;
  final String eventDate;
  final String eventLocation;

  const QrDisplayPage({
    super.key,
    required this.qrData,
    required this.eventName,
    required this.eventDate,
    required this.eventLocation,
  });

  @override
  State<QrDisplayPage> createState() => _QrDisplayPageState();
}

class _QrDisplayPageState extends State<QrDisplayPage> {
  final GlobalKey _globalKey = GlobalKey();

  Future<void> _saveTicket() async {
    // Check permission first (gal handles it usually but good to know)
    try {
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }

      // 1. Capture the widget
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0); // High res
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // 2. Save to gallery
        await Gal.putImageBytes(pngBytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(backgroundColor: Colors.green, content: Text("Ticket saved to Gallery!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Error saving ticket: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Ticket'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Save to Gallery',
            onPressed: _saveTicket,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.eventName,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Wrap the Card in RepaintBoundary to capture it
              RepaintBoundary(
                key: _globalKey,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: theme.cardColor, // Ensure background color is captured
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // shrink to fit
                      children: [
                        QrImageView(
                          data: widget.qrData,
                          version: QrVersions.auto,
                          size: 220.0,
                          dataModuleStyle: QrDataModuleStyle(
                            color: isDark ? Colors.white : Colors.black,
                            dataModuleShape: QrDataModuleShape.circle,
                          ),
                          eyeStyle: QrEyeStyle(
                            color: isDark ? Colors.white : Colors.black,
                            eyeShape: QrEyeShape.square,
                          ),
                          backgroundColor: Colors.transparent, // Important for capture
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),
                        _buildInfoRow(theme, Icons.calendar_today, widget.eventDate),
                        const SizedBox(height: 10),
                        _buildInfoRow(theme, Icons.location_on, widget.eventLocation),
                        const SizedBox(height: 10),
                        Text("Scan to Verify", style: theme.textTheme.bodySmall)
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saveTicket,
                icon: const Icon(Icons.save_alt),
                label: const Text("Save Ticket to Gallery"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Present this QR code at the event entrance for scanning.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
