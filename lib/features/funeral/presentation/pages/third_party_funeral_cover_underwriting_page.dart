import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/api_client.dart';

class ThirdPartyFuneralCoverUnderwritingPage extends StatefulWidget {
  const ThirdPartyFuneralCoverUnderwritingPage({super.key});
  @override
  State<ThirdPartyFuneralCoverUnderwritingPage> createState() => _ThirdPartyFuneralCoverUnderwritingPageState();
}

class _ThirdPartyFuneralCoverUnderwritingPageState extends State<ThirdPartyFuneralCoverUnderwritingPage> {
  List<dynamic> covers = [];

  Future<void> load() async {
    final response = await ApiClient().get('/v2/funeral-underwriting/covers');
    setState(() => covers = jsonDecode(response.body) as List<dynamic>);
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> decide(String id, String status) async {
    await ApiClient().post('/v2/funeral-underwriting/covers/$id/decision', body: {'status': status});
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Third Party Funeral Cover Underwriting')),
      body: ListView(
        children: covers.map((dynamic raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          final cents = (item['cover_amount_cents'] as num?)?.toInt() ?? 0;
          return Card(
            child: ListTile(
              title: Text('${item['external_policy_no']} • ${item['holder_name']}'),
              subtitle: Text('${item['underwriter_name']} • ${item['status']} • R${(cents / 100).toStringAsFixed(2)}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => decide(item['id'].toString(), value),
                itemBuilder: (_) => const ['APPROVED', 'DECLINED', 'SUSPENDED', 'ACTIVE']
                    .map((value) => PopupMenuItem(value: value, child: Text(value)))
                    .toList(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
