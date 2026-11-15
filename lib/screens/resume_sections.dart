import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/skill_suggestions.dart';
import '../models/resume_data.dart';
import '../services/ai_usage_tracker.dart';
import '../services/groq_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth/auth_kit.dart';
import '../widgets/app_feedback.dart';
import 'ai_guard.dart';

/// Shared building blocks for every screen that edits [ResumeData] — the
/// onboarding/settings Profile form and the resume editor — so both look and
/// behave identically. Field edits write straight into the passed-in data
/// and call `onChanged` so the host can refresh status pills / strength.

// ---------------------------------------------------------------------------
// Layout primitives
// ---------------------------------------------------------------------------

/// Collapsible section card: icon tile, title + one-line hint, status pill.
class ResumeSectionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final bool done;
  final bool initiallyExpanded;
  final Widget child;

  const ResumeSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.done,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<ResumeSectionCard> createState() => _ResumeSectionCardState();
}

class _ResumeSectionCardState extends State<ResumeSectionCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: p.background, borderRadius: BorderRadius.circular(12)),
                    child: Icon(widget.icon, size: 20, color: p.title),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: p.title)),
                        const SizedBox(height: 2),
                        Text(widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: p.body)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(label: widget.status, done: widget.done),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(LucideIcons.chevronDown, size: 20, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, thickness: 1, color: p.fieldBorder),
                      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 18), child: widget.child),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool done;
  const _StatusPill({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final fg = done ? AppColors.success : p.body;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: done ? AppColors.success.withValues(alpha: 0.12) : p.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            Icon(LucideIcons.check, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Small uppercase label that splits a section into sub-groups.
class GroupLabel extends StatelessWidget {
  final String text;
  const GroupLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: p.muted),
      ),
    );
  }
}

/// Two fields side by side.
class FieldPair extends StatelessWidget {
  final Widget left;
  final Widget right;
  const FieldPair(this.left, this.right, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)],
    );
  }
}

const kFieldGap = SizedBox(height: 14);

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _AddButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(LucideIcons.plus, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: p.title,
          backgroundColor: p.background,
          side: BorderSide(color: p.fieldBorder, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EntryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onDelete;
  const _EntryHeader({required this.title, required this.subtitle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.title)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: p.body)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Remove',
          onPressed: onDelete,
          icon: Icon(LucideIcons.trash2, size: 19, color: p.muted),
        ),
      ],
    );
  }
}

class _EntryShell extends StatelessWidget {
  final Widget header;
  final List<Widget> children;
  const _EntryShell({required this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [const SizedBox(height: 6), ...children],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CheckRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? p.focus : p.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: value ? p.focus : p.fieldBorder, width: 1.5),
              ),
              child: value ? Icon(LucideIcons.check, size: 14, color: p.onPrimary) : null,
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.title)),
          ],
        ),
      ),
    );
  }
}

/// Removes an item and offers Undo, so a mis-tap doesn't lose a filled entry.
void _removeWithUndo<T>(BuildContext context, List<T> list, T item, String label, VoidCallback onChanged) {
  final index = list.indexOf(item);
  if (index < 0) return;
  list.removeAt(index);
  onChanged();
  showToast(context, '$label removed', actionLabel: 'Undo', onAction: () {
    list.insert(index.clamp(0, list.length), item);
    onChanged();
  });
}

// ---------------------------------------------------------------------------
// AI helpers
// ---------------------------------------------------------------------------

/// Small gold-outlined "✦ Write with AI" pill used inside sections.
class AiPillButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  const AiPillButton({super.key, required this.label, required this.onPressed, this.busy = false});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Material(
      color: AppColors.accentGold.withValues(alpha: 0.12),
      shape: StadiumBorder(side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.55))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentGoldDeep),
                )
              else
                const Icon(LucideIcons.sparkles, size: 15, color: AppColors.accentGoldDeep),
              const SizedBox(width: 6),
              Text(
                busy ? 'Writing…' : label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.title),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String message, {ToastTone tone = ToastTone.info}) =>
    showToast(context, message, tone: tone);

// ---------------------------------------------------------------------------
// Personal details
// ---------------------------------------------------------------------------

class PersonalDetailsFields extends StatefulWidget {
  final ResumeData data;
  final VoidCallback onChanged;
  final String? nameError;

