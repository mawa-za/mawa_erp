import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/survey.dart';
import '../services/survey_service.dart';

class SurveyListScreen extends StatefulWidget {
  const SurveyListScreen({super.key});

  @override
  State<SurveyListScreen> createState() => _SurveyListScreenState();
}

class _SurveyListScreenState extends State<SurveyListScreen> {
  final SurveyService _service = SurveyService();
  bool _isLoading = true;
  List<Survey> _surveys = [];

  @override
  void initState() {
    super.initState();
    _fetchSurveys();
  }

  Future<void> _fetchSurveys() async {
    setState(() => _isLoading = true);
    final results = await _service.getSurveys();
    setState(() {
      _surveys = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Surveys & Feedback'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSurveys,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _surveys.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _surveys.length,
                  itemBuilder: (context, index) {
                    final survey = _surveys[index];
                    return _buildSurveyCard(survey, colorScheme);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // Implementation for creating new survey
        child: const Icon(Icons.add_chart),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.poll_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No surveys found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Create First Survey'),
          ),
        ],
      ),
    );
  }

  Widget _buildSurveyCard(Survey survey, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTypeChip(survey.type),
                  _buildStatusChip(survey.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                survey.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                survey.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('Participants: ${survey.participantCount}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const Spacer(),
                  if (survey.endDate != null)
                    Text(
                      'Ends: ${DateFormat('MMM d').format(survey.endDate!)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(SurveyType type) {
    Color color = Colors.blue;
    if (type == SurveyType.pulse) color = Colors.green;
    if (type == SurveyType.engagement) color = Colors.deepPurple;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusChip(SurveyStatus status) {
    Color color = Colors.grey;
    if (status == SurveyStatus.active) color = Colors.green;
    if (status == SurveyStatus.closed) color = Colors.red;

    return Text(
      status.name.toUpperCase(),
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    );
  }
}
