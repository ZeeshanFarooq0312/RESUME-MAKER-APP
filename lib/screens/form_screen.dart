import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../data/skill_suggestions.dart';
import '../models/document_entry.dart';
import '../models/resume_data.dart';
import '../services/ai_usage_tracker.dart';
import '../services/documents_repository.dart';
import '../services/groq_service.dart';
import '../theme/app_theme.dart';
import '../widgets/accordion_section.dart';
import '../widgets/ai_action_button.dart';
import 'paywall_screen.dart';
import 'preview_screen.dart';
import 'template_screen.dart';

const _uuid = Uuid();

void _showAiNotConfiguredDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('AI features not set up'),
      content: const Text("AI features aren't set up on this build. Ask the developer to configure a Groq API key."),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ),
  );
}

void _showAiLimitReachedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Daily AI limit reached'),
      content: const Text(
          "You've used all your AI generations for today. Upgrade for a higher daily limit."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
          },
          child: const Text('View Plans'),
        ),
      ],
    ),
  );
}

void _showAiErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class FormScreen extends StatefulWidget {
  final DocumentEntry? entry;
  final ResumeTemplate? initialTemplate;
  const FormScreen({super.key, this.entry, this.initialTemplate});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  late final String _entryId = widget.entry?.id ?? _uuid.v4();
  late final ResumeData data =
      widget.entry != null ? ResumeData.fromJson(widget.entry!.payload) : ResumeData();

  Future<void> _saveEntry() async {
    await DocumentsRepository.save(DocumentEntry(
      id: _entryId,
      kind: DocumentKind.resume,
      title: data.personalInfo.fullName.isEmpty ? 'My Resume' : data.personalInfo.fullName,
      templateId: widget.initialTemplate?.name ??
          widget.entry?.templateId ??
          ResumeTemplate.classic.name,
      updatedAt: DateTime.now(),
      completionPercent: data.completionPercent,
      payload: data.toJson(),
    ));
  }

  Future<void> _onBack() async {
    await _saveEntry();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onExport() async {
    await _saveEntry();
    if (!mounted) return;
    final template = widget.initialTemplate;
    if (template != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(resumeData: data, template: template, documentId: _entryId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TemplateScreen(resumeData: data, documentId: _entryId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        title: Text(widget.entry == null ? 'New Resume' : 'Edit Resume'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AccordionSection(
              title: 'Personal Data',
              initiallyExpanded: true,
              child: _PersonalDataFields(data: data),
            ),
            AccordionSection(title: 'Summary', child: _SummaryField(data: data)),
            AccordionSection(title: 'Experience', child: _ExperienceSection(data: data)),
            AccordionSection(title: 'Education', child: _EducationSection(data: data)),
            AccordionSection(title: 'Skills', child: _SkillsSection(data: data)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onExport,
              child: const Text('Preview & Export'),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Personal Data ----------
// StatefulWidget so each keystroke only rebuilds this section's own subtree
// via the field's local TextEditingController, never the whole form.
class _PersonalDataFields extends StatefulWidget {
  final ResumeData data;
  const _PersonalDataFields({required this.data});

  @override
  State<_PersonalDataFields> createState() => _PersonalDataFieldsState();
}

class _PersonalDataFieldsState extends State<_PersonalDataFields> {
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
    return Column(
      children: [
        Center(
          child: _PhotoPicker(
            photoBase64: info.photoBase64,
            onPick: _pickPhoto,
            onRemove: _removePhoto,
          ),
        ),
        const SizedBox(height: 20),
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

// ---------- Summary ----------
class _SummaryField extends StatefulWidget {
  final ResumeData data;
  const _SummaryField({required this.data});

  @override
  State<_SummaryField> createState() => _SummaryFieldState();
}

class _SummaryFieldState extends State<_SummaryField> {
  late final _controller = TextEditingController(text: widget.data.personalInfo.summary);
  bool _aiBusy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onGenerateWithAi() async {
    if (!GroqService.isConfigured) {
      _showAiNotConfiguredDialog(context);
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) _showAiLimitReachedDialog(context);
      return;
    }
    if (!mounted) return;
    final info = widget.data.personalInfo;
    if (info.jobTitle.trim().isEmpty && widget.data.experience.isEmpty) {
      _showAiErrorSnackBar(context, 'Add a job title or work experience first so AI has something to summarize.');
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final result = await GroqService.generateSummary(context: widget.data);
      await AiUsageTracker.recordUsage();
      final previous = _controller.text;
      setState(() {
        _controller.text = result;
        info.summary = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Summary generated with AI'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => setState(() {
              _controller.text = previous;
              info.summary = previous;
            }),
          ),
        ));
      }
    } on AiServiceException catch (e) {
      if (mounted) _showAiErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextFormField(
          controller: _controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Professional Summary'),
          onChanged: (v) => widget.data.personalInfo.summary = v,
        ),
        const SizedBox(height: 8),
        AiActionButton(
          label: 'Generate with AI',
          busy: _aiBusy,
          onPressed: _aiBusy ? null : _onGenerateWithAi,
        ),
      ],
    );
  }
}

// ---------- Experience ----------
// StatefulWidget only to own the add/delete rebuild locally; typing inside
// a card never reaches this widget (see _ExperienceCard).
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
  bool _aiBusy = false;

  @override
  void dispose() {
    _role.dispose();
    _company.dispose();
    _startDate.dispose();
    _endDate.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _onRewriteWithAi() async {
    if (!GroqService.isConfigured) {
      _showAiNotConfiguredDialog(context);
      return;
    }
    if (!await AiUsageTracker.canUseAi()) {
      if (mounted) _showAiLimitReachedDialog(context);
      return;
    }
    if (!mounted) return;
    if (_description.text.trim().isEmpty) return;
    setState(() => _aiBusy = true);
    try {
      final result = await GroqService.rewriteBullet(
        currentText: _description.text,
        roleContext: '${widget.entry.role} at ${widget.entry.company}',
      );
      await AiUsageTracker.recordUsage();
      final previous = _description.text;
      setState(() {
        _description.text = result;
        widget.entry.description = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Rewritten with AI'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => setState(() {
              _description.text = previous;
              widget.entry.description = previous;
            }),
          ),
        ));
      }
    } on AiServiceException catch (e) {
      if (mounted) _showAiErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
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
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: AiActionButton(
                label: 'Rewrite with AI',
                busy: _aiBusy,
                onPressed: _aiBusy ? null : _onRewriteWithAi,
              ),
            ),
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
