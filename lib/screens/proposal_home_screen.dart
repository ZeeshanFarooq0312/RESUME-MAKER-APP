import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/proposal_data.dart';
import '../theme/app_theme.dart';
import 'proposal_form_screen.dart';

const String kProposalStorageKey = 'proposal_data_v1';

class ProposalHomeScreen extends StatefulWidget {
  const ProposalHomeScreen({super.key});

  @override
  State<ProposalHomeScreen> createState() => _ProposalHomeScreenState();
}

class _ProposalHomeScreenState extends State<ProposalHomeScreen> {
  bool _hasExisting = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kProposalStorageKey);
    setState(() {
      _hasExisting = saved != null;
      _loading = false;
    });
  }

  Future<void> _openForm({required bool fresh}) async {
    ProposalData data;
    if (fresh) {
      data = ProposalData();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kProposalStorageKey);
      data = saved != null ? ProposalData.decode(saved) : ProposalData();
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProposalFormScreen(data: data)),
    );
    _checkExisting();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proposal')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.slate900,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.handshake_outlined, color: AppColors.gold, size: 28),
                    ),
                    const SizedBox(height: 24),
                    Text('Proposal', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text(
                      'Pitch a project or business proposal to a client.',
                      style: TextStyle(color: AppColors.slate600, height: 1.4, fontSize: 15),
                    ),
                    const SizedBox(height: 40),
                    if (_hasExisting) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _openForm(fresh: false),
                          child: const Text('Continue My Proposal'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _openForm(fresh: true),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.slate400),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Start a New Proposal'),
                        ),
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _openForm(fresh: true),
                          child: const Text('Create My Proposal'),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
