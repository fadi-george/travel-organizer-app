import 'package:flutter/material.dart';

class FlightOptionsSheet extends StatelessWidget {
  final String tripId;

  const FlightOptionsSheet({super.key, required this.tripId});

  static void show(BuildContext context, {required String tripId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FlightOptionsSheet(tripId: tripId),
    );
  }

  void _onAddFlightManually(BuildContext context) {
    Navigator.pop(context);
    // TODO: Navigate to manual flight form
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Manual flight form coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onUploadFlightPdf(BuildContext context) {
    Navigator.pop(context);
    // TODO: Implement PDF upload and extraction
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF upload coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Flight',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: Colors.blue),
              ),
              title: const Text('Add Manually'),
              subtitle: const Text('Enter flight details by hand'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onAddFlightManually(context),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.upload_file, color: Colors.orange),
              ),
              title: const Text('Upload Flight Info (PDF)'),
              subtitle: const Text('Extract details from confirmation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onUploadFlightPdf(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

