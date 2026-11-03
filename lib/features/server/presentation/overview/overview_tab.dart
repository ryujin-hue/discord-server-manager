import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/models.dart';
import '../server_providers.dart';
import '../verification/verification_section.dart';

/// The overview tab with the counts of the server, the state of the bot and
/// the collected insights.
class OverviewTab extends ConsumerWidget {
  const OverviewTab({required this.guildId, super.key});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(serverOverviewProvider(guildId));
    final status = ref.watch(serverStatusProvider(guildId));

    return AsyncStateView<ServerOverview>(
      value: overview,
      onRetry: () => ref.invalidate(serverOverviewProvider(guildId)),
      data: (ServerOverview data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serverOverviewProvider(guildId));
          ref.invalidate(serverStatusProvider(guildId));
          await ref.read(serverOverviewProvider(guildId).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(data.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Server id ${data.guildId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _GatewayCard(status: status.value, overview: data),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.9,
              children: <Widget>[
                _StatCard(
                  label: 'Members',
                  value:
                      '${data.memberCount ?? data.approximateMemberCount ?? '—'}',
                ),
                _StatCard(label: 'Online', value: '${data.onlineCount ?? 0}'),
                _StatCard(label: 'Channels', value: '${data.channelCount}'),
                _StatCard(
                  label: 'Text channels',
                  value: '${data.textChannelCount}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            VerificationSection(guildId: guildId),
            const SizedBox(height: 24),
            _InsightsSection(guildId: guildId),
          ],
        ),
      ),
    );
  }
}

class _GatewayCard extends StatelessWidget {
  const _GatewayCard({required this.status, required this.overview});

  final ServerStatus? status;
  final ServerOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gateway = status?.gateway;
    final connected = gateway?.connected ?? false;
    final error = gateway?.error;

    final String title;
    final String detail;
    if (connected) {
      title = 'Active';
      detail =
          'The gateway is connected and the automatic features are enforced.';
    } else {
      title = 'Saved. Not enforced: gateway offline';
      detail = switch (error) {
        'privileged_intent_disabled' =>
          'The Server Members Intent is disabled in the Discord Developer '
              'Portal, so the gateway cannot log in.',
        'gateway_disabled' => 'The backend runs with the gateway disabled.',
        _ =>
          'The gateway is not connected, so the automatic features are '
              'stored but not enforced.',
      };
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  connected ? Icons.bolt : Icons.bolt_outlined,
                  size: 20,
                  color: connected
                      ? const Color(0xFF57F287)
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                if (!overview.botPresent)
                  Chip(
                    label: const Text('Bot not in server'),
                    avatar: Icon(
                      Icons.warning_amber_outlined,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    backgroundColor: theme.colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The chart of the collected member counts.
class _InsightsSection extends ConsumerWidget {
  const _InsightsSection({required this.guildId});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(serverInsightsProvider(guildId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Insights', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'The backend collects one point per day.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        insights.when(
          skipLoadingOnRefresh: false,
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) => ErrorRetryView(
            failure: error is AppFailure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () => ref.invalidate(serverInsightsProvider(guildId)),
          ),
          data: (List<InsightPoint> points) {
            if (points.isEmpty) {
              return const SizedBox(
                height: 160,
                child: EmptyStateView(
                  icon: Icons.show_chart,
                  title: 'No points collected yet',
                  message:
                      'The chart fills as soon as the backend collected its '
                      'first daily snapshot.',
                ),
              );
            }
            return _InsightsChart(points: points);
          },
        ),
      ],
    );
  }
}

/// A small line chart that only draws the points that were collected.
class _InsightsChart extends StatelessWidget {
  const _InsightsChart({required this.points});

  final List<InsightPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _LineChartPainter(
                  points: points,
                  color: theme.colorScheme.primary,
                  gridColor: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${points.length} points, from ${points.first.day} to '
              '${points.last.day}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.color,
    required this.gridColor,
  });

  final List<InsightPoint> points;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var index = 0; index <= 3; index += 1) {
      final y = size.height * index / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.length < 2) {
      return;
    }

    var maximum = 0;
    for (final point in points) {
      if (point.memberCount > maximum) {
        maximum = point.memberCount;
      }
    }
    if (maximum == 0) {
      return;
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var index = 0; index < points.length; index += 1) {
      final x = size.width * index / (points.length - 1);
      final y = size.height * (1 - points[index].memberCount / maximum);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (var index = 0; index < points.length; index += 1) {
      final x = size.width * index / (points.length - 1);
      final y = size.height * (1 - points[index].memberCount / maximum);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
