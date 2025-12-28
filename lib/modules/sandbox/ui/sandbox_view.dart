import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/theme/nerd_fonts.dart';
import 'package:cwatch/shared/widgets/section_nav_bar.dart';

class SandboxView extends StatelessWidget {
  const SandboxView({super.key, this.leading});

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return Column(
      children: [
        SectionNavBar(
          title: 'Sandbox',
          tabs: const [],
          leading: leading,
        ),
        Expanded(
          child: Stack(
            children: [
              Center(
                child: Text(
                  'Sandbox canvas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: SafeArea(
                  minimum: EdgeInsets.all(spacing.lg),
                  child: const _TransferToast(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransferToast extends StatefulWidget {
  const _TransferToast();

  @override
  State<_TransferToast> createState() => _TransferToastState();
}

class _TransferToastState extends State<_TransferToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  late final List<_TransferSample> _samples = [
    _TransferSample(
      fileName: 'release_1.9.0.zip',
      status: 'Uploading • 3.4 MB/s',
      size: '64 MB',
      icon: NerdIcon.cloudUpload.data,
      start: 0.18,
      end: 0.92,
    ),
    _TransferSample(
      fileName: 'assets_pack.tar',
      status: 'Downloading • 8.1 MB/s',
      size: '420 MB',
      icon: NerdIcon.arrowDown.data,
      start: 0.12,
      end: 0.78,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _progressFor(_TransferSample sample) {
    final eased = Curves.easeInOut.transform(_controller.value);
    return ui.lerpDouble(sample.start, sample.end, eased) ?? sample.start;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final colorScheme = Theme.of(context).colorScheme;
    final section = context.appTheme.section;
    final surface = section.surface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Material(
          elevation: surface.elevation,
          color: surface.background,
          shape: RoundedRectangleBorder(
            borderRadius: surface.radius,
            side: BorderSide(color: surface.borderColor),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, minWidth: 280),
            child: Padding(
              padding: surface.padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        NerdIcon.cloudUpload.data,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: Text(
                          'File transfers',
                          style: context.appTheme.typography.tabLabel,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.sm,
                          vertical: spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: section.toolbarBackground,
                          borderRadius: surface.radius,
                          border: Border.all(color: surface.borderColor),
                        ),
                        child: Text(
                          '${_samples.length} active',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.md),
                  for (var i = 0; i < _samples.length; i++) ...[
                    _TransferRow(
                      sample: _samples[i],
                      progress: _progressFor(_samples[i]),
                    ),
                    if (i != _samples.length - 1) ...[
                      SizedBox(height: spacing.sm),
                      Divider(color: section.divider),
                      SizedBox(height: spacing.sm),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.sample, required this.progress});

  final _TransferSample sample;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    final colorScheme = Theme.of(context).colorScheme;
    final section = context.appTheme.section;
    final typography = context.appTheme.typography;
    final progressTrack = section.divider.withValues(alpha: 0.35);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircularPercentIndicator(
          radius: 16,
          lineWidth: 3,
          percent: progress,
          animation: false,
          backgroundColor: progressTrack,
          progressColor: colorScheme.primary,
          circularStrokeCap: CircularStrokeCap.round,
          center: Icon(sample.icon, size: 10, color: colorScheme.primary),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sample.fileName,
                style: typography.body,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: spacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sample.status,
                      style: typography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Text(
                    '${(progress * 100).round()}%',
                    style: typography.caption,
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              LinearPercentIndicator(
                padding: EdgeInsets.zero,
                lineHeight: 6,
                percent: progress,
                animation: false,
                backgroundColor: progressTrack,
                progressColor: colorScheme.primary,
                barRadius: const Radius.circular(8),
              ),
              SizedBox(height: spacing.xs),
              Text(
                sample.size,
                style: typography.caption.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransferSample {
  const _TransferSample({
    required this.fileName,
    required this.status,
    required this.size,
    required this.icon,
    required this.start,
    required this.end,
  });

  final String fileName;
  final String status;
  final String size;
  final IconData icon;
  final double start;
  final double end;
}