  /// Resume editor only: profile photo picker.
  final bool showPhoto;

  const PersonalDetailsFields({
    super.key,
    required this.data,
    required this.onChanged,
    this.nameError,
    this.showPhoto = false,
  });

  @override
  State<PersonalDetailsFields> createState() => _PersonalDetailsFieldsState();
}

class _PersonalDetailsFieldsState extends State<PersonalDetailsFields> {
  PersonalInfo get _info => widget.data.personalInfo;
  late final _fullName = TextEditingController(text: _info.fullName);
  late final _jobTitle = TextEditingController(text: _info.jobTitle);
  late final _email = TextEditingController(text: _info.email);
  late final _phone = TextEditingController(text: _info.phone);
  late final _location = TextEditingController(text: _info.location);

  @override
  void dispose() {
    for (final c in [_fullName, _jobTitle, _email, _phone, _location]) {
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
    setState(() => _info.photoBase64 = base64Encode(bytes));
    widget.onChanged();
  }

  void _removePhoto() {
    setState(() => _info.photoBase64 = '');
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showPhoto) ...[
          _PhotoRow(photoBase64: _info.photoBase64, onPick: _pickPhoto, onRemove: _removePhoto),
          const SizedBox(height: 22),
        ],
        const GroupLabel('About you'),
        FieldPair(
          AuthField(
            dense: true,
            label: 'Full name *',
            hint: 'Sarah Ahmed',
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            errorText: widget.nameError,
            onChanged: (v) {
              _info.fullName = v;
              widget.onChanged();
            },
          ),
          AuthField(
            dense: true,
            label: 'Job title',
            hint: 'Designer',
            controller: _jobTitle,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.jobTitle],
            onChanged: (v) {
              _info.jobTitle = v;
              widget.onChanged();
            },
          ),
        ),
        const SizedBox(height: 22),
        const GroupLabel('Contact'),
        AuthField(
          dense: true,
          label: 'Email',
          hint: 'you@example.com',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onChanged: (v) {
            _info.email = v;
            widget.onChanged();
          },
        ),
        kFieldGap,
        FieldPair(
          AuthField(
            dense: true,
            label: 'Phone',
            hint: '+92 300 1234567',
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (v) {
              _info.phone = v;
              widget.onChanged();
            },
          ),
          AuthField(
            dense: true,
            label: 'City',
            hint: 'Lahore, PK',
            controller: _location,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.addressCity],
            onChanged: (v) {
              _info.location = v;
              widget.onChanged();
            },
          ),
        ),
      ],
    );
  }
}

