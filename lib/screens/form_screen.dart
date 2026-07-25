import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/skill_suggestions.dart';
import '../models/resume_data.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'template_screen.dart';

class FormScreen extends StatefulWidget {
  final ResumeData resumeData;
  const FormScreen({super.key, required this.resumeData});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  int _step = 0;
  late ResumeData data;

  @override
  void initState() {
    super.initState();
    data = widget.resumeData;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kResumeStorageKey, data.encode());
  }

  void _next() {
    _save();
    if (_step < 3) {
      setState(() => _step++);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TemplateScreen(resumeData: data)),
      );
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Personal Info', 'Experience', 'Education', 'Skills'];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text(steps[_step]),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(step: _step, total: steps.length),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: IndexedStack(
                  index: _step,
                  children: [
                    _PersonalInfoStep(data: data),
                    _ExperienceStep(data: data),
                    _EducationStep(data: data),
                    _SkillsStep(data: data),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_step < 3 ? 'Continue' : 'Choose Template'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(total, (i) {
          final active = i <= step;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 4,
              decoration: BoxDecoration(
                color: active ? AppColors.gold : const Color(0xFFE1E4E8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------- Step 1: Personal Info ----------
// StatefulWidget so each keystroke only rebuilds this step's own subtree
// (via the field's local TextEditingController) instead of bubbling a
// setState up to FormScreen, which would rebuild every step in the
// IndexedStack on every character typed.
class _PersonalInfoStep extends StatefulWidget {
  final ResumeData data;
  const _PersonalInfoStep({required this.data});

  @override
  State<_PersonalInfoStep> createState() => _PersonalInfoStepState();
}

class _PersonalInfoStepState extends State<_PersonalInfoStep> {
  late final _controllers = <String, TextEditingController>{
    'fullName': TextEditingController(text: widget.data.personalInfo.fullName),
    'jobTitle': TextEditingController(text: widget.data.personalInfo.jobTitle),
    'email': TextEditingController(text: widget.data.personalInfo.email),
    'phone': TextEditingController(text: widget.data.personalInfo.phone),
    'location': TextEditingController(text: widget.data.personalInfo.location),
    'summary': TextEditingController(text: widget.data.personalInfo.summary),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 82,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => widget.data.personalInfo.photoBase64 = base64Encode(bytes));
  }

  void _removePhoto() {
    setState(() => widget.data.personalInfo.photoBase64 = '');
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.data.personalInfo;
    return ListView(
      children: [
        Center(
          child: _PhotoPicker(
            photoBase64: info.photoBase64,
            onPick: _pickPhoto,
            onRemove: _removePhoto,
          ),
        ),
        const SizedBox(height: 24),
        _field('Full Name', _controllers['fullName']!, (v) => info.fullName = v),
        _field('Job Title', _controllers['jobTitle']!, (v) => info.jobTitle = v),
        _field('Email', _controllers['email']!, (v) => info.email = v),
        _field('Phone', _controllers['phone']!, (v) => info.phone = v),
        _field('Location', _controllers['location']!, (v) => info.location = v),
        _field('Professional Summary', _controllers['summary']!, (v) => info.summary = v, maxLines: 4),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, Function(String) onSave, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        onChanged: onSave,
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final String photoBase64;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _PhotoPicker({required this.photoBase64, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoBase64.isNotEmpty;
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onPick,
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.slate100,
                backgroundImage: hasPhoto ? MemoryImage(base64Decode(photoBase64)) : null,
                child: hasPhoto
                    ? null
                    : const Icon(Icons.add_a_photo_outlined, color: AppColors.slate400, size: 26),
              ),
            ),
            if (hasPhoto)
              Positioned(
                right: -4,
                bottom: -4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 15, color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hasPhoto ? 'Tap photo to change' : 'Add a photo (optional)',
          style: const TextStyle(color: AppColors.slate600, fontSize: 12),
        ),
        const Text(
          'Only shown on the Modern template',
          style: TextStyle(color: AppColors.slate400, fontSize: 10.5),
        ),
      ],
    );
  }
}

// ---------- Step 2: Experience ----------
// StatefulWidget only to own the add/delete rebuild locally; typing inside
// a card never reaches this widget (see _ExperienceCard).
class _ExperienceStep extends StatefulWidget {
  final ResumeData data;
  const _ExperienceStep({required this.data});

  @override
  State<_ExperienceStep> createState() => _ExperienceStepState();
}

class _ExperienceStepState extends State<_ExperienceStep> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ...widget.data.experience.map((e) => _ExperienceCard(
              key: ValueKey(e.id),
              entry: e,
              onDelete: () => setState(() => widget.data.experience.remove(e)),
            )),
        const SizedBox(height: 8),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E4E8)),
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
            decoration: const InputDecoration(labelText: 'Job Title'),
            onChanged: (v) => entry.role = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _company,
            decoration: const InputDecoration(labelText: 'Company'),
            onChanged: (v) => entry.company = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startDate,
                  decoration: const InputDecoration(labelText: 'Start (e.g. Jan 2022)'),
                  onChanged: (v) => entry.startDate = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _endDate,
                  decoration: const InputDecoration(labelText: 'End (or Present)'),
                  onChanged: (v) => entry.endDate = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Key Responsibilities / Achievements'),
            onChanged: (v) => entry.description = v,
          ),
        ],
      ),
    );
  }
}

// ---------- Step 3: Education ----------
class _EducationStep extends StatefulWidget {
  final ResumeData data;
  const _EducationStep({required this.data});

  @override
  State<_EducationStep> createState() => _EducationStepState();
}

class _EducationStepState extends State<_EducationStep> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ...widget.data.education.map((e) => _EducationCard(
              key: ValueKey(e.id),
              entry: e,
              onDelete: () => setState(() => widget.data.education.remove(e)),
            )),
        const SizedBox(height: 8),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E4E8)),
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
            decoration: const InputDecoration(labelText: 'Degree / Program'),
            onChanged: (v) => entry.degree = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _school,
            decoration: const InputDecoration(labelText: 'School / University'),
            onChanged: (v) => entry.school = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startDate,
                  decoration: const InputDecoration(labelText: 'Start Year'),
                  onChanged: (v) => entry.startDate = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _endDate,
                  decoration: const InputDecoration(labelText: 'End Year'),
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

// ---------- Step 4: Skills ----------
class _SkillsStep extends StatefulWidget {
  final ResumeData data;
  const _SkillsStep({required this.data});

  @override
  State<_SkillsStep> createState() => _SkillsStepState();
}

class _SkillsStepState extends State<_SkillsStep> {
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
                    decoration: const InputDecoration(labelText: 'Add a skill (e.g. Project Management)'),
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
              style: IconButton.styleFrom(backgroundColor: AppColors.slate900),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.data.skills
                  .map((s) => Chip(
                        label: Text(s),
                        backgroundColor: AppColors.goldLight.withValues(alpha: 0.4),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() => widget.data.skills.remove(s));
                        },
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
