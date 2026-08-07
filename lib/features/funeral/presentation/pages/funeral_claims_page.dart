import 'package:flutter/material.dart';
import '../../data/funeral_api.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../widgets/funeral_claim_card.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class FuneralClaimsPage extends StatefulWidget {
  final String serviceRequestId;

  const FuneralClaimsPage({super.key, required this.serviceRequestId});

  @override
  State<FuneralClaimsPage> createState() => _FuneralClaimsPageState();
}

class _FuneralClaimsPageState extends State<FuneralClaimsPage> {
  final _api = FuneralApi();
  List<FuneralClaimDto> _claims = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    setState(() => _isLoading = true);
    try {
      final claims = await _api.getClaims(widget.serviceRequestId);
      setState(() {
        _claims = claims;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error loading claims: $e'))));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Funeral Claims'),
        actions: [
          IconButton(onPressed: _loadClaims, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _claims.isEmpty
              ? const Center(child: Text('No claims found for this request.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _claims.length,
                  itemBuilder: (context, index) {
                    return FuneralClaimCard(claim: _claims[index]);
                  },
                ),
    );
  }
}