class _PhotoRow extends StatelessWidget {
  final String photoBase64;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  const _PhotoRow({required this.photoBase64, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final hasPhoto = photoBase64.isNotEmpty;
    return Row(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.background,
              border: Border.all(color: p.fieldBorder, width: 1.2),
              image: hasPhoto
                  ? DecorationImage(image: MemoryImage(base64Decode(photoBase64)), fit: BoxFit.cover)
                  : null,
            ),
            child: hasPhoto ? null : Icon(LucideIcons.camera, color: p.muted, size: 24),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.title)),
              const SizedBox(height: 2),
              Text('Optional. Shown on the Modern template.', style: TextStyle(fontSize: 12.5, color: p.body)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _SmallButton(label: hasPhoto ? 'Change' : 'Upload', icon: LucideIcons.upload, onTap: onPick),
                  if (hasPhoto) ...[
                    const SizedBox(width: 8),
                    _SmallButton(label: 'Remove', icon: LucideIcons.trash2, onTap: onRemove, danger: true),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _SmallButton({required this.label, required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final fg = danger ? AppColors.danger : p.title;
    return Material(
      color: p.background,
      shape: StadiumBorder(side: BorderSide(color: p.fieldBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

class SummaryEditor extends StatefulWidget {
  final ResumeData data;
  final VoidCallback onChanged;
  final bool enableAi;
  const SummaryEditor({super.key, required this.data, required this.onChanged, this.enableAi = false});

  @override
  State<SummaryEditor> createState() => _SummaryEditorState();
}

class _SummaryEditorState extends State<SummaryEditor> {
  late final _controller = TextEditingController(text: widget.data.personalInfo.summary);
  bool _aiBusy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _set(String value) {
    _controller.text = value;
    widget.data.personalInfo.summary = value;
    setState(() {});
    widget.onChanged();
  }

  Future<void> _generate() async {
    if (!await ensureAiAvailable(context)) return;
    if (!mounted) return;
    final info = widget.data.personalInfo;
    if (info.jobTitle.trim().isEmpty && widget.data.experience.isEmpty) {
      _snack(context, 'Add a job title or a role first so AI has something to work from.');
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final result = await GroqService.generateSummary(context: widget.data);
      await AiUsageTracker.recordUsage();
      final previous = _controller.text;
      _set(result);
      if (mounted) {
        showToast(context, 'Summary written with AI',
            tone: ToastTone.success, actionLabel: 'Undo', onAction: () => _set(previous));
      }
    } on AiServiceException catch (e) {
      if (mounted) _snack(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final text = _controller.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthField(
          dense: true,
          label: 'Summary',
          hint: '2–3 sentences, e.g. Product designer with 5 years of experience building fintech apps…',
          controller: _controller,
          maxLines: 6,
          minLines: 4,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) {
            widget.data.personalInfo.summary = v;
            setState(() {});
            widget.onChanged();
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text('$words ${words == 1 ? 'word' : 'words'}', style: TextStyle(fontSize: 12, color: p.muted)),
            ),
            if (widget.enableAi)
              AiPillButton(
                label: text.isEmpty ? 'Write with AI' : 'Rewrite with AI',
                busy: _aiBusy,
                onPressed: _generate,
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Experience
// ---------------------------------------------------------------------------

class ExperienceEditor extends StatelessWidget {
  final ResumeData data;
  final VoidCallback onChanged;
  final bool enableAi;
  const ExperienceEditor({super.key, required this.data, required this.onChanged, this.enableAi = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < data.experience.length; i++)
          _ExperienceCard(
            key: ValueKey(data.experience[i].id),
            entry: data.experience[i],
            enableAi: enableAi,
            onChanged: onChanged,
            onDelete: () => _removeWithUndo(context, data.experience, data.experience[i], 'Role', onChanged),
          ),
        _AddButton(
          label: data.experience.isEmpty ? 'Add a role' : 'Add another role',
          onPressed: () {
            data.experience.add(ExperienceEntry());
            onChanged();
          },
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatefulWidget {
  final ExperienceEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final bool enableAi;
  const _ExperienceCard({
    super.key,
    required this.entry,
    required this.onDelete,
    required this.onChanged,
    required this.enableAi,
  });

  @override
  State<_ExperienceCard> createState() => _ExperienceCardState();
}

class _ExperienceCardState extends State<_ExperienceCard> {
  late final _role = TextEditingController(text: widget.entry.role);
  late final _company = TextEditingController(text: widget.entry.company);
  late final _startDate = TextEditingController(text: widget.entry.startDate);
  late final _endDate = TextEditingController(text: widget.entry.endDate);
  late final _description = TextEditingController(text: widget.entry.description);
  late bool _current = widget.entry.endDate.trim().toLowerCase() == 'present';
  bool _aiBusy = false;

  @override
  void dispose() {
    for (final c in [_role, _company, _startDate, _endDate, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setCurrent(bool value) {
    setState(() {
      _current = value;
      final end = value ? 'Present' : '';
      _endDate.text = end;
      widget.entry.endDate = end;
    });
    widget.onChanged();
  }

  void _setDescription(String value) {
    setState(() {
      _description.text = value;
      widget.entry.description = value;
    });
    widget.onChanged();
  }

  Future<void> _rewrite() async {
    if (_description.text.trim().isEmpty) {
      _snack(context, 'Write a line or two about this role first, then AI can polish it.');
      return;
    }
    if (!await ensureAiAvailable(context)) return;
    if (!mounted) return;
    setState(() => _aiBusy = true);
    try {
      final result = await GroqService.rewriteBullet(
        currentText: _description.text,
        roleContext: '${widget.entry.role} at ${widget.entry.company}',
      );
      await AiUsageTracker.recordUsage();
      final previous = _description.text;
      _setDescription(result);
      if (mounted) {
        showToast(context, 'Rewritten with AI',
            tone: ToastTone.success, actionLabel: 'Undo', onAction: () => _setDescription(previous));
      }
    } on AiServiceException catch (e) {
      if (mounted) _snack(context, e.message, tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return _EntryShell(
      header: _EntryHeader(
        title: entry.role.trim().isEmpty ? 'New role' : entry.role,
        subtitle: entry.company,
        onDelete: widget.onDelete,
      ),
      children: [
        FieldPair(
          AuthField(
            dense: true,
            label: 'Job title',
            hint: 'Designer',
            controller: _role,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (v) {
              setState(() => entry.role = v);
              widget.onChanged();
            },
          ),
          AuthField(
            dense: true,
            label: 'Company',
            hint: 'Northwind',
            controller: _company,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (v) {
              setState(() => entry.company = v);
              widget.onChanged();
            },
          ),
        ),
        kFieldGap,
        FieldPair(
          AuthField(
            dense: true,
            label: 'Start',
            hint: 'Jan 2022',
            controller: _startDate,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (v) => entry.startDate = v,
          ),
          AuthField(
            dense: true,
            label: 'End',
            hint: 'Mar 2024',
            controller: _endDate,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (v) {
              entry.endDate = v;
              final isPresent = v.trim().toLowerCase() == 'present';
              if (isPresent != _current) setState(() => _current = isPresent);
            },
          ),
        ),
        const SizedBox(height: 4),
        _CheckRow(label: 'I currently work here', value: _current, onChanged: _setCurrent),
        const SizedBox(height: 8),
        AuthField(
          dense: true,
          label: 'What you did',
          hint: 'Key responsibilities and results, one per line',
          controller: _description,
          maxLines: 6,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) {
            entry.description = v;
            widget.onChanged();
          },
        ),
        if (widget.enableAi) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: AiPillButton(label: 'Improve with AI', busy: _aiBusy, onPressed: _rewrite),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Education
// ---------------------------------------------------------------------------

class EducationEditor extends StatelessWidget {
  final ResumeData data;
  final VoidCallback onChanged;
  const EducationEditor({super.key, required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < data.education.length; i++)
          _EducationCard(
            key: ValueKey(data.education[i].id),
            entry: data.education[i],
            onChanged: onChanged,
            onDelete: () => _removeWithUndo(context, data.education, data.education[i], 'Education', onChanged),
          ),
        _AddButton(
          label: data.education.isEmpty ? 'Add education' : 'Add more education',
          onPressed: () {
            data.education.add(EducationEntry());
            onChanged();
          },
        ),
      ],
    );
  }
}

class _EducationCard extends StatefulWidget {
  final EducationEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  const _EducationCard({super.key, required this.entry, required this.onDelete, required this.onChanged});

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
    for (final c in [_degree, _school, _startDate, _endDate]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return _EntryShell(
      header: _EntryHeader(
        title: entry.degree.trim().isEmpty ? 'New education' : entry.degree,
        subtitle: entry.school,
        onDelete: widget.onDelete,
      ),
      children: [
        AuthField(
          dense: true,
          label: 'Degree or program',
          hint: 'BS Computer Science',
          controller: _degree,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (v) {
            setState(() => entry.degree = v);
            widget.onChanged();
          },
        ),
        kFieldGap,
        AuthField(
          dense: true,
          label: 'School or university',
          hint: 'University of the Punjab',
          controller: _school,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (v) {
            setState(() => entry.school = v);
            widget.onChanged();
          },
        ),
        kFieldGap,
        FieldPair(
          AuthField(
            dense: true,
            label: 'Start year',
            hint: '2018',
            controller: _startDate,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            onChanged: (v) => entry.startDate = v,
          ),
          AuthField(
            dense: true,
            label: 'End year',
            hint: '2022',
            controller: _endDate,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onChanged: (v) => entry.endDate = v,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Skills
// ---------------------------------------------------------------------------

class SkillsEditor extends StatefulWidget {
  final ResumeData data;
  final VoidCallback onChanged;
  const SkillsEditor({super.key, required this.data, required this.onChanged});

  @override
  State<SkillsEditor> createState() => _SkillsEditorState();
}

class _SkillsEditorState extends State<SkillsEditor> {
  TextEditingController? _fieldController;

  void _addSkill([String? skill]) {
    final text = (skill ?? _fieldController?.text ?? '').trim();
    if (text.isNotEmpty && !widget.data.skills.contains(text)) {
      widget.data.skills.add(text);
      widget.onChanged();
    }
    _fieldController?.clear();
  }

  void _removeSkill(String skill) {
    widget.data.skills.remove(skill);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final skills = widget.data.skills;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Autocomplete<String>(
                  optionsBuilder: (value) {
                    final query = value.text.trim().toLowerCase();
                    if (query.isEmpty) return const Iterable<String>.empty();
                    return kSkillSuggestions
                        .where((s) => s.toLowerCase().contains(query) && !skills.contains(s))
                        .take(8);
                  },
                  onSelected: _addSkill,
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _fieldController = controller;
                    return AuthField(
                      dense: true,
                      label: 'Add a skill',
                      hint: 'e.g. Figma, SQL, Leadership',
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addSkill(),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Material(
                          color: p.surface,
                          elevation: 6,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 260, maxWidth: constraints.maxWidth),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Text(option, style: TextStyle(fontSize: 14.5, color: p.title)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                tooltip: 'Add skill',
                onPressed: _addSkill,
                icon: const Icon(LucideIcons.plus),
                style: IconButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (skills.isEmpty)
          Text('Add at least 3 skills. Type to see suggestions.', style: TextStyle(fontSize: 12.5, color: p.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in skills)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.fieldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.title)),
                      const SizedBox(width: 2),
                      InkResponse(
                        radius: 16,
                        onTap: () => _removeSkill(s),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(LucideIcons.x, size: 15, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status helpers (shared by hosts)
// ---------------------------------------------------------------------------

String countLabel(int n, String singular, {String? plural}) {
  if (n == 0) return 'None yet';
  return '$n ${n == 1 ? singular : (plural ?? '${singular}s')}';
}

int filledBasics(PersonalInfo info) =>
    [info.fullName, info.jobTitle, info.email, info.phone, info.location].where((s) => s.trim().isNotEmpty).length;

// ---------------------------------------------------------------------------
// Strength card (shared by every editor)
// ---------------------------------------------------------------------------

/// Live completeness meter plus the single most valuable next step.
class StrengthCard extends StatelessWidget {
  final String label;
  final double percent;
  final String? nextStep;
  final int? nextGain;
  final String doneMessage;

  const StrengthCard({
    super.key,
    required this.label,
    required this.percent,
    required this.nextStep,
    required this.nextGain,
    this.doneMessage = 'Looking great. Ready to export.',
  });

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    final pct = percent.clamp(0, 100).toDouble();
    final verdict = pct >= 100
        ? 'Excellent'
        : pct >= 70
            ? 'Strong'
            : pct >= 40
                ? 'Getting there'
                : 'Just started';
    final barColor = pct >= 80 ? AppColors.success : p.title;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: p.muted)),
                    const SizedBox(height: 4),
                    Text(verdict, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.title)),
                  ],
                ),
              ),
              Text(
                '${pct.round()}%',
                style: TextStyle(
                    fontFamily: 'Fraunces', fontSize: 28, height: 1, fontWeight: FontWeight.w600, color: p.title),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: pct / 100),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) =>
                  LinearProgressIndicator(value: v, minHeight: 7, backgroundColor: p.background, color: barColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(nextStep == null ? LucideIcons.circleCheck : LucideIcons.lightbulb,
                  size: 16, color: nextStep == null ? AppColors.success : AppColors.accentGoldDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  nextStep == null
                      ? TextSpan(text: doneMessage)
                      : TextSpan(children: [
                          const TextSpan(text: 'Next: '),
                          TextSpan(text: nextStep, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (nextGain != null)
                            TextSpan(text: '  +$nextGain%', style: const TextStyle(color: AppColors.success)),
                        ]),
                  style: TextStyle(fontSize: 13, color: p.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small outlined pill used for secondary in-section actions
/// (e.g. "Fill from my profile").
class SectionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const SectionPillButton({super.key, required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final p = AuthPalette.of(context);
    return Material(
      color: p.background,
      shape: StadiumBorder(side: BorderSide(color: p.fieldBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: p.title),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.title)),
            ],
          ),
        ),
      ),
    );
  }
}
