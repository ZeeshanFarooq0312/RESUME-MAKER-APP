import 'package:flutter/material.dart';
import '../data/skill_suggestions.dart';
import '../models/resume_data.dart';
import '../services/account_repository.dart';
import '../services/profile_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/accordion_section.dart';

/// Local profile form: name, title, contact info, experience, education,
/// and skills, saved under a single SharedPreferences key via
/// [ProfileRepository]. This is the source of truth the AI resume-tailoring
/// feature reads from — there's no server involved, it's stored on this
/// device exactly like every other document in the app.
///
/// Doubles as the app's mandatory onboarding step when [onboarding] is true
/// (shown right after Sign Up / Log In, before the user ever reaches Home):
/// no back button, "Continue" instead of "Save Profile". Completing it only
/// flips [AccountSession.onboardingComplete] rather than navigating directly
/// — `AuthGate` is what's watching that and swaps itself to `AppShell` in
/// place, consistent with how the rest of the auth flow avoids Navigator.
class ProfileScreen extends StatefulWidget {
  final bool onboarding;
  const ProfileScreen({super.key, this.onboarding = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ResumeData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await ProfileRepository.load();
    if (mounted) setState(() => _data = loaded ?? ResumeData());
  }

  Future<void> _save() async {
    final data = _data;
    if (data == null) return;
    await ProfileRepository.save(data);
  }

  Future<void> _onBack() async {
    await _save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onSavePressed() async {
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    }
  }

  Future<void> _onContinuePressed() async {
    final data = _data;
    if (data == null) return;
    if (data.personalInfo.fullName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your name to continue.')),
      );
      return;
    }
    await _save();
    await AccountRepository.markOnboardingComplete();
    AccountSession.onboardingComplete.value = true;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final onboarding = widget.onboarding;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !onboarding,
        leading: onboarding
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        title: Text(onboarding ? 'Complete Your Profile' : 'My Profile'),
      ),
      body: SafeArea(
        child: data == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      onboarding
                          ? 'One-time setup — this powers AI resume tailoring later on. Stored '
                              'only on this device, never uploaded except when you explicitly '
                              'generate a tailored resume.'
                          : 'Used only to power AI resume tailoring — stored locally, never uploaded '
                              'except when you explicitly generate a tailored resume.',
                      style: const TextStyle(color: AppColors.slate800, fontSize: 12.5, height: 1.4),
                    ),
                  ),
                  AccordionSection(
                    title: 'Personal Info',
                    initiallyExpanded: true,
                    child: _PersonalInfoFields(data: data),
                  ),
                  AccordionSection(title: 'Summary', child: _SummaryField(data: data)),
                  AccordionSection(title: 'Experience', child: _ExperienceSection(data: data)),
                  AccordionSection(title: 'Education', child: _EducationSection(data: data)),
                  AccordionSection(title: 'Skills', child: _SkillsSection(data: data)),
                ],
              ),
      ),
      bottomNavigationBar: data == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onboarding ? _onContinuePressed : _onSavePressed,
                    child: Text(onboarding ? 'Continue' : 'Save Profile'),
                  ),
                ),
              ),
            ),
    );
  }
}

// ---------- Personal Info ----------
class _PersonalInfoFields extends StatefulWidget {
  final ResumeData data;
  const _PersonalInfoFields({required this.data});

  @override
  State<_PersonalInfoFields> createState() => _PersonalInfoFieldsState();
}

class _PersonalInfoFieldsState extends State<_PersonalInfoFields> {
  late final _controllers = <String, TextEditingController>{
    'fullName': TextEditingController(text: widget.data.personalInfo.fullName),
    'jobTitle': TextEditingController(text: widget.data.personalInfo.jobTitle),
    'email': TextEditingController(text: widget.data.personalInfo.email),
    'phone': TextEditingController(text: widget.data.personalInfo.phone),
    'location': TextEditingController(text: widget.data.personalInfo.location),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.data.personalInfo;
    return Column(
      children: [
        _field('Full Name', _controllers['fullName']!, (v) => info.fullName = v),
        _field('Job Title', _controllers['jobTitle']!, (v) => info.jobTitle = v),
        _field('Email', _controllers['email']!, (v) => info.email = v),
        _field('Phone', _controllers['phone']!, (v) => info.phone = v),
        _field('Location', _controllers['location']!, (v) => info.location = v, isLast: true),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, Function(String) onSave,
      {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        onChanged: onSave,
      ),
    );
  }
}

// ---------- Summary ----------
class _SummaryField extends StatefulWidget {
  final ResumeData data;
  const _SummaryField({required this.data});

  @override
  State<_SummaryField> createState() => _SummaryFieldState();
}

class _SummaryFieldState extends State<_SummaryField> {
  late final _controller = TextEditingController(text: widget.data.personalInfo.summary);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      maxLines: 4,
      decoration: const InputDecoration(labelText: 'Professional Summary'),
      onChanged: (v) => widget.data.personalInfo.summary = v,
    );
  }
}

// ---------- Experience ----------
class _ExperienceSection extends StatefulWidget {
  final ResumeData data;
  const _ExperienceSection({required this.data});

  @override
  State<_ExperienceSection> createState() => _ExperienceSectionState();
}

