import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/legal_practice_service.dart';

class LegalPracticeScreen extends StatefulWidget {
  final String? resource;
  final String title;
  const LegalPracticeScreen({super.key, this.resource, this.title='Legal Practice'});
  @override State<LegalPracticeScreen> createState()=>_LegalPracticeScreenState();
}
class _LegalPracticeScreenState extends State<LegalPracticeScreen> {
  final _service=LegalPracticeService(); bool _loading=true; dynamic _data;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async { setState(()=>_loading=true); try { _data=widget.resource==null?await _service.dashboard():await _service.list(widget.resource!); } finally { if(mounted)setState(()=>_loading=false); } }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar: AppBar(title: Text(widget.title),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh))]),
    body:_loading?const Center(child:CircularProgressIndicator()):widget.resource==null?_dashboard():_records(),
  );
  Widget _dashboard() {
    final d = Map<String, dynamic>.from(_data ?? {});
    final cards = <String, String>{
      'Open matters': 'openMatters',
      'Open intakes': 'openIntakes',
      'Pending conflicts': 'pendingConflicts',
      'Hearings – next 30 days': 'upcomingHearings',
      'Documents awaiting completion': 'draftDocuments',
      'Trust reconciliations open': 'unreconciledTrust',
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards.entries
              .map(
                (e) => SizedBox(
                  width: 250,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key),
                          const SizedBox(height: 8),
                          Text(
                            '${d[e.value] ?? 0}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Matter register'),
            subtitle: const Text('Open and manage all legal matters'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/cases'),
          ),
        ),
      ],
    );
  }
  Widget _records(){ final rows=(_data as List?)?.cast<Map<String,dynamic>>()??[]; if(rows.isEmpty)return Center(child:Text('No ${widget.title.toLowerCase()} records yet.')); return ListView.separated(padding:const EdgeInsets.all(16),itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(context,i){final r=rows[i]; final title=r['title']??r['prospective_client_name']??r['case_number']??r['subject']??r['search_terms']??r['id']; final status=r['status']??r['result']??r['team_role']??''; return Card(child:ListTile(title:Text('$title'),subtitle:status.toString().isEmpty?null:Text('$status'),trailing:const Icon(Icons.chevron_right)));}); }
}
