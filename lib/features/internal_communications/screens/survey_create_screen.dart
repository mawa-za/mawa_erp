import 'package:flutter/material.dart';
import '../models/survey.dart';
import '../services/survey_service.dart';

class SurveyCreateScreen extends StatefulWidget {
  const SurveyCreateScreen({super.key});

  @override
  State<SurveyCreateScreen> createState() => _SurveyCreateScreenState();
}

class _SurveyCreateScreenState extends State<SurveyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SurveyService();
  bool _isSubmitting = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  SurveyType _selectedType = SurveyType.pulse;
  final List<SurveyQuestion> _questions = [];

  void _addQuestion() {
    setState(() {
      _questions.add(SurveyQuestion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '',
        type: QuestionType.rating,
      ));
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one question')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'type': _selectedType.name.toUpperCase(),
        'status': 'ACTIVE',
        'questions': _questions.map((q) => q.toJson()).toList(),
      };

      await _service.createSurvey(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Survey created and distributed'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Create Survey'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<SurveyType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Survey Type', border: OutlineInputBorder()),
              items: SurveyType.values.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type.name.toUpperCase()),
              )).toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Survey Title', border: OutlineInputBorder()),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('QUESTIONS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Question'),
                ),
              ],
            ),
            const Divider(),
            ..._questions.asMap().entries.map((entry) => _buildQuestionEditor(entry.key, entry.value)),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('CREATE & DISTRIBUTE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionEditor(int index, SurveyQuestion question) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<QuestionType>(
                    value: question.type,
                    isDense: true,
                    underline: const SizedBox(),
                    items: QuestionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _questions[index] = SurveyQuestion(
                          id: question.id,
                          text: question.text,
                          type: val!,
                        );
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => setState(() => _questions.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: question.text,
              decoration: const InputDecoration(hintText: 'Enter question text...', border: InputBorder.none),
              onChanged: (val) {
                _questions[index] = SurveyQuestion(
                  id: question.id,
                  text: val,
                  type: question.type,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