class _ExperienceSectionState extends State<_ExperienceSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...widget.data.experience.map((e) => _ExperienceCard(
              key: ValueKey(e.id),
              entry: e,
              onDelete: () => setState(() => widget.data.experience.remove(e)),
            )),
        OutlinedButton.icon(
          onPressed: () => setState(() => widget.data.experience.add(ExperienceEntry())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Work Experience'),
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatefulWidget {
  final ExperienceEntry entry;
  final VoidCallback onDelete;
  const _ExperienceCard({super.key, required this.entry, required this.onDelete});

  @override
  State<_ExperienceCard> createState() => _ExperienceCardState();
}

class _ExperienceCardState extends State<_ExperienceCard> {
  late final _role = TextEditingController(text: widget.entry.role);
  late final _company = TextEditingController(text: widget.entry.company);
  late final _startDate = TextEditingController(text: widget.entry.startDate);
  late final _endDate = TextEditingController(text: widget.entry.endDate);
  late final _description = TextEditingController(text: widget.entry.description);

  @override
  void dispose() {
    _role.dispose();
    _company.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5F3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.slate400, size: 20),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          TextFormField(
            controller: _role,
            decoration: const InputDecoration(labelText: 'Job Title', filled: true, fillColor: Colors.white),
            onChanged: (v) => entry.role = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _company,
            decoration: const InputDecoration(labelText: 'Company', filled: true, fillColor: Colors.white),
            onChanged: (v) => entry.company = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startDate,
                  decoration: const InputDecoration(
                      labelText: 'Start (e.g. Jan 2022)', filled: true, fillColor: Colors.white),
                  onChanged: (v) => entry.startDate = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _endDate,
                  decoration: const InputDecoration(
                      labelText: 'End (or Present)', filled: true, fillColor: Colors.white),
                  onChanged: (v) => entry.endDate = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Key Responsibilities / Achievements', filled: true, fillColor: Colors.white),
            onChanged: (v) => entry.description = v,
          ),
        ],
      ),
    );
  }
}

// ---------- Education ----------
class _EducationSection extends StatefulWidget {
  final ResumeData data;
  const _EducationSection({required this.data});

  @override
  State<_EducationSection> createState() => _EducationSectionState();
}

class _EducationSectionState extends State<_EducationSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...widget.data.education.map((e) => _EducationCard(
              key: ValueKey(e.id),
              entry: e,
              onDelete: () => setState(() => widget.data.education.remove(e)),
            )),
        OutlinedButton.icon(
          onPressed: () => setState(() => widget.data.education.add(EducationEntry())),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Education'),
        ),
      ],
    );
  }
}

class _EducationCard extends StatefulWidget {
  final EducationEntry entry;
  final VoidCallback onDelete;
  const _EducationCard({super.key, required this.entry, required this.onDelete});

  @override
  State<_EducationCard> createState() => _EducationCardState();
}

class _EducationCardState extends State<_EducationCard> {
  late final _degree = TextEditingController(text: widget.entry.degree);
  late final _school = TextEditingController(text: widget.entry.school);
  late final _startDate = TextEditingController(text: widget.entry.startDate);
  late final _endDate = TextEditingController(text: widget.entry.endDate);

  @override
  void dispose() {
    _degree.dispose();
    _school.dispose();
    _startDate.dispose();
    _endDate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E5F3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.slate400, size: 20),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          TextFormField(
            controller: _degree,
            decoration:
                const InputDecoration(labelText: 'Degree / Program', filled: true, fillColor: Colors.white),
            onChanged: (v) => entry.degree = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _school,
            decoration: const InputDecoration(
                labelText: 'School / University', filled: true, fillColor: Colors.white),
            onChanged: (v) => entry.school = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startDate,
                  decoration:
                      const InputDecoration(labelText: 'Start Year', filled: true, fillColor: Colors.white),
                  onChanged: (v) => entry.startDate = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _endDate,
                  decoration:
                      const InputDecoration(labelText: 'End Year', filled: true, fillColor: Colors.white),
                  onChanged: (v) => entry.endDate = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Skills ----------
class _SkillsSection extends StatefulWidget {
  final ResumeData data;
  const _SkillsSection({required this.data});

  @override
  State<_SkillsSection> createState() => _SkillsSectionState();
}

class _SkillsSectionState extends State<_SkillsSection> {
  TextEditingController? _fieldController;

  void _addSkill([String? skill]) {
    final text = (skill ?? _fieldController?.text ?? '').trim();
    if (text.isNotEmpty && !widget.data.skills.contains(text)) {
      setState(() {
        widget.data.skills.add(text);
      });
      _fieldController?.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue value) {
                  final query = value.text.trim().toLowerCase();
                  if (query.isEmpty) return const Iterable<String>.empty();
                  return kSkillSuggestions.where((s) =>
                      s.toLowerCase().contains(query) &&
                      !widget.data.skills.contains(s));
                },
                onSelected: _addSkill,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  _fieldController = controller;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration:
                        const InputDecoration(labelText: 'Add a skill (e.g. Project Management)'),
                    onFieldSubmitted: (_) => _addSkill(),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260, maxWidth: 360),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () => _addSkill(),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.data.skills
              .map((s) => Chip(
                    label: Text(s),
                    backgroundColor: AppColors.primaryLight,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => widget.data.skills.remove(s));
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }
}
